#!/usr/bin/env node
/**
 * Grant isAdmin: true to an existing user by email address.
 * Usage: node scripts/set-admin.js eva@yugi.uk
 *
 * Connects to MongoDB using MONGODB_URI from .env, sets isAdmin: true,
 * then exits.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User     = require('../src/models/User');

const email = process.argv[2];

if (!email) {
  console.error('Usage: node scripts/set-admin.js <email>');
  process.exit(1);
}

if (!process.env.MONGODB_URI) {
  console.error('MONGODB_URI is not set in .env');
  process.exit(1);
}

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);

  const result = await User.findOneAndUpdate(
    { email: email.toLowerCase().trim() },
    { $set: { isAdmin: true } },
    { new: true }
  ).select('email fullName userType isAdmin');

  if (!result) {
    console.error(`No user found with email "${email}"`);
    await mongoose.disconnect();
    process.exit(1);
  }

  console.log(`✅ Admin granted to ${result.email} (${result.fullName})`);
  console.log(`   isAdmin: ${result.isAdmin}, userType: ${result.userType}`);
  await mongoose.disconnect();
})();
