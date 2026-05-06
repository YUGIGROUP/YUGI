const mongoose = require('mongoose');

const rawAccessibilityPairSchema = new mongoose.Schema(
  {
    key:   { type: String, required: true },
    value: { type: String, required: true },
  },
  { _id: false }
);

const stationAccessibilitySchema = new mongoose.Schema(
  {
    stationName: {
      type:     String,
      required: true,
      trim:     true,
      index:    true,
    },
    searchAlias: {
      type:     String,
      required: true,
      trim:     true,
      lowercase: true,
      unique:   true,
      index:    true,
    },
    naptanId: {
      type:   String,
      trim:   true,
      sparse: true,
      unique: true,
      index:  true,
    },
    hubNaptanId: {
      type: String,
      trim: true,
      default: null,
    },
    stopType: {
      type: String,
      trim: true,
      default: null,
    },
    accessViaLift: {
      type: String,
      default: null,
    },
    liftCount: {
      type:    Number,
      default: 0,
    },
    escalatorCount: {
      type:    Number,
      default: 0,
    },
    rawAccessibilityPairs: {
      type: [rawAccessibilityPairSchema],
      default: [],
    },
    resolvedStepFree: {
      type: String,
      enum: ['confirmed', 'unknown'],
      default: 'unknown',
      index: true,
    },
    lookupFailed: {
      type:    Boolean,
      default: false,
      index:   true,
    },
    fetchedAt: {
      type:    Date,
      default: Date.now,
    },
    cacheExpiresAt: {
      type:    Date,
      required: true,
      index:   true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('StationAccessibility', stationAccessibilitySchema);
