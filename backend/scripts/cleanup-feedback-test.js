require('dotenv').config();
const mongoose = require('mongoose');
const VenueFactFeedback = require('../src/models/VenueFactFeedback');

const TEST_TAG = 'TEST_FEEDBACK_SEED';

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  const result = await VenueFactFeedback.deleteMany({ comment: { $regex: TEST_TAG } });
  console.log('Deleted', result.deletedCount, 'test events');
  await mongoose.disconnect();
})();
