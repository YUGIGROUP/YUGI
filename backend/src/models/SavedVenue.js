const mongoose = require('mongoose');

const savedVenueSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  placeId: {
    type: String,
    required: true,
    index: true,
  },
  venueName: {
    type: String,
    required: true,
    trim: true,
  },
  savedAt: {
    type: Date,
    default: Date.now,
  },
  promptShown: {
    type: Boolean,
    default: false,
  },
  promptShownAt: {
    type: Date,
    default: null,
  },
  feedbackSubmitted: {
    type: Boolean,
    default: false,
  },
  feedbackSubmittedAt: {
    type: Date,
    default: null,
  },
  didNotVisit: {
    type: Boolean,
    default: false,
  },
  didNotVisitAt: {
    type: Date,
    default: null,
  },
}, { timestamps: true, versionKey: false });

savedVenueSchema.index({ userId: 1, placeId: 1 }, { unique: true });

module.exports = mongoose.model('SavedVenue', savedVenueSchema);
