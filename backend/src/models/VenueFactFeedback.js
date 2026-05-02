const mongoose = require('mongoose');

/**
 * Append-only event log for parent-verified venue fact feedback.
 * Documents are never updated after creation.
 */
const venueFactFeedbackSchema = new mongoose.Schema({
  placeId: {
    type: String,
    required: true,
    index: true,
  },
  venueName: {
    type: String,
    required: true,
  },
  factPath: {
    type: String,
    required: true,
    index: true,
  },
  parentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  agreed: {
    type: Boolean,
    required: true,
  },
  comment: {
    type: String,
    maxlength: 500,
  },
  reportType: {
    type: String,
    enum: ['broken', 'no_longer_true', 'wrong_location', 'never_existed', 'other'],
  },
  source: {
    type: String,
    required: true,
    enum: ['save_prompt', 'mark_visited', 'report_inaccuracy'],
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
}, {
  versionKey: false,
});

venueFactFeedbackSchema.index({ placeId: 1, factPath: 1, createdAt: -1 });

module.exports = mongoose.model('VenueFactFeedback', venueFactFeedbackSchema);
