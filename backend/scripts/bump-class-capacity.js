/**
 * ONE-OFF TEST SCRIPT — bumps a single class's maxCapacity by 5
 * so we can test bookings against a class that's hit capacity in testing.
 *
 * Updates ONLY maxCapacity on ONE class. Requires typing "YES".
 *
 * Run from backend/ folder:
 *   railway run node scripts/bump-class-capacity.js
 *
 * Edit CLASS_ID below to target a different class.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const readline = require('readline');
const Class = require('../src/models/Class');

const CLASS_ID = '6a17679e7d9a22666073eb3b';  // Baby Coffee morning (Sat 6 Jun)
const BUMP_BY = 5;

function ask(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(q, (a) => { rl.close(); resolve(a); }));
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('📊 Connected to MongoDB\n');

  const cls = await Class.findById(CLASS_ID);
  if (!cls) {
    console.log(`❌ Class ${CLASS_ID} not found`);
    process.exit(1);
  }

  const oldCapacity = cls.maxCapacity;
  const newCapacity = oldCapacity + BUMP_BY;

  console.log('Current state:');
  console.log(`  Class:           ${cls.name}`);
  console.log(`  _id:             ${cls._id}`);
  console.log(`  currentBookings: ${cls.currentBookings}`);
  console.log(`  maxCapacity:     ${oldCapacity}  (currently ${cls.currentBookings >= oldCapacity ? 'FULL' : 'has space'})`);
  console.log(`  New maxCapacity: ${newCapacity}  (will free up ${newCapacity - cls.currentBookings} spots)\n`);

  const answer = await ask('Type "YES" to confirm: ');
  if (answer !== 'YES') {
    console.log('❌ Aborted');
    await mongoose.disconnect();
    process.exit(0);
  }

  cls.maxCapacity = newCapacity;
  await cls.save();
  console.log(`\n✅ Updated maxCapacity from ${oldCapacity} to ${newCapacity}`);

  await mongoose.disconnect();
  process.exit(0);
}

main().catch(err => { console.error('❌ Error:', err); process.exit(1); });
