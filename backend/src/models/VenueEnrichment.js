const mongoose = require('mongoose');

const parkingSchema = new mongoose.Schema({
  totalSpaces:   { type: Number, default: null },
  carParkNames:  [String],
  type:          { type: String, default: null }, // 'multi-storey' | 'surface' | 'underground' | 'mixed'
  blueBadgeBays: { type: Number, default: null },
  parentBays:    { type: Number, default: null },
  costInfo:      { type: String, default: null },
  ticketless:    { type: Boolean, default: null },
  evCharging:    { type: Boolean, default: null },
  source:        { type: Number, default: null },
  confidence:    { type: String, default: null }, // 'high' | 'medium' | 'low'
}, { _id: false });

const babyChangingSchema = new mongoose.Schema({
  available: { type: Boolean, default: null },
  location:  { type: String, default: null },
  details:   { type: String, default: null },
  source:    { type: Number, default: null },
  confidence:{ type: String, default: null }, // 'high' | 'medium' | 'low'
}, { _id: false });

const pramAccessSchema = new mongoose.Schema({
  stepFreeAccess: { type: Boolean, default: null },
  liftAvailable:  { type: Boolean, default: null },
  details:        { type: String, default: null },
  source:         { type: Number, default: null },
  confidence:     { type: String, default: null }, // 'high' | 'medium' | 'low'
}, { _id: false });

const publicTransportSchema = new mongoose.Schema({
  nearestStation: { type: String, default: null },
  walkingTime:    { type: String, default: null },
  busRoutes:      [String],
  source:         { type: Number, default: null },
  confidence:     { type: String, default: null }, // 'high' | 'medium' | 'low'
}, { _id: false });

const parentVerificationFactSummaryEntrySchema = new mongoose.Schema({
  confirmations: { type: Number, default: 0 },
  disputes:      { type: Number, default: 0 },
  lastConfirmed: { type: Date },
  lastDisputed:  { type: Date },
}, { _id: false });

const parentVerificationSchema = new mongoose.Schema({
  totalConfirmations:  { type: Number, default: 0 },
  totalDisputes:       { type: Number, default: 0 },
  recentDisputes30d:   { type: Number, default: 0 },
  factSummary:         {
    type: Map,
    of: parentVerificationFactSummaryEntrySchema,
    default: () => new Map(),
  },
  confidenceTier: {
    type: String,
    enum: ['ai_high', 'ai_medium', 'ai_low', 'parent_verified', 'disputed'],
    default: 'ai_medium',
  },
  lastAggregatedAt: { type: Date },
}, { _id: false });

const enrichedDataSchema = new mongoose.Schema({
  parking:              { type: parkingSchema,              default: {} },
  babyChanging:         { type: babyChangingSchema,         default: {} },
  pramAccess:           { type: pramAccessSchema,           default: {} },
  publicTransport:      { type: publicTransportSchema,      default: {} },
  additionalNotes:      { type: String, default: null },
  venueVerified:        { type: Boolean, default: null },
  parentVerification:   { type: parentVerificationSchema,    default: {} },
}, { _id: false });

const venueEnrichmentSchema = new mongoose.Schema({
  placeId:      { type: String, required: true, unique: true, index: true },
  venueName:    { type: String, required: true },
  enrichedData: { type: enrichedDataSchema, default: {} },
  sources:      [String],
  confidence:   { type: String, default: 'web_enriched', enum: ['web_enriched', 'parent_verified'] },
  expiresAt:    { type: Date, default: () => new Date(Date.now() + 90 * 24 * 60 * 60 * 1000) },
}, { timestamps: true, versionKey: false });

// TTL index — MongoDB auto-deletes documents after expiresAt
venueEnrichmentSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('VenueEnrichment', venueEnrichmentSchema);
