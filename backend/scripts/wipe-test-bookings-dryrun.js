/**
 * DRY RUN — counts Stripe/test bookings that would be deleted.
 *
 * Targets bookings where the populated class name contains "stripe", "test",
 * or "demo" (case-insensitive). Does NOT delete anything.
 *
 * Run from backend/ folder:
 *   railway run node scripts/wipe-test-bookings-dryrun.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

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
  console.log(`📦 Total bookings in DB: ${totalBookings}`);

  // Find class IDs whose name matches test patterns
  const testClasses = await classes
    .find({ name: { $regex: /(stripe|test|demo)/i } })
    .project({ _id: 1, name: 1 })
    .toArray();

  console.log('');
  console.log(`🔍 Found ${testClasses.length} classes with test-like names:`);
  testClasses.forEach((cls, i) => {
    console.log(`  ${i + 1}. "${cls.name}"  (${cls._id})`);
  });

  if (testClasses.length === 0) {
    console.log('');
    console.log('✅ No test classes found. Nothing to clean up.');
    await mongoose.disconnect();
    return;
  }

  const testClassIds = testClasses.map((c) => c._id);
  const matchingBookings = await bookings.countDocuments({ class: { $in: testClassIds } });

  console.log('');
  console.log('═══════════════════════════════════════');
  console.log(`  Bookings linked to test classes: ${matchingBookings}`);
  console.log(`  Bookings to keep:                ${totalBookings - matchingBookings}`);
  console.log('═══════════════════════════════════════');

  // Sample of what would be deleted
  const sampleBookings = await bookings
    .find({ class: { $in: testClassIds } })
    .limit(5)
    .project({ _id: 1, class: 1, parent: 1, sessionDate: 1, status: 1 })
    .toArray();

  console.log('');
  console.log('🔍 Sample of 5 bookings that would be deleted:');
  sampleBookings.forEach((b, i) => {
    const className = testClasses.find((c) => c._id.equals(b.class))?.name || 'unknown';
    console.log(`  ${i + 1}. "${className}" — ${b.sessionDate?.toISOString() || 'no date'} — status: ${b.status}`);
  });

  // Also check related collections that might reference these bookings
  const postVisitFeedback = mongoose.connection.db.collection('postvisitfeedbacks');
  const matchingFeedback = await postVisitFeedback.countDocuments({
    bookingId: { $in: sampleBookings.map((b) => b._id) },
  });
  console.log('');
  console.log(`ℹ️  PostVisitFeedback records referencing these bookings: ${matchingFeedback} (in sample only)`);
  console.log('    These will be orphaned but harmless.');

  console.log('');
  console.log('✅ Dry run complete. Nothing deleted.');

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
