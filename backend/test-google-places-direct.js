/**
 * Direct test of Google Places API to debug the "Cannot read properties of undefined (reading 'name')" error
 * 
 * Run with: node test-google-places-direct.js
 */

const axios = require('axios');
require('dotenv').config();

const GOOGLE_PLACES_API_KEY = process.env.GOOGLE_PLACES_API_KEY;

async function testGooglePlacesAPI() {
  console.log('🧪 Testing Google Places API directly...\n');
  
  if (!GOOGLE_PLACES_API_KEY) {
    console.error('❌ GOOGLE_PLACES_API_KEY not found in environment variables');
    return;
  }
  
  console.log(`✅ API Key found: ${GOOGLE_PLACES_API_KEY.substring(0, 10)}...`);
  console.log(`✅ API Key length: ${GOOGLE_PLACES_API_KEY.length}`);
  console.log(`✅ API Key starts with AIza: ${GOOGLE_PLACES_API_KEY.startsWith('AIza')}\n`);
  
  const venueName = 'Polka Theatre';
  const address = {
    street: '240 The Broadway',
    city: 'London',
    postalCode: 'SW19 1SB',
    country: 'United Kingdom'
  };
  
  const query = `${venueName} ${address.street} ${address.city}`;
  const encodedQuery = encodeURIComponent(query);
  
  console.log(`🔍 Testing search query: "${query}"`);
  console.log(`🔍 Encoded query: "${encodedQuery}"\n`);
  
  const searchUrl = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodedQuery}&key=${GOOGLE_PLACES_API_KEY}`;
  console.log(`🔗 Search URL: ${searchUrl.replace(GOOGLE_PLACES_API_KEY, 'API_KEY_HIDDEN')}\n`);
  
  try {
    // Step 1: Test Text Search API
    console.log('📡 Step 1: Calling Text Search API...');
    const searchResponse = await axios.get(searchUrl);
    
    console.log('✅ Search API Response received');
    console.log('📊 Response status:', searchResponse.status);
    console.log('📊 Response headers:', Object.keys(searchResponse.headers));
    console.log('📊 Response data type:', typeof searchResponse.data);
    console.log('📊 Response data keys:', Object.keys(searchResponse.data || {}));
    
    if (searchResponse.data) {
      console.log('📊 Response data.status:', searchResponse.data.status);
      console.log('📊 Response data.results exists:', !!(searchResponse.data.results));
      console.log('📊 Response data.results is array:', Array.isArray(searchResponse.data.results));
      console.log('📊 Response data.results length:', searchResponse.data.results?.length || 0);
      
      if (searchResponse.data.results && searchResponse.data.results.length > 0) {
        const firstResult = searchResponse.data.results[0];
        console.log('\n📊 First result structure:');
        console.log('  - Type:', typeof firstResult);
        console.log('  - Is null:', firstResult === null);
        console.log('  - Is undefined:', firstResult === undefined);
        console.log('  - Keys:', Object.keys(firstResult || {}));
        
        if (firstResult && typeof firstResult === 'object') {
          console.log('  - Has place_id:', 'place_id' in firstResult);
          console.log('  - place_id value:', firstResult.place_id);
          console.log('  - Has name:', 'name' in firstResult);
          console.log('  - name value:', firstResult.name);
          
          if (firstResult.place_id) {
            // Step 2: Test Place Details API
            console.log('\n📡 Step 2: Calling Place Details API...');
            const placeId = firstResult.place_id;
            const detailsUrl = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=name,formatted_address,geometry,place_id,types,opening_hours,photos,reviews,wheelchair_accessible_entrance,editorial_summary&key=${GOOGLE_PLACES_API_KEY}`;
            
            console.log(`🔗 Details URL: ${detailsUrl.replace(GOOGLE_PLACES_API_KEY, 'API_KEY_HIDDEN')}\n`);
            
            const detailsResponse = await axios.get(detailsUrl);
            
            console.log('✅ Details API Response received');
            console.log('📊 Details response status:', detailsResponse.status);
            console.log('📊 Details response.data exists:', !!(detailsResponse.data));
            console.log('📊 Details response.data.status:', detailsResponse.data?.status);
            console.log('📊 Details response.data.result exists:', !!(detailsResponse.data?.result));
            
            if (detailsResponse.data && detailsResponse.data.result) {
              const result = detailsResponse.data.result;
              console.log('\n📊 Details result structure:');
              console.log('  - Type:', typeof result);
              console.log('  - Is null:', result === null);
              console.log('  - Is undefined:', result === undefined);
              console.log('  - Keys:', Object.keys(result || {}));
              console.log('  - Has name:', 'name' in result);
              console.log('  - name value:', result.name);
              console.log('  - Has formatted_address:', 'formatted_address' in result);
              console.log('  - Has geometry:', 'geometry' in result);
              
              console.log('\n✅ SUCCESS: Both APIs working correctly!');
              console.log('📋 Place name:', result.name);
              console.log('📋 Address:', result.formatted_address);
              if (result.geometry && result.geometry.location) {
                console.log('📋 Coordinates:', result.geometry.location.lat, result.geometry.location.lng);
              }
            } else {
              console.log('\n❌ ERROR: Details response missing result');
              console.log('📊 Full details response:', JSON.stringify(detailsResponse.data, null, 2));
            }
          } else {
            console.log('\n❌ ERROR: First result missing place_id');
            console.log('📊 Full first result:', JSON.stringify(firstResult, null, 2));
          }
        } else {
          console.log('\n❌ ERROR: First result is not an object');
          console.log('📊 First result:', firstResult);
        }
      } else {
        console.log('\n❌ ERROR: No results in search response');
        console.log('📊 Full search response:', JSON.stringify(searchResponse.data, null, 2));
      }
    } else {
      console.log('\n❌ ERROR: No data in search response');
      console.log('📊 Full response:', JSON.stringify(searchResponse, null, 2));
    }
    
  } catch (error) {
    console.error('\n❌ ERROR occurred:');
    console.error('  - Message:', error.message);
    console.error('  - Type:', error.constructor.name);
    
    if (error.response) {
      console.error('  - Response status:', error.response.status);
      console.error('  - Response statusText:', error.response.statusText);
      console.error('  - Response data:', JSON.stringify(error.response.data, null, 2));
    }
    
    if (error.stack) {
      console.error('  - Stack:', error.stack);
    }
  }
}

// Run the test
testGooglePlacesAPI()
  .then(() => {
    console.log('\n✅ Test completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  });

