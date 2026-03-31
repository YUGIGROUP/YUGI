const mongoose = require('mongoose');

const postVisitFeedbackSchema = new mongoose.Schema({
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    required: true,
  },
  classId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Class',
    default: null,
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  venuePlaceId: {
    type: String,
    default: null,
  },
  attended: {
    type: Boolean,
    required: true,
  },
  rating: {
    type: Number,
    min: 1,
    max: 5,
    default: null,
  },
  babyChangingAccurate: {
    type: Boolean,
    default: null,
  },
  pramAccessAccurate: {
    type: Boolean,
    default: null,
  },
  parkingAccurate: {
    type: Boolean,
    default: null,
  },
  comments: {
    type: String,
    default: null,
  },
  notificationSentAt: {
    type: Date,
    default: null,
  },
  respondedAt: {
    type: Date,
    default: Date.now,
  },
}, { timestamps: true, versionKey: false });

postVisitFeedbackSchema.index({ bookingId: 1 }, { unique: true });
postVisitFeedbackSchema.index({ classId: 1 });
postVisitFeedbackSchema.index({ venuePlaceId: 1 });

module.exports = mongoose.model('PostVisitFeedback', postVisitFeedbackSchema);
