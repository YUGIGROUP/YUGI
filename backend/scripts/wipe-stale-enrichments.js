/**
 * DELETE — wipes stale venue enrichments.
 *
 * "Stale" = cached before the per-fact attribution commit (8453665)
 * which landed at 2026-05-03 22:07:43 +0100.
 *
 * Requires typing "DELETE" to confirm. No accidental wipes.
 *
 * Run from backend/ folder:
 *   railway run node wipe-stale-enrichments.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const readline = require('readline');

const CUTOFF = new Date('2026-05-03T22:07:43+01:00');

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
  console.log(`📅 Cutoff: ${CUTOFF.toISOString()}`);

  const collection = mongoose.connection.db.collection('venueenrichments');

  const staleCount = await collection.countDocuments({ updatedAt: { $lt: CUTOFF } });
  const totalCount = await collection.countDocuments({});

  console.log('');
  console.log('═══════════════════════════════════════');
  console.log(`  Will delete:   ${staleCount} stale records`);
  console.log(`  Will keep:     ${totalCount - staleCount} fresh records`);
  console.log('═══════════════════════════════════════');
  console.log('');

  if (staleCount === 0) {
    console.log('✅ Nothing to delete. Exiting.');
    await mongoose.disconnect();
    return;
  }

  const answer = await ask('Type DELETE to confirm, anything else to abort: ');

  if (answer.trim() !== 'DELETE') {
    console.log('❌ Aborted. Nothing deleted.');
    await mongoose.disconnect();
    return;
  }

  console.log('');
  console.log('🗑️  Deleting...');

  const result = await collection.deleteMany({ updatedAt: { $lt: CUTOFF } });

  console.log(`✅ Deleted ${result.deletedCount} stale enrichment records.`);
  console.log('');
  console.log('Next: each affected venue will re-enrich on its next view in the iOS app,');
  console.log('using the current prompt with per-fact attribution.');

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
