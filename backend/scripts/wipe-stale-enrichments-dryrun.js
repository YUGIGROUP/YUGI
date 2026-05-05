/**
 * DRY RUN — counts stale venue enrichments without deleting anything.
 *
 * "Stale" = cached before the per-fact attribution commit (8453665)
 * which landed at 2026-05-03 22:07:43 +0100.
 *
 * Run from backend/ folder:
 *   node wipe-stale-enrichments-dryrun.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

const CUTOFF = new Date('2026-05-03T22:07:43+01:00');

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    console.error('❌ MONGODB_URI not set in .env');
    process.exit(1);
  }

  await mongoose.connect(uri);
  console.log('📊 Connected to MongoDB');
  console.log(`📅 Cutoff: ${CUTOFF.toISOString()}`);

  const collection = mongoose.connection.db.collection('venueenrichments');

  const total = await collection.countDocuments({});
  const stale = await collection.countDocuments({ updatedAt: { $lt: CUTOFF } });
  const fresh = await collection.countDocuments({ updatedAt: { $gte: CUTOFF } });
  const noTimestamp = await collection.countDocuments({ updatedAt: { $exists: false } });

  console.log('');
  console.log('═══════════════════════════════════════');
  console.log(`  Total enrichments:       ${total}`);
  console.log(`  Fresh (post-cutoff):     ${fresh}`);
  console.log(`  Stale (pre-cutoff):      ${stale}`);
  console.log(`  No updatedAt timestamp:  ${noTimestamp}`);
  console.log('═══════════════════════════════════════');
  console.log('');
  console.log('🔍 Sample of 5 stale records (would be deleted):');

  const samples = await collection
    .find({ updatedAt: { $lt: CUTOFF } })
    .limit(5)
    .project({ venueName: 1, placeId: 1, updatedAt: 1 })
    .toArray();

  samples.forEach((doc, i) => {
    console.log(`  ${i + 1}. ${doc.venueName || '(no name)'} — ${doc.placeId} — ${doc.updatedAt?.toISOString() || 'no timestamp'}`);
  });

  if (noTimestamp > 0) {
    console.log('');
    console.log(`⚠️  ${noTimestamp} record(s) have no updatedAt — these would NOT be deleted by the cutoff query.`);
    console.log('    Decide separately whether to wipe those too.');
  }

  console.log('');
  console.log('✅ Dry run complete. Nothing deleted.');

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
