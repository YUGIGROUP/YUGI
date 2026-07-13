// Unit tests for the parent-verification aggregator (services/parentVerificationAggregator.js).
// Dependency-free, same DB-less pattern as the route tests: the two Mongoose
// models the aggregator touches are mocked at their boundaries —
//   VenueFactFeedback.find({placeId}).lean()  → the append-only event log
//   VenueEnrichment.findOne({placeId}).lean() → the enrichment doc (for AI confidence)
//   VenueEnrichment.updateOne(...)            → the write-back we assert on
// so nothing touches a real database.
//
// Focus: the parent-level dedupe. Confirmations/disputes are counted from ONE
// current vote per parent per fact (latest by createdAt wins), not from every
// appended event — which is what stops a single parent stacking repeats to
// cross the thresholds (3 verified, 2 disputed).

jest.mock('../../models/VenueFactFeedback', () => ({
  find: jest.fn(),
}));
jest.mock('../../models/VenueEnrichment', () => ({
  findOne: jest.fn(),
  updateOne: jest.fn(),
}));

const VenueFactFeedback = require('../../models/VenueFactFeedback');
const VenueEnrichment = require('../../models/VenueEnrichment');
const { aggregateOne } = require('../parentVerificationAggregator');

const PLACE_ID = 'place-xyz';
const NOW = new Date();
const OLD = new Date('2020-01-01T00:00:00Z'); // well outside the 30-day recency window

// Enrichment doc with a low AI confidence on the fact under test, so any
// 'parent_verified'/'disputed' outcome must come from parent votes, not the AI tier.
function enrichmentDoc(section = 'babyChanging') {
  return { placeId: PLACE_ID, enrichedData: { [section]: { confidence: 'low' } } };
}

// Build one feedback event. parentId is a plain string here; the aggregator keys
// the dedupe off `${parentId} ${factPath}`, which works identically to the
// hex-stringified ObjectId it sees on real lean() docs.
function evt(parentId, factPath, agreed, createdAt = NOW) {
  return { placeId: PLACE_ID, parentId, factPath, agreed, createdAt };
}

// Wire the mocks for a single aggregateOne run and return { result, pv } where
// `pv` is the parentVerification block written back via
// updateOne(query, { $set: { 'enrichedData.parentVerification': pv } }).
async function run(events, enrichment = enrichmentDoc()) {
  VenueFactFeedback.find.mockReturnValue({ lean: () => Promise.resolve(events) });
  VenueEnrichment.findOne.mockReturnValue({ lean: () => Promise.resolve(enrichment) });
  VenueEnrichment.updateOne.mockResolvedValue({ matchedCount: 1, modifiedCount: 1 });

  const result = await aggregateOne(PLACE_ID);
  const pv = VenueEnrichment.updateOne.mock.calls.length
    ? VenueEnrichment.updateOne.mock.calls[0][1].$set['enrichedData.parentVerification']
    : null;
  return { result, pv };
}

beforeEach(() => jest.clearAllMocks());

describe('parentVerificationAggregator — parent-level dedupe', () => {
  test('three distinct parents confirming a fact → parent_verified', async () => {
    const { result, pv } = await run([
      evt('p1', 'babyChanging.available', true),
      evt('p2', 'babyChanging.available', true),
      evt('p3', 'babyChanging.available', true),
    ]);

    const entry = pv.factSummary['babyChanging.available'];
    expect(entry.confirmations).toBe(3);
    expect(entry.disputes).toBe(0);
    expect(entry.confidenceTier).toBe('parent_verified');
    expect(result.confidenceTier).toBe('parent_verified');
    expect(result.totalConfirmations).toBe(3);
  });

  test('one parent confirming the same fact three times → NOT parent_verified (the attack this closes)', async () => {
    const { result, pv } = await run([
      evt('p1', 'babyChanging.available', true, new Date('2026-07-01T00:00:00Z')),
      evt('p1', 'babyChanging.available', true, new Date('2026-07-02T00:00:00Z')),
      evt('p1', 'babyChanging.available', true, new Date('2026-07-03T00:00:00Z')),
    ]);

    const entry = pv.factSummary['babyChanging.available'];
    expect(entry.confirmations).toBe(1); // three events collapse to one vote
    expect(entry.confidenceTier).not.toBe('parent_verified');
    expect(result.confidenceTier).not.toBe('parent_verified');
    expect(result.totalConfirmations).toBe(1);
  });

  test('a parent who confirmed then disputed → one dispute, not one of each (latest wins)', async () => {
    const { result, pv } = await run([
      evt('p1', 'babyChanging.available', true, OLD),  // superseded
      evt('p1', 'babyChanging.available', false, NOW), // current vote
    ]);

    const entry = pv.factSummary['babyChanging.available'];
    expect(entry.confirmations).toBe(0);
    expect(entry.disputes).toBe(1);
    expect(result.totalConfirmations).toBe(0);
    expect(result.totalDisputes).toBe(1);
  });

  test('two distinct parents disputing recently → disputed', async () => {
    const { result, pv } = await run([
      evt('p1', 'babyChanging.available', false),
      evt('p2', 'babyChanging.available', false),
    ]);

    const entry = pv.factSummary['babyChanging.available'];
    expect(entry.disputes).toBe(2);
    expect(entry.recentDisputes).toBe(2);
    expect(entry.confidenceTier).toBe('disputed');
    expect(result.confidenceTier).toBe('disputed');
    expect(result.totalDisputes).toBe(2);
  });
});
