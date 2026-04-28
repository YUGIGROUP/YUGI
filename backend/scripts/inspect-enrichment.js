require('dotenv').config();
const mongoose = require('mongoose');
const VenueEnrichment = require('../src/models/VenueEnrichment');

const TARGET_PLACE_ID = 'ChIJPy8Y5kIFdkgRxGSXw4Xjt3s';

async function main() {
  const uri = process.env.MONGODB_URI || process.env.MONGO_URI;
  if (!uri) {
    console.error('No MONGODB_URI or MONGO_URI in env');
    process.exit(1);
  }

  try {
    await mongoose.connect(uri);

    const doc = await VenueEnrichment.findOne({ placeId: TARGET_PLACE_ID });
    console.log(JSON.stringify(doc, null, 2));
  } finally {
    await mongoose.disconnect();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
