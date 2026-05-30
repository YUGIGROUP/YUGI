/**
 * TEST-ONLY — backdates a single booking so the release cron will fire on it
 * immediately. Sets classCompletedAt + fundsReleaseDate to "1 hour ago" so we
 * don't have to wait three working days to validate the payout path.
 *
 * Does NOT call Stripe. Run scripts/run-funds-release-once.js (or wait for
 * the cron tick) after this to actually transfer.
 *
 * Refuses to run unless STRIPE_SECRET_KEY is sk_test_, as a guard against
 * accidentally backdating a live booking.
 *
 * Run from backend/ folder:
 *   railway run node scripts/backdate-booking-release.js <bookingId>
 */

require('dotenv').config();
const mongoose = require('mongoose');

const SECRET = process.env.STRIPE_SECRET_KEY || '';
if (!SECRET.startsWith('sk_test_')) {
  console.error('❌ Refusing to run: STRIPE_SECRET_KEY is not an sk_test_ key.');
  console.error('   This script is test-only. Aborting.');
  process.exit(1);
}

const bookingId = process.argv[2];
if (!bookingId) {
  console.error('Usage: node scripts/backdate-booking-release.js <bookingId>');
  process.exit(1);
}

async function main() {
  if (!process.env.MONGODB_URI) {
    console.error('❌ MONGODB_URI not set');
    process.exit(1);
  }
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('📊 Connected to MongoDB');

  const Booking = require('../src/models/Booking');

  const booking = await Booking.findById(bookingId);
  if (!booking) {
    console.error(`❌ Booking ${bookingId} not found`);
    process.exit(1);
  }

  if (booking.paymentStatus !== 'held') {
    console.error(`❌ Booking ${booking.bookingNumber} is paymentStatus='${booking.paymentStatus}', not 'held'. Refusing to backdate.`);
    process.exit(1);
  }

  if (booking.fundsReleased) {
    console.error(`❌ Booking ${booking.bookingNumber} is already fundsReleased. Refusing to backdate.`);
    process.exit(1);
  }

  const past = new Date(Date.now() - 60 * 60 * 1000);
  booking.classCompletedAt = past;
  booking.fundsReleaseDate = past;
  await booking.save();

  console.log(`✅ Backdated booking ${booking.bookingNumber}:`);
  console.log(`   classCompletedAt = ${past.toISOString()}`);
  console.log(`   fundsReleaseDate = ${past.toISOString()}`);
  console.log(`\nNext: run scripts/run-funds-release-once.js to trigger the transfer.`);

  await mongoose.disconnect();
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
