const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const Class = require('../models/Class');
const emailService = require('./emailService');

const SERVICE_FEE = 1.99;

/**
 * Cancel a single booking and issue the appropriate refund.
 *
 * @param {Object} booking - Mongoose Booking doc, populated with `class` and `parent`.
 * @param {Object} opts
 * @param {'provider'|'parent'} opts.cancelledBy - who is cancelling.
 * @param {string} [opts.reason] - optional reason stored on the booking.
 * @returns {Promise<Object>}
 *   { bookingNumber, skipped }                                  nothing to do
 *   { bookingNumber, success:false, error, ... }                Stripe refund failed
 *   { bookingNumber, success:true, refundAmount, refundReason, stripeRefundId }
 */
async function cancelBookingWithRefund(booking, { cancelledBy, reason } = {}) {
  const isProvider = cancelledBy === 'provider';
  const bookingNumber = booking.bookingNumber;

  // Guards - nothing to refund
  if (booking.status === 'cancelled') {
    return { bookingNumber, skipped: 'already_cancelled' };
  }
  if (booking.status === 'completed') {
    return { bookingNumber, skipped: 'completed' };
  }
  if (booking.fundsLeftPlatform()) {
    return { bookingNumber, skipped: 'funds_released' };
  }

  // Determine refund amount based on who is cancelling and timing
  const sessionDate = new Date(booking.sessionDate);
  const now = new Date();
  const hoursUntilSession = (sessionDate - now) / (1000 * 60 * 60);

  let refundAmount = 0;
  let refundReason = '';

  if (isProvider) {
    // Provider cancellation: full refund including service fee
    refundAmount = booking.totalAmount;
    refundReason = 'provider_cancellation';
  } else if (hoursUntilSession > 24) {
    // Parent cancellation outside 24h: full refund minus service fee
    refundAmount = Math.max(0, booking.totalAmount - SERVICE_FEE);
    refundReason = 'parent_cancellation_outside_window';
  } else {
    // Parent cancellation inside 24h: no refund
    refundAmount = 0;
    refundReason = 'parent_cancellation_inside_window';
  }

  console.log(
    `Cancelling booking ${bookingNumber}: ${refundReason}, refund GBP ${refundAmount.toFixed(2)}`
  );

  // Process Stripe refund if applicable
  let stripeRefund = null;
  if (
    refundAmount > 0 &&
    (booking.paymentStatus === 'paid' || booking.paymentStatus === 'held') &&
    booking.stripeChargeId
  ) {
    try {
      stripeRefund = await stripe.refunds.create({
        charge: booking.stripeChargeId,
        amount: Math.round(refundAmount * 100),
        reason: 'requested_by_customer',
        metadata: {
          bookingId: booking._id.toString(),
          bookingNumber,
          cancellationReason: refundReason,
          cancelledBy: isProvider ? 'provider' : 'parent'
        }
      });
      console.log(`Stripe refund created: ${stripeRefund.id}, status: ${stripeRefund.status}`);
    } catch (stripeError) {
      console.error(`Stripe refund failed for ${bookingNumber}:`, stripeError.message);
      return { bookingNumber, success: false, error: stripeError.message, refundAmount, refundReason };
    }
  } else if (refundAmount > 0 && !booking.stripeChargeId) {
    console.warn(`Refund owed (GBP ${refundAmount}) but no stripeChargeId on booking ${bookingNumber}`);
  }

  // Update booking
  booking.status = 'cancelled';
  booking.cancelledAt = new Date();
  booking.cancellationReason = reason || refundReason;
  booking.refundAmount = refundAmount;
  if (refundAmount > 0 && stripeRefund) {
    booking.paymentStatus = 'refunded';
  }
  await booking.save();

  // Decrement the class's booking count (works whether class is populated or an id)
  const classId = booking.class && booking.class._id ? booking.class._id : booking.class;
  await Class.findByIdAndUpdate(classId, { $inc: { currentBookings: -1 } });

  // Send cancellation email (non-blocking)
  try {
    await emailService.sendCancellationEmail({
      booking,
      cancelledBy: isProvider ? 'provider' : 'parent',
      refundAmount,
      reason: refundReason
    });
  } catch (emailErr) {
    console.error('Cancellation email failed (non-blocking):', emailErr.message);
  }

  return {
    bookingNumber,
    success: true,
    refundAmount,
    refundReason,
    stripeRefundId: stripeRefund?.id || null
  };
}

module.exports = { cancelBookingWithRefund, SERVICE_FEE };
