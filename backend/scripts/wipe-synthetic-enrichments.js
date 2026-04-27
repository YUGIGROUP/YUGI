// One-off cleanup: delete VenueEnrichment docs cached against synthetic placeIds.
// These were created by an iOS bug that sent fake "yugi-..." placeIds to the
// enrichment endpoint, polluting the cache with empty enrichedData for 90 days.
// After fix, run once: node scripts/wipe-synthetic-enrichments.js

require('dotenv').config();
const mongoose = require('mongoose');
const VenueEnrichment = require('../src/models/VenueEnrichment');

async function main() {
  const uri = process.env.MONGODB_URI || process.env.MONGO_URI;
  if (!uri) { console.error('No MONGODB_URI or MONGO_URI in env'); process.exit(1); }
  await mongoose.connect(uri);
  console.log('Connected to MongoDB');

  const before = await VenueEnrichment.countDocuments({ placeId: /^yugi-/ });
  console.log(`Found ${before} synthetic-placeId enrichment docs to delete`);

  if (before > 0) {
    const result = await VenueEnrichment.deleteMany({ placeId: /^yugi-/ });
    console.log(`Deleted ${result.deletedCount} docs`);
  }

  await mongoose.disconnect();
  console.log('Done');
}

main().catch(err => { console.error(err); process.exit(1); });
