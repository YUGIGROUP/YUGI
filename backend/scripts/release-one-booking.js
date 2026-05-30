/**
 * Single-booking funds-release helper. Calls releaseFundsToProvider(bookingId)
 * for exactly one booking and prints the full result object. Does NOT run
 * either sweep, so other 'held' bookings are untouched.
 *
 * Idempotent: re-running for the same bookingId after a successful release
 * returns { skipped: true, reason: 'no_claim' } and creates no second transfer
 * (the claim gates on paymentStatus='held' + fundsReleased=false).
 *
 * THIS CALLS REAL stripe.transfers.create. Refuses to run unless
 * STRIPE_SECRET_KEY is an sk_test_ key.
 *
 * Run from backend/ folder:
 *   railway run node scripts/release-one-booking.js <bookingId>
 */

require('dotenv').config();
const mongoose = require('mongoose');

const SECRET = process.env.STRIPE_SECRET_KEY || '';
if (!SECRET.startsWith('sk_test_')) {
  console.error('❌ Refusing to run: STRIPE_SECRET_KEY is not an sk_test_ key.');
  console.error('   This script moves real money in live mode. Aborting.');
  process.exit(1);
}

const bookingId = process.argv[2];
if (!bookingId) {
  console.error('❌ Usage: node scripts/release-one-booking.js <bookingId>');
  process.exit(1);
}

async function main() {
  if (!process.env.MONGODB_URI) {
    console.error('❌ MONGODB_URI not set');
    process.exit(1);
  }
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('📊 Connected to MongoDB');

  // Pre-register models so the .populate('class' → 'provider') chain inside
  // releaseFundsToProvider can resolve refs.
  require('../src/models/Booking');
  require('../src/models/Class');
  require('../src/models/User');

  const { releaseFundsToProvider } = require('../src/services/fundsReleaseService');

  console.log(`\n▶ Releasing funds for booking ${bookingId}…`);
  const result = await releaseFundsToProvider(bookingId);
  console.log('\nResult:');
  console.log(JSON.stringify(result, null, 2));

  await mongoose.disconnect();
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
