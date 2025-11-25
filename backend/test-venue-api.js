#!/usr/bin/env node

/**
 * Test script to verify venue analysis API is working with API keys
 * Run: node test-venue-api.js
 */

const axios = require('axios');
require('dotenv').config();

const RAILWAY_URL = process.env.RAILWAY_URL || 'https://yugi-production.up.railway.app';
const API_URL = `${RAILWAY_URL}/api`;

// Test venue - Polka Theatre (from your screenshot)
const testVenue = {
    venueName: "Polka Theatre",
    address: {
        street: "240 Broadway",
        city: "Wimbledon",
        state: "London",
        postalCode: "SW19 1SB",
        country: "United Kingdom"
    }
};

async function testVenueAnalysis() {
    console.log('🧪 Testing Venue Analysis API...\n');
    console.log(`📍 Testing venue: ${testVenue.venueName}`);
    console.log(`📍 Address: ${testVenue.address.street}, ${testVenue.address.city}\n`);
    
    // First, we need to login to get a token
    console.log('1️⃣ Logging in to get auth token...');
    
    try {
        // Try to login (you may need to adjust credentials)
        const loginResponse = await axios.post(`${API_URL}/auth/login`, {
            email: 'macy@test.com',
            firebaseUid: 'test-firebase-uid'
        });
        
        const token = loginResponse.data.token;
        console.log('   ✅ Login successful\n');
        
        // Now test venue analysis
        console.log('2️⃣ Testing venue analysis endpoint...');
        
        const analysisResponse = await axios.post(
            `${API_URL}/classes/venues/analyze`,
            testVenue,
            {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            }
        );
        
        const data = analysisResponse.data.data;
        
        console.log('\n✅ Venue Analysis Results:');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`📍 Venue: ${data.venueName}`);
        console.log(`🚗 Parking: ${data.parkingInfo}`);
        console.log(`👶 Baby Changing: ${data.babyChangingFacilities}`);
        console.log(`♿ Accessibility: ${data.accessibilityNotes || 'Not specified'}`);
        console.log(`📊 Data Source: ${data.source}`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        // Check if we got real API data or defaults
        if (data.source === 'google' || data.source === 'foursquare') {
            console.log('✅ SUCCESS: Real API data retrieved!');
            console.log('   The API keys are working correctly.\n');
        } else if (data.source === 'default' || data.source === 'fallback') {
            console.log('⚠️  WARNING: Using fallback/default data');
            console.log('   This means API keys might not be configured in Railway.\n');
            console.log('   Check Railway Variables:');
            console.log('   - GOOGLE_PLACES_API_KEY');
            console.log('   - FOURSQUARE_API_KEY\n');
        }
        
    } catch (error) {
        if (error.response) {
            console.error('❌ API Error:', error.response.status);
            console.error('   Message:', error.response.data.message || error.response.data);
        } else {
            console.error('❌ Network Error:', error.message);
        }
        console.log('\n💡 Make sure:');
        console.log('   1. Railway deployment is active');
        console.log('   2. API keys are set in Railway Variables');
        console.log('   3. Backend server is running\n');
    }
}

// Run the test
testVenueAnalysis();

