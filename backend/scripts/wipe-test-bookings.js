/**
 * DELETE — wipes test bookings AND test classes from the database.
 *
 * Targets:
 *   - All classes whose name contains "stripe", "test", or "demo" (case-insensitive)
 *   - All bookings linked to those test classes
 *
 * Requires typing "DELETE" to confirm. No accidental wipes.
 *
 * Run from backend/ folder:
 *   railway run node scripts/wipe-test-bookings.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const readline = require('readline');

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    console.error('❌ MONGODB_URI not set');
    process.exit(1);
  }

  await mongoose.connect(uri);
  console.log('📊 Connected to MongoDB');

  const bookings = mongoose.connection.db.collection('bookings');
  const classes = mongoose.connection.db.collection('classes');

  const totalBookings = await bookings.countDocuments({});
  const totalClasses = await classes.countDocuments({});

  const testClasses = await classes
    .find({ name: { $regex: /(stripe|test|demo)/i } })
    .project({ _id: 1, name: 1 })
    .toArray();

  if (testClasses.length === 0) {
    console.log('✅ No test classes found. Nothing to delete.');
    await mongoose.disconnect();
    return;
  }

  const testClassIds = testClasses.map((c) => c._id);
  const matchingBookings = await bookings.countDocuments({ class: { $in: testClassIds } });

  console.log('');
  console.log('═══════════════════════════════════════');
  console.log(`  Will delete:`);
  console.log(`    ${testClasses.length} test classes`);
  console.log(`    ${matchingBookings} bookings linked to test classes`);
  console.log(`  Will keep:`);
  console.log(`    ${totalClasses - testClasses.length} classes`);
  console.log(`    ${totalBookings - matchingBookings} bookings`);
  console.log('═══════════════════════════════════════');
  console.log('');
  console.log('Test classes to be deleted:');
  testClasses.forEach((cls, i) => {
    console.log(`  ${i + 1}. "${cls.name}"`);
  });
  console.log('');

  const answer = await ask('Type DELETE to confirm, anything else to abort: ');

  if (answer.trim() !== 'DELETE') {
    console.log('❌ Aborted. Nothing deleted.');
    await mongoose.disconnect();
    return;
  }

  console.log('');
  console.log('🗑️  Deleting bookings...');
  const bookingsResult = await bookings.deleteMany({ class: { $in: testClassIds } });
  console.log(`   ✅ Deleted ${bookingsResult.deletedCount} bookings.`);

  console.log('🗑️  Deleting classes...');
  const classesResult = await classes.deleteMany({ _id: { $in: testClassIds } });
  console.log(`   ✅ Deleted ${classesResult.deletedCount} classes.`);

  console.log('');
  console.log('Next: sign in to YUGI on iPhone — Stripe test prompts should be gone.');
  console.log('SuStudio post-save prompt should now have a chance to surface.');

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
