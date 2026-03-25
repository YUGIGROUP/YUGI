const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema({
  latitude:  { type: Number },
  longitude: { type: Number },
}, { _id: false });

const eventSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  eventType: {
    type: String,
    required: true,
    enum: [
      'class_viewed',
      'class_searched',
      'booking_started',
      'booking_completed',
      'booking_cancelled',
      'venue_checked',
      'filter_used',
      'class_favorited',
      'doability_warning_seen',
    ],
  },
  classId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Class',
    default: null,
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
  sessionId: {
    type: String,
  },
  parentLocation: {
    type: locationSchema,
    default: null,
  },
  venueLocation: {
    type: locationSchema,
    default: null,
  },
}, { versionKey: false });

eventSchema.index({ userId: 1, timestamp: -1 });
eventSchema.index({ eventType: 1, timestamp: -1 });
eventSchema.index({ classId: 1, eventType: 1 });
eventSchema.index({ sessionId: 1 });

module.exports = mongoose.model('Event', eventSchema);
