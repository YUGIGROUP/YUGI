require('dotenv').config();
const mongoose = require('mongoose');
const VenueEnrichment = require('../src/models/VenueEnrichment');

const MONGODB_URI = process.env.MONGODB_URI || process.env.MONGO_URI;

async function wipeTestEnrichments() {
  if (!MONGODB_URI) {
    throw new Error('Missing MongoDB URI: set MONGODB_URI or MONGO_URI');
  }

  await mongoose.connect(MONGODB_URI);
  console.log('Connected to MongoDB');

  const placeIdsToDelete = [
    'ChIJPy8Y5kIFdkgRxGSXw4Xjt3s', // Natural History Museum (current)
    'ChIJjajRAusLdkgRGh3kebzHyjQ', // Bentall Centre (current)
    'ChIJVxbp48Shc0gRq_0byyMJQ9A', // Rockwater (current)
  ];

  const deleteFilter = {
    $or: [
      { placeId: { $in: placeIdsToDelete } },
      { placeId: { $regex: '^yugi-' } },
    ],
  };

  const docsToDelete = await VenueEnrichment.find(deleteFilter, {
    _id: 0,
    placeId: 1,
    venueName: 1,
  }).lean();

  docsToDelete.forEach((doc) => {
    console.log(`Deleting placeId=${doc.placeId} venueName=${doc.venueName || ''}`);
  });

  const result = await VenueEnrichment.deleteMany(deleteFilter);
  console.log(`Deleted ${result.deletedCount} venue enrichment document(s).`);
}

wipeTestEnrichments()
  .catch((err) => {
    console.error('Failed to wipe test enrichments:', err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    try {
      await mongoose.disconnect();
      console.log('Disconnected from MongoDB');
    } catch (disconnectErr) {
      console.error('Error during MongoDB disconnect:', disconnectErr.message);
      process.exitCode = 1;
    }
  });
