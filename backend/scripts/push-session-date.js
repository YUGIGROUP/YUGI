/**
 * ONE-OFF TEST SCRIPT — pushes a booking's session date 3 days into the future
 * so we can test the >24h cancellation refund path.
 * Updates ONLY sessionDate on ONE booking. Requires typing "YES".
 *
 * Run: railway run node scripts/push-session-date.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const readline = require('readline');
const Booking = require('../src/models/Booking');

function ask(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(q, (a) => { rl.close(); resolve(a); }));
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('📊 Connected to MongoDB\n');

  const BOOKING_NUMBER = 'YUGI260527001';
  const booking = await Booking.findOne({ bookingNumber: BOOKING_NUMBER });
  if (!booking) {
    console.log(`❌ Booking ${BOOKING_NUMBER} not found`);
    process.exit(1);
  }

  const newSessionDate = new Date();
  newSessionDate.setDate(newSessionDate.getDate() + 3);

  console.log('Current state:');
  console.log(`  Booking:        ${booking.bookingNumber}`);
  console.log(`  Status:         ${booking.status}`);
  console.log(`  paymentStatus:  ${booking.paymentStatus}`);
  console.log(`  Current session: ${booking.sessionDate}`);
  console.log(`  New session:     ${newSessionDate}  (3 days out, >24h window)\n`);

  const answer = await ask('Type "YES" to confirm: ');
  if (answer !== 'YES') {
    console.log('❌ Aborted');
    await mongoose.disconnect();
    process.exit(0);
  }

  booking.sessionDate = newSessionDate;
  await booking.save();
  console.log(`\n✅ Updated sessionDate to ${newSessionDate}`);

  await mongoose.disconnect();
  process.exit(0);
}

main().catch(err => { console.error('❌ Error:', err); process.exit(1); });
