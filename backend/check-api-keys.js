#!/usr/bin/env node

/**
 * Quick script to check if API keys are configured
 * Run: node check-api-keys.js
 */

require('dotenv').config();

console.log('🔍 Checking API Key Configuration...\n');

const googlePlacesKey = process.env.GOOGLE_PLACES_API_KEY;
const foursquareKey = process.env.FOURSQUARE_API_KEY;

console.log('📋 Google Places API Key:');
if (googlePlacesKey && googlePlacesKey !== 'your_google_places_api_key_here') {
    console.log(`   ✅ Configured: ${googlePlacesKey.substring(0, 20)}...`);
} else {
    console.log('   ❌ NOT CONFIGURED');
    console.log('   ⚠️  Venue analysis will use fallback defaults');
}

console.log('\n📋 Foursquare API Key:');
if (foursquareKey && foursquareKey !== 'your_foursquare_api_key_here') {
    console.log(`   ✅ Configured: ${foursquareKey.substring(0, 20)}...`);
} else {
    console.log('   ❌ NOT CONFIGURED');
    console.log('   ⚠️  Will only use Google Places as fallback');
}

console.log('\n📊 Status Summary:');
if (googlePlacesKey && googlePlacesKey !== 'your_google_places_api_key_here') {
    console.log('   ✅ Google Places API: Ready for detailed venue analysis');
} else {
    console.log('   ❌ Google Places API: Not configured - using defaults');
}

if (foursquareKey && foursquareKey !== 'your_foursquare_api_key_here') {
    console.log('   ✅ Foursquare API: Ready as backup data source');
} else {
    console.log('   ⚠️  Foursquare API: Not configured - no backup source');
}

console.log('\n💡 To configure:');
console.log('   1. Add keys to Railway: Dashboard → Variables → Add Variable');
console.log('   2. Or add to backend/.env file for local development');
console.log('   3. Restart your backend server after adding keys\n');

