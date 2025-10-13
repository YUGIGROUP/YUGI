#!/usr/bin/env node

/**
 * Script to help you extract environment variables for Railway deployment
 * Run this script to see what environment variables you need to set in Railway
 */

const fs = require('fs');
const path = require('path');

console.log('🔧 YUGI Backend Environment Variables for Railway\n');

// Check if .env file exists
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
    console.log('📋 Copy these variables to Railway dashboard:\n');
    
    const envContent = fs.readFileSync(envPath, 'utf8');
    const lines = envContent.split('\n');
    
    lines.forEach(line => {
        line = line.trim();
        if (line && !line.startsWith('#') && line.includes('=')) {
            const [key, ...valueParts] = line.split('=');
            const value = valueParts.join('=');
            console.log(`${key}=${value}`);
        }
    });
    
    console.log('\n📝 Instructions:');
    console.log('1. Go to your Railway project dashboard');
    console.log('2. Click on "Variables" tab');
    console.log('3. Add each variable above');
    console.log('4. Make sure to update MONGODB_URI to your production database');
    console.log('5. Update any API keys to production keys if needed');
    
} else {
    console.log('❌ No .env file found. Please create one with your environment variables.');
    console.log('\n📝 Required variables:');
    console.log('- NODE_ENV=production');
    console.log('- PORT=3001');
    console.log('- MONGODB_URI=your_mongodb_connection_string');
    console.log('- JWT_SECRET=your_jwt_secret');
    console.log('- EMAIL_HOST=smtp.gmail.com');
    console.log('- EMAIL_PORT=587');
    console.log('- EMAIL_USER=your_email@gmail.com');
    console.log('- EMAIL_PASS=your_email_password');
    console.log('- GOOGLE_PLACES_API_KEY=your_google_places_key');
    console.log('- FOURSQUARE_API_KEY=your_foursquare_key');
    console.log('- FIREBASE_PROJECT_ID=your_firebase_project_id');
    console.log('- FIREBASE_PRIVATE_KEY_ID=your_firebase_private_key_id');
    console.log('- FIREBASE_PRIVATE_KEY=your_firebase_private_key');
    console.log('- FIREBASE_CLIENT_EMAIL=your_firebase_client_email');
    console.log('- FIREBASE_CLIENT_ID=your_firebase_client_id');
    console.log('- FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth');
    console.log('- FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token');
    console.log('- FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs');
    console.log('- FIREBASE_CLIENT_X509_CERT_URL=your_firebase_client_x509_cert_url');
    console.log('- STRIPE_SECRET_KEY=your_stripe_secret_key');
    console.log('- STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret');
}

console.log('\n🚀 After setting up Railway, update your iOS app:');
console.log('Edit YUGI/Services/APIService.swift line 32:');
console.log('case .production:');
console.log('    return "https://your-app-name.railway.app/api"');
