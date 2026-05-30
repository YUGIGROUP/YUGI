/**
 * One-shot funds-release runner. Runs the auto-completion sweep, then the
 * release sweep, then disconnects. Use this to validate Phase 2b in the
 * sandbox without waiting for the 10-minute cron tick.
 *
 * THIS CALLS REAL stripe.transfers.create FOR EVERY HELD BOOKING PAST ITS
 * fundsReleaseDate. Before running, confirm STRIPE_SECRET_KEY is an sk_test_
 * key — the script will refuse to run against a live key.
 *
 * Run from backend/ folder:
 *   railway run node scripts/run-funds-release-once.js
 *   (or, locally with .env loaded:  node scripts/run-funds-release-once.js)
 */

require('dotenv').config();
const mongoose = require('mongoose');

const SECRET = process.env.STRIPE_SECRET_KEY || '';
if (!SECRET.startsWith('sk_test_')) {
  console.error('❌ Refusing to run: STRIPE_SECRET_KEY is not an sk_test_ key.');
  console.error('   This script moves real money in live mode. Aborting.');
  process.exit(1);
}

async function main() {
  if (!process.env.MONGODB_URI) {
    console.error('❌ MONGODB_URI not set');
    process.exit(1);
  }
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('📊 Connected to MongoDB');

  const { runAutoCompletionSweep, runReleaseSweep } = require('../src/services/fundsReleaseService');

  console.log('\n▶ Auto-completion sweep…');
  const completion = await runAutoCompletionSweep();
  console.log(`   scanned=${completion.scanned}, completed=${completion.completed}`);

  console.log('\n▶ Release sweep…');
  const release = await runReleaseSweep();
  console.log(`   scanned=${release.scanned}, released=${release.released}, skipped=${release.skipped}, failed=${release.failed}`);

  console.log('\n✅ Done');
  await mongoose.disconnect();
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
