const mongoose = require('mongoose');

const intakeResponseSchema = new mongoose.Schema({
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    required: true
  },
  classId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Class',
    required: true
  },
  parentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  providerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  answers: [{
    questionText: { type: String, required: true },
    answerType:   { type: String, required: true },
    answer:       { type: String, default: '' }
  }],
  submittedAt: {
    type: Date,
    default: Date.now
  }
});

intakeResponseSchema.index({ classId: 1, parentId: 1 });
intakeResponseSchema.index({ bookingId: 1 });

module.exports = mongoose.model('IntakeResponse', intakeResponseSchema);
