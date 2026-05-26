/**
 * READ-ONLY — inspects Daisy's most recent bookings to verify
 * payment status, holding logic, and Stripe ID storage.
 *
 * No writes. Safe to run anytime.
 *
 * Run from backend/ folder:
 *   railway run node scripts/inspect-daisy-booking.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Booking = require('../src/models/Booking');
const User = require('../src/models/User');
const Class = require('../src/models/Class');

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('📊 Connected to MongoDB\n');

  const daisy = await User.findOne({ email: 'daisy@test.com' });
  if (!daisy) {
    console.log('❌ No user found with email daisy@test.com');
    process.exit(1);
  }
  console.log(`👤 Daisy: ${daisy._id}\n`);

  const bookings = await Booking.find({ parent: daisy._id })
    .populate('class', 'name')
    .sort({ createdAt: -1 })
    .limit(5);

  if (bookings.length === 0) {
    console.log('❌ No bookings found for Daisy');
    process.exit(0);
  }

  console.log(`Found ${bookings.length} recent booking(s):\n`);

  for (const b of bookings) {
    console.log('─'.repeat(60));
    console.log(`📋 Booking: ${b.bookingNumber}`);
    console.log(`   _id:                   ${b._id}`);
    console.log(`   Class:                 ${b.class?.name || '(unknown)'}`);
    console.log(`   Created:               ${b.createdAt}`);
    console.log(`   Session date:          ${b.sessionDate}`);
    console.log(`   Total amount:          £${b.totalAmount}`);
    console.log('');
    console.log(`   status:                ${b.status}`);
    console.log(`   paymentStatus:         ${b.paymentStatus}`);
    console.log('');
    console.log(`   stripePaymentIntentId: ${b.stripePaymentIntentId || '(not set)'}`);
    console.log(`   stripeChargeId:        ${b.stripeChargeId || '(not set)'}`);
    console.log('');
    console.log(`   paymentDate:           ${b.paymentDate || '(not set)'}`);
    console.log(`   fundsReleased:         ${b.fundsReleased}`);
    console.log(`   fundsReleaseDate:      ${b.fundsReleaseDate || '(not set)'}`);
    console.log(`   classCompletedAt:      ${b.classCompletedAt || '(not set)'}`);
    console.log('');
    console.log(`   cancelledAt:           ${b.cancelledAt || '(not set)'}`);
    console.log(`   refundAmount:          £${b.refundAmount || 0}`);
  }

  console.log('─'.repeat(60));
  console.log('\n✅ Inspection complete (no writes performed)');

  await mongoose.disconnect();
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
