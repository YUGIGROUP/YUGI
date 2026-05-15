const mongoose = require('mongoose');

const documentSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  documentType: {
    type: String,
    enum: ['insurance', 'dbs', 'qualifications', 'business_registration'],
    required: true,
    index: true,
  },
  s3Key: {
    type: String,
    required: true,
  },
  originalFileName: {
    type: String,
    required: true,
    trim: true,
  },
  mimeType: {
    type: String,
    required: true,
  },
  sizeBytes: {
    type: Number,
    required: true,
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'expired'],
    default: 'pending',
    index: true,
  },
  uploadedAt: {
    type: Date,
    default: Date.now,
  },
  reviewedAt: {
    type: Date,
    default: null,
  },
  reviewedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  rejectionReason: {
    type: String,
    trim: true,
    default: null,
  },
  expiryDate: {
    type: Date,
    default: null,
    index: true,
  },
}, { timestamps: true, versionKey: false });

// Compound index for "list this user's documents by type, most recent first"
documentSchema.index({ userId: 1, documentType: 1, uploadedAt: -1 });

module.exports = mongoose.model('Document', documentSchema);
