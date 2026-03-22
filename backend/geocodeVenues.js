/**
 * YUGI — Geocode Venue Coordinates
 * 
 * One-time script to fix classes with missing coordinates (0, 0).
 * Goes through all classes, geocodes their address using Google Places API,
 * and updates the coordinates in MongoDB.
 * 
 * Usage:
 *   node scripts/geocodeVenues.js
 * 
 * Requires:
 *   - GOOGLE_PLACES_API_KEY in environment variables
 *   - MONGODB_URI in environment variables
 *   - Or run from the backend folder where .env is configured
 */

require('dotenv').config();
const mongoose = require('mongoose');
const axios = require('axios');

// ============================================================
// CONFIG
// ============================================================

const MONGODB_URI = process.env.MONGODB_URI || process.env.MONGO_URI;
const GOOGLE_API_KEY = process.env.GOOGLE_PLACES_API_KEY || process.env.GOOGLE_API_KEY;

if (!MONGODB_URI) {
  console.error('❌ No MongoDB URI found. Set MONGODB_URI or MONGO_URI in your .env file.');
  process.exit(1);
}

if (!GOOGLE_API_KEY) {
  console.error('❌ No Google API key found. Set GOOGLE_PLACES_API_KEY in your .env file.');
  process.exit(1);
}

// ============================================================
// CLASS MODEL (simplified — just what we need)
// ============================================================

const classSchema = new mongoose.Schema({
  name: String,
  location: {
    name: String,
    address: {
      street: String,
      city: String,
      state: String,
      postalCode: String,
      country: String,
      formatted: String,
    },
    coordinates: {
      latitude: Number,
      longitude: Number,
    },
    accessibilityNotes: String,
    parkingInfo: String,
    babyChangingFacilities: String,
  },
}, { collection: 'classes', strict: false });

const Class = mongoose.model('Class', classSchema);

// ============================================================
// GEOCODING
// ============================================================

/**
 * Geocode an address string using Google Geocoding API.
 * Returns { latitude, longitude } or null if not found.
 */
async function geocodeAddress(address) {
  try {
    const response = await axios.get('https://maps.googleapis.com/maps/api/geocode/json', {
      params: {
        address: address,
        key: GOOGLE_API_KEY,
      },
    });

    if (response.data.status === 'OK' && response.data.results.length > 0) {
      const location = response.data.results[0].geometry.location;
      return {
        latitude: location.lat,
        longitude: location.lng,
      };
    }

    console.log(`  ⚠️  No results for: "${address}" (status: ${response.data.status})`);
    return null;
  } catch (error) {
    console.error(`  ❌ Geocoding error for "${address}":`, error.message);
    return null;
  }
}

/**
 * Build a full address string from the class location fields.
 */
function buildAddressString(location) {
  const addr = location.address || {};
  const parts = [
    addr.street,
    addr.city,
    addr.postalCode,
    addr.country || 'United Kingdom',
  ].filter(Boolean);

  // If we have a formatted address, prefer that
  if (addr.formatted && addr.formatted.length > 5) {
    return addr.formatted;
  }

  // Otherwise build from parts
  if (parts.length >= 2) {
    return parts.join(', ');
  }

  // Last resort: use venue name + city
  if (location.name && addr.city) {
    return `${location.name}, ${addr.city}, ${addr.country || 'United Kingdom'}`;
  }

  return null;
}

// ============================================================
// MAIN
// ============================================================

async function main() {
  console.log('🔗 Connecting to MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('✅ Connected to MongoDB\n');

  // Find all classes with missing or zero coordinates
  const classes = await Class.find({
    $or: [
      { 'location.coordinates.latitude': 0 },
      { 'location.coordinates.longitude': 0 },
      { 'location.coordinates.latitude': null },
      { 'location.coordinates.longitude': null },
      { 'location.coordinates': null },
    ],
  });

  console.log(`📍 Found ${classes.length} classes with missing coordinates\n`);

  if (classes.length === 0) {
    console.log('✅ All classes already have coordinates. Nothing to do!');
    await mongoose.disconnect();
    return;
  }

  let updated = 0;
  let failed = 0;

  for (const classDoc of classes) {
    const name = classDoc.name || 'Unknown class';
    const venueName = classDoc.location?.name || '';
    const addressString = buildAddressString(classDoc.location || {});

    console.log(`📍 Processing: "${name}" at "${venueName}"`);

    if (!addressString) {
      console.log(`  ⚠️  No address available — skipping\n`);
      failed++;
      continue;
    }

    console.log(`  🔍 Geocoding: "${addressString}"`);

    const coords = await geocodeAddress(addressString);

    if (coords) {
      // Update the class in MongoDB
      await Class.updateOne(
        { _id: classDoc._id },
        {
          $set: {
            'location.coordinates.latitude': coords.latitude,
            'location.coordinates.longitude': coords.longitude,
          },
        }
      );

      console.log(`  ✅ Updated: ${coords.latitude}, ${coords.longitude}\n`);
      updated++;
    } else {
      console.log(`  ❌ Could not geocode — skipping\n`);
      failed++;
    }

    // Small delay to respect Google API rate limits
    await new Promise(resolve => setTimeout(resolve, 200));
  }

  console.log('═══════════════════════════════════════');
  console.log(`✅ Updated: ${updated} classes`);
  console.log(`❌ Failed:  ${failed} classes`);
  console.log('═══════════════════════════════════════');

  await mongoose.disconnect();
  console.log('\n🔌 Disconnected from MongoDB');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  mongoose.disconnect();
  process.exit(1);
});
