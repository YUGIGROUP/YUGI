/**
 * READ-ONLY — lists every booking currently in the 'released' state so they
 * can be matched to a booking in the app.
 *
 * No writes. Safe to run anytime.
 *
 * Run from backend/ folder:
 *   railway run node scripts/inspect-released-bookings.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Booking = require('../src/models/Booking');
const User = require('../src/models/User');
const Class = require('../src/models/Class');

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('📊 Connected to MongoDB\n');

  const bookings = await Booking.find({ paymentStatus: 'released' })
    .populate('class', 'name')
    .populate('parent', 'email fullName')
    .sort({ createdAt: -1 });

  console.log(`Found ${bookings.length} booking(s) with paymentStatus 'released':\n`);

  for (const b of bookings) {
    console.log('─'.repeat(60));
    console.log(`📋 Booking: ${b.bookingNumber}`);
    console.log(`   _id:             ${b._id}`);
    console.log(`   Parent email:    ${b.parent?.email || '(unknown)'}`);
    console.log(`   Class:           ${b.class?.name || '(unknown)'}`);
    console.log(`   Session date:    ${b.sessionDate}`);
    console.log(`   paymentStatus:   ${b.paymentStatus}`);
    console.log(`   fundsReleased:   ${b.fundsReleased}`);
    console.log(`   stripeTransferId:${b.stripeTransferId || '(not set)'}`);
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
