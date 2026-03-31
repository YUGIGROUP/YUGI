const mongoose = require('mongoose');

const scheduledNotificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
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
  className: {
    type: String,
    required: true,
  },
  sendAt: {
    type: Date,
    required: true,
    index: true,
  },
  status: {
    type: String,
    enum: ['pending', 'sent', 'failed'],
    default: 'pending',
    index: true,
  },
}, { timestamps: true, versionKey: false });

scheduledNotificationSchema.index({ sendAt: 1, status: 1 });

module.exports = mongoose.model('ScheduledNotification', scheduledNotificationSchema);
