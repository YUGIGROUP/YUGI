// Funds-release service.
//
// Owns three operations for the Session 5 holding-period payout pipeline:
//   1. runAutoCompletionSweep() — auto-stamps classCompletedAt + fundsReleaseDate
//      on bookings whose session has ended + grace period elapsed, so the
//      release clock starts even if the provider never manually marked the
//      class complete.
//   2. releaseFundsToProvider(bookingId) — single-booking atomic-claim release;
//      transfers basePrice in pence to the provider's Stripe Connect account
//      via stripe.transfers.create with a stable idempotency key.
//   3. runReleaseSweep() — finds every booking past fundsReleaseDate that is
//      still 'held' and not cancelled, and calls releaseFundsToProvider on
//      each (per-booking try/catch so one bad booking can't abort the batch).
//
// Money invariants (must never be violated):
//   - Never transfer twice for one booking (atomic claim + stable
//     idempotencyKey = `transfer_${bookingId}`).
//   - Never mark released unless the Stripe transfer call returned a valid
//     transfer.id.
//   - Never transfer if the provider isn't payouts-enabled in Stripe Connect.
//
// The release cron is wired in src/server.js (startFundsReleaseJob).

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const Booking = require('../models/Booking');
// Registration side-effect: the populate('class' → 'provider') below needs
// these schemas registered with mongoose. Server boot pulls them transitively,
// but standalone callers (ops scripts, tests) don't — declare the dependency
// here so the service is self-contained.
require('../models/Class');
require('../models/User');
const { applyClassCompletion } = require('../utils/holdingPeriod');

// 3 hours after sessionDate, we treat a held booking as completed and start
// the release clock. Covers typical class duration + cushion. Manual provider
// completion (PUT /bookings/:id/complete) always wins because
// applyClassCompletion no-ops if classCompletedAt is already set.
const COMPLETION_GRACE_MS = 3 * 60 * 60 * 1000;

// A claim is considered stale (and re-claimable) if releaseStartedAt is older
// than this. Covers process crashes mid-transfer.
const STALE_CLAIM_MS = 30 * 60 * 1000;

// ─── Auto-completion sweep ──────────────────────────────────────────────────
// Selects held bookings whose session ended >= COMPLETION_GRACE_MS ago and
// stamps classCompletedAt + fundsReleaseDate so the release clock runs even
// when providers don't manually tap "complete".
async function runAutoCompletionSweep() {
  const cutoff = new Date(Date.now() - COMPLETION_GRACE_MS);
  const candidates = await Booking.find({
    paymentStatus: 'held',
    classCompletedAt: null,
    status: 'confirmed',
    sessionDate: { $lte: cutoff },
  });

  let completed = 0;
  for (const booking of candidates) {
    try {
      const completedAt = new Date(booking.sessionDate.getTime() + COMPLETION_GRACE_MS);
      const changed = applyClassCompletion(booking, completedAt);
      if (changed) {
        booking.status = 'completed';
        await booking.save();
        completed++;
        console.log(`✅ Auto-completed booking ${booking.bookingNumber}; release at ${booking.fundsReleaseDate.toISOString()}`);
      }
    } catch (err) {
      console.error(`Auto-completion error for booking ${booking._id}:`, err.message);
    }
  }
  return { scanned: candidates.length, completed };
}

// ─── Single-booking release ─────────────────────────────────────────────────
// Atomically claims the booking, transfers basePrice to the provider's
// connected account, and marks 'released'. Idempotent: a stable
// idempotencyKey means re-running this for the same bookingId after a partial
// failure will not create a second transfer.
async function releaseFundsToProvider(bookingId) {
  // (a) Atomic claim. Only one process can hold the claim at a time; stale
  // claims (older than STALE_CLAIM_MS) are reclaimable. Populate is NOT chained
  // here — a populate-time throw would strand the claim with releaseInProgress
  // stuck true. Populate happens inside the try/catch below so any failure
  // unwinds the claim.
  const staleCutoff = new Date(Date.now() - STALE_CLAIM_MS);
  const booking = await Booking.findOneAndUpdate(
    {
      _id: bookingId,
      paymentStatus: 'held',
      fundsReleased: false,
      $or: [
        { releaseInProgress: { $ne: true } },
        { releaseStartedAt: { $lt: staleCutoff } },
      ],
    },
    {
      $set: { releaseInProgress: true, releaseStartedAt: new Date() },
      $inc: { releaseAttempts: 1 },
    },
    { new: true }
  );

  if (!booking) {
    // Already claimed by another tick, already released, refunded, or
    // cancelled. Either way: nothing to do.
    return { skipped: true, reason: 'no_claim' };
  }

  // From here on, any throw MUST free the claim so the next tick can retake it.
  try {
    // (b) Populate provider for the readiness check + Connect destination.
    await booking.populate({
      path: 'class',
      populate: { path: 'provider', select: 'stripeConnectedAccountId stripePayoutsEnabled businessName fullName' },
    });

    const provider = booking.class && booking.class.provider;

    // (c) Provider readiness guard. If onboarding incomplete, release the claim
    // and leave the booking 'held'; a later run will retry once
    // stripePayoutsEnabled flips true.
    if (!provider || !provider.stripeConnectedAccountId || provider.stripePayoutsEnabled !== true) {
      booking.releaseInProgress = false;
      booking.lastReleaseError = 'provider payouts not enabled';
      await booking.save();
      console.warn(`⏸  Skipping booking ${booking.bookingNumber}: provider payouts not enabled`);
      return { skipped: true, reason: 'provider_not_ready', bookingNumber: booking.bookingNumber };
    }

    // (d) Provider gets basePrice in pence; YUGI keeps the £1.99 serviceFee.
    const amountInPence = Math.round(booking.basePrice * 100);

    // (e) Transfer with a stable idempotency key tied to the booking ID. If the
    // process crashes after Stripe accepted the transfer but before we saved,
    // a later retry will receive the same Transfer object back from Stripe
    // rather than creating a second one.
    const transfer = await stripe.transfers.create(
      {
        amount: amountInPence,
        currency: 'gbp',
        destination: provider.stripeConnectedAccountId,
        metadata: {
          bookingId: booking._id.toString(),
          bookingNumber: booking.bookingNumber,
        },
      },
      { idempotencyKey: `transfer_${booking._id.toString()}` }
    );

    // (f) Success.
    booking.paymentStatus = 'released';
    booking.fundsReleased = true;
    booking.fundsReleasedAt = new Date();
    booking.stripeTransferId = transfer.id;
    booking.releaseInProgress = false;
    booking.lastReleaseError = null;
    await booking.save();

    console.log(`💸 Released £${(amountInPence / 100).toFixed(2)} to ${provider.businessName || provider.fullName} for booking ${booking.bookingNumber} (transfer ${transfer.id})`);
    return { released: true, bookingNumber: booking.bookingNumber, transferId: transfer.id, amountPence: amountInPence };
  } catch (err) {
    // (g) Any post-claim failure: free the claim, record the error, surface to
    // the caller. The save is guarded so a save-time failure only logs — we
    // must still return the original failure rather than throw past it.
    try {
      booking.releaseInProgress = false;
      booking.lastReleaseError = err.message || 'release failed';
      await booking.save();
    } catch (saveErr) {
      console.error(`Failed to free claim for booking ${booking._id}: ${saveErr.message}`);
    }
    console.error(`❌ Release failed for booking ${booking.bookingNumber || booking._id}: ${err.message}`);
    return { failed: true, reason: 'exception', error: err.message };
  }
}

// ─── Release sweep ──────────────────────────────────────────────────────────
// Finds every booking whose holding window has elapsed and tries to release
// each one. Per-booking try/catch so one Stripe error doesn't abort the batch.
async function runReleaseSweep() {
  const due = await Booking.find({
    paymentStatus: 'held',
    fundsReleased: false,
    fundsReleaseDate: { $lte: new Date() },
    status: { $ne: 'cancelled' },
  }).select('_id bookingNumber');

  let released = 0;
  let skipped = 0;
  let failed = 0;

  for (const candidate of due) {
    try {
      const result = await releaseFundsToProvider(candidate._id);
      if (result.released) released++;
      else if (result.skipped) skipped++;
      else if (result.failed) failed++;
    } catch (err) {
      failed++;
      console.error(`Release sweep error for booking ${candidate._id}:`, err.message);
    }
  }

  return { scanned: due.length, released, skipped, failed };
}

module.exports = {
  COMPLETION_GRACE_MS,
  STALE_CLAIM_MS,
  runAutoCompletionSweep,
  releaseFundsToProvider,
  runReleaseSweep,
};
