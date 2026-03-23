const mongoose = require('mongoose');
require('dotenv').config();

const Class = require('../src/models/Class');
const venueDataService = require('../src/services/venueDataService');

const DELAY_MS = 500; // 0.5s between calls to respect API rate limits

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function updateVenueData() {
  console.log('🔄 Connecting to database...');
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/yugi');
  console.log('✅ Connected to MongoDB\n');

  // Find all classes with a venue name and at least a street address
  const classes = await Class.find({
    'location.name': { $exists: true, $ne: '' },
    'location.address.street': { $exists: true, $ne: '' },
  }).lean();

  console.log(`📋 Found ${classes.length} classes to update\n`);

  let updated = 0;
  let skipped = 0;
  let failed  = 0;

  for (let i = 0; i < classes.length; i++) {
    const classDoc = classes[i];
    const venueName = classDoc.location.name;
    const address   = classDoc.location.address;

    console.log(`[${i + 1}/${classes.length}] ${classDoc.name}`);
    console.log(`   Venue: ${venueName} | ${address.street}, ${address.city}`);

    try {
      const venueData = await venueDataService.getRealVenueData(venueName, address, true);

      if (venueData.source === 'default') {
        console.log(`   ⚠️  No API data found — skipping update (kept existing data)`);
        skipped++;
      } else {
        const update = {
          'location.accessibilityNotes':     venueData.accessibilityNotes,
          'location.parkingInfo':            venueData.parkingInfo,
          'location.babyChangingFacilities': venueData.babyChangingFacilities,
        };

        if (venueData.coordinates) {
          update['location.coordinates.latitude']  = venueData.coordinates.latitude;
          update['location.coordinates.longitude'] = venueData.coordinates.longitude;
        }

        if (venueData.venueAccessibility) {
          update['venueAccessibility'] = venueData.venueAccessibility;
        }

        await Class.updateOne({ _id: classDoc._id }, { $set: update });

        const va = venueData.venueAccessibility;
        console.log(`   ✅ Updated (source: ${venueData.source})`);
        console.log(`   🦽 Pram entrance: ${va?.pramAccessibleEntrance ?? 'unknown'} | Baby changing: ${va?.hasBabyChanging ?? 'unknown'} | Parking: ${va?.parkingType ?? 'unknown'}`);
        console.log(`   🚇 Stations: ${va?.nearestStations?.map(s => `${s.name} (${s.distance}m)`).join(', ') || 'none'}`);
        console.log(`   🌤  Weather: ${va?.weatherForecast || 'unavailable'}`);
        updated++;
      }
    } catch (err) {
      console.log(`   ❌ Error: ${err.message}`);
      failed++;
    }

    console.log('');
    if (i < classes.length - 1) await sleep(DELAY_MS);
  }

  console.log('─'.repeat(50));
  console.log(`✅ Updated:  ${updated}`);
  console.log(`⚠️  Skipped:  ${skipped} (no API data)`);
  console.log(`❌ Failed:   ${failed}`);
  console.log('─'.repeat(50));

  await mongoose.disconnect();
  console.log('👋 Disconnected from MongoDB');
}

updateVenueData().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
