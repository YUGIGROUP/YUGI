/**
 * TEST HELPER — backdates a SavedVenue's savedAt so the 24h-7d prompt fires.
 *
 * Without this, you can't test piece 2 because no real saves are old enough.
 *
 * What it does:
 *   1. Finds your most recently saved venue
 *   2. Sets savedAt to 36 hours ago (squarely in the 24h-7d window)
 *   3. Resets promptShown = false (in case you've already dismissed it)
 *   4. Resets feedbackSubmitted = false
 *
 * After running:
 *   - Force-quit YUGI on iPhone
 *   - Reopen the app
 *   - Wait ~5 seconds (the launch delay)
 *   - Bottom sheet should appear: "How was [VenueName]?"
 *
 * Run from backend/ folder:
 *   railway run node scripts/backdate-saved-venue-for-prompt-test.js
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

  const collection = mongoose.connection.db.collection('savedvenues');

  const total = await collection.countDocuments({});
  console.log(`📦 Total SavedVenue records: ${total}`);

  if (total === 0) {
    console.log('❌ No saved venues exist. Save one in the iOS app first, then re-run.');
    await mongoose.disconnect();
    return;
  }

  const mostRecent = await collection
    .find({})
    .sort({ savedAt: -1 })
    .limit(1)
    .toArray();

  const target = mostRecent[0];
  console.log('');
  console.log(`🎯 Targeting most recent save:`);
  console.log(`   venueName: ${target.venueName}`);
  console.log(`   placeId:   ${target.placeId}`);
  console.log(`   savedAt:   ${target.savedAt?.toISOString()} (currently)`);

  const thirtySixHoursAgo = new Date(Date.now() - (36 * 60 * 60 * 1000));

  const result = await collection.updateOne(
    { _id: target._id },
    {
      $set: {
        savedAt: thirtySixHoursAgo,
        promptShown: false,
        promptShownAt: null,
        feedbackSubmitted: false,
        feedbackSubmittedAt: null,
      },
    }
  );

  console.log('');
  console.log(`✅ Updated ${result.modifiedCount} record.`);
  console.log(`   savedAt now:    ${thirtySixHoursAgo.toISOString()} (36h ago)`);
  console.log(`   promptShown:    false`);
  console.log(`   feedbackSubmitted: false`);
  console.log('');
  console.log('Next steps on iPhone:');
  console.log('  1. Force-quit YUGI (swipe up, swipe away)');
  console.log('  2. Reopen the app');
  console.log('  3. Wait ~5 seconds');
  console.log('  4. Prompt should appear: "How was ' + target.venueName + '?"');

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
