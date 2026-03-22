/**
 * YUGI — Auto-Geocode Middleware
 * 
 * Automatically geocodes class addresses when a class is created or updated
 * and the coordinates are missing (0, 0) or null.
 * 
 * Add this to your Class model file (src/models/Class.js) as a pre-save hook,
 * OR use the helper function in your classes route when creating/updating classes.
 * 
 * OPTION 1: Use as a helper function in your routes (recommended — simpler)
 * OPTION 2: Add as a Mongoose pre-save hook on the Class model
 */

const axios = require('axios');

const GOOGLE_API_KEY = process.env.GOOGLE_PLACES_API_KEY || process.env.GOOGLE_API_KEY;

// ============================================================
// OPTION 1: Helper function (call this in your routes)
// ============================================================

/**
 * Geocode a class's address if coordinates are missing.
 * Call this after creating or updating a class.
 * 
 * Usage in routes/classes.js:
 *   const { ensureCoordinates } = require('../services/autoGeocode');
 *   
 *   // After creating a class:
 *   const newClass = await Class.create(classData);
 *   await ensureCoordinates(newClass);
 *   
 *   // After updating a class:
 *   const updatedClass = await Class.findByIdAndUpdate(id, updates, { new: true });
 *   await ensureCoordinates(updatedClass);
 */
async function ensureCoordinates(classDoc) {
  if (!classDoc || !classDoc.location) return classDoc;

  const coords = classDoc.location.coordinates || {};
  const hasCoords = coords.latitude && coords.longitude && 
                    coords.latitude !== 0 && coords.longitude !== 0;

  if (hasCoords) return classDoc; // Already has valid coordinates

  const addressString = buildAddressString(classDoc.location);
  if (!addressString) return classDoc; // No address to geocode

  try {
    const result = await geocodeAddress(addressString);
    if (result) {
      classDoc.location.coordinates = {
        latitude: result.latitude,
        longitude: result.longitude,
      };
      
      // Save if it's a Mongoose document
      if (classDoc.save) {
        await classDoc.save();
        console.log(`📍 Auto-geocoded "${classDoc.name}": ${result.latitude}, ${result.longitude}`);
      }
    }
  } catch (error) {
    console.error(`⚠️ Auto-geocode failed for "${classDoc.name}":`, error.message);
    // Don't throw — geocoding failure shouldn't block class creation
  }

  return classDoc;
}

// ============================================================
// OPTION 2: Mongoose pre-save hook
// ============================================================

/**
 * Add this to your Class model file (src/models/Class.js):
 * 
 *   const { addGeocodingHook } = require('../services/autoGeocode');
 *   addGeocodingHook(classSchema);
 */
function addGeocodingHook(schema) {
  schema.pre('save', async function (next) {
    // Only geocode if location exists and coordinates are missing
    if (!this.location || !this.isModified('location.address')) {
      return next();
    }

    const coords = this.location.coordinates || {};
    const hasCoords = coords.latitude && coords.longitude && 
                      coords.latitude !== 0 && coords.longitude !== 0;

    if (hasCoords) return next();

    const addressString = buildAddressString(this.location);
    if (!addressString) return next();

    try {
      const result = await geocodeAddress(addressString);
      if (result) {
        this.location.coordinates = {
          latitude: result.latitude,
          longitude: result.longitude,
        };
        console.log(`📍 Auto-geocoded "${this.name}": ${result.latitude}, ${result.longitude}`);
      }
    } catch (error) {
      console.error(`⚠️ Auto-geocode failed for "${this.name}":`, error.message);
      // Don't block save on geocoding failure
    }

    next();
  });
}

// ============================================================
// SHARED UTILITIES
// ============================================================

async function geocodeAddress(address) {
  if (!GOOGLE_API_KEY) {
    console.warn('⚠️ No Google API key — skipping geocoding');
    return null;
  }

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

  return null;
}

function buildAddressString(location) {
  const addr = location.address || {};
  
  if (addr.formatted && addr.formatted.length > 5) {
    return addr.formatted;
  }

  const parts = [
    addr.street,
    addr.city,
    addr.postalCode,
    addr.country || 'United Kingdom',
  ].filter(Boolean);

  if (parts.length >= 2) {
    return parts.join(', ');
  }

  if (location.name && addr.city) {
    return `${location.name}, ${addr.city}, ${addr.country || 'United Kingdom'}`;
  }

  return null;
}

// ============================================================
// EXPORTS
// ============================================================

module.exports = {
  ensureCoordinates,
  addGeocodingHook,
  geocodeAddress,
  buildAddressString,
};
