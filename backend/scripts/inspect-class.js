/**
 * READ-ONLY — inspects classes by name pattern, showing the raw stored fields
 * AND the synthesized schedule the iOS app sees.
 *
 * No writes. Safe to run anytime.
 *
 * Run from backend/ folder:
 *   railway run node scripts/inspect-class.js
 *
 * Defaults to looking up classes that match Daisy's recent bookings.
 * Edit CLASS_NAME_FILTER to look at others.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Class = require('../src/models/Class');

const CLASS_NAME_FILTER = /baby coffee|mama brunch|little glow/i;

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('📊 Connected to MongoDB\n');

  const classes = await Class.find({ name: CLASS_NAME_FILTER })
    .sort({ createdAt: -1 })
    .limit(5);

  if (classes.length === 0) {
    console.log('❌ No matching classes found');
    process.exit(0);
  }

  console.log(`Found ${classes.length} class(es):\n`);

  for (const c of classes) {
    console.log('─'.repeat(60));
    console.log(`📚 Class: ${c.name}`);
    console.log(`   _id:               ${c._id}`);
    console.log(`   tier:              ${c.tier}`);
    console.log(`   provider:          ${c.provider}`);
    console.log(`   price:             £${c.price}`);
    console.log(`   createdAt:         ${c.createdAt}`);
    console.log('');
    console.log(`   --- raw schedule fields stored on disk ---`);
    console.log(`   classDates:        ${JSON.stringify(c.classDates ?? '(not set)')}`);
    console.log(`   recurringDays:     ${JSON.stringify(c.recurringDays ?? '(not set)')}`);
    console.log(`   timeSlots:         ${JSON.stringify(c.timeSlots ?? '(not set)')}`);
    console.log(`   duration:          ${c.duration ?? '(not set)'}`);
    console.log(`   startTime:         ${c.startTime ?? '(not set)'}`);
    console.log('');
    console.log(`   (the iOS app sees a synthesized 'schedule' object built from these fields by classes.js)`);
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
