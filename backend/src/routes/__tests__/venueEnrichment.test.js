// Route-level tests for Claude-backed venue enrichment —
// GET /api/venues/:placeId/enrichment (routes/venues.js) — driven through the
// exported Express app with supertest. Same DB-less pattern as the other route
// tests: the User model (for protect), the VenueEnrichment cache/store, and the
// Anthropic SDK are mocked at their boundaries so nothing touches a real
// database or the network.
//
// Identity guard: STEP 1 verification is prompt-driven, but the route also
// enforces it in code — when Claude returns `venueVerified: false` (its sources
// referred to the wrong branch), routes/venues.js refuses to persist and
// degrades to the empty shape rather than caching a wrong-venue ("Rockwater")
// response verbatim. See the `venueVerified: false` test below. Absent/null
// verification passes through unchanged.

const jwt = require('jsonwebtoken');

// Anthropic SDK mock — venues.js does `new Anthropic({apiKey})` at module load
// then `anthropic.messages.create(...)` in the handler.
const mockMessagesCreate = jest.fn();
jest.mock('@anthropic-ai/sdk', () =>
  jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate },
  }))
);

// VenueEnrichment: findOne is the cache read; findOneAndUpdate is the 90-day
// upsert. We assert the upsert is NOT called on any degradation branch.
jest.mock('../../models/VenueEnrichment', () => ({
  findOne: jest.fn(),
  findOneAndUpdate: jest.fn(),
}));

// protect() does `User.findById(id).select('-password')`.
jest.mock('../../models/User', () => ({
  findById: jest.fn(),
}));

const request = require('supertest');
const User = require('../../models/User');
const VenueEnrichment = require('../../models/VenueEnrichment');
const app = require('../../server');

const PLACE_ID = 'place-abc';

function loginAs(overrides = {}) {
  const doc = { id: 'user-1', _id: 'user-1', isActive: true, isAdmin: false, userType: 'parent', ...overrides };
  doc.select = jest.fn().mockReturnValue(doc);
  User.findById.mockReturnValue(doc);
  return doc;
}

function tokenFor(id) {
  return jwt.sign({ id }, process.env.JWT_SECRET);
}

function getEnrichment(query = 'venueName=Test%20Venue&address=1%20High%20St') {
  return request(app)
    .get(`/api/venues/${PLACE_ID}/enrichment?${query}`)
    .set('Authorization', `Bearer ${tokenFor('user-1')}`);
}

// Build an Anthropic response whose text blocks contain `rawText`.
function claudeText(rawText) {
  return { content: [{ type: 'text', text: rawText }] };
}

beforeEach(() => {
  jest.clearAllMocks();
  // Default: cache miss and a store that echoes back the upserted document.
  VenueEnrichment.findOne.mockResolvedValue(null);
  VenueEnrichment.findOneAndUpdate.mockImplementation((_query, update) => Promise.resolve(update));
});

describe('GET /api/venues/:placeId/enrichment', () => {
  test('cache hit — returns cached enrichment and makes NO external call', async () => {
    loginAs();
    VenueEnrichment.findOne.mockResolvedValue({
      placeId: PLACE_ID,
      venueName: 'Test Venue',
      enrichedData: { parking: { costInfo: 'Free', source: 0, confidence: 'high' } },
      sources: ['https://example.com'],
      confidence: 'web_enriched',
      createdAt: new Date('2026-01-01T00:00:00Z'),
    });

    const res = await getEnrichment();

    expect(res.status).toBe(200);
    expect(res.body.enrichedData.parking.costInfo).toBe('Free');
    expect(res.body.confidence).toBe('web_enriched');
    // Short-circuit: neither Claude nor the store's write path is touched.
    expect(mockMessagesCreate).not.toHaveBeenCalled();
    expect(VenueEnrichment.findOneAndUpdate).not.toHaveBeenCalled();
  });

  test('happy path — Claude JSON persisted with per-fact source/confidence preserved', async () => {
    loginAs();
    mockMessagesCreate.mockResolvedValue(
      claudeText(
        JSON.stringify({
          venueVerified: true,
          parking: { costInfo: 'Free for Blue Badge', source: 0, confidence: 'high' },
          babyChanging: { available: true, source: 1, confidence: 'medium' },
          sources: ['https://venue.example/access', 'https://council.example'],
        })
      )
    );

    const res = await getEnrichment();

    expect(res.status).toBe(200);
    // Per-fact attribution and confidence tiers survive verbatim.
    expect(res.body.enrichedData.parking).toEqual({ costInfo: 'Free for Blue Badge', source: 0, confidence: 'high' });
    expect(res.body.enrichedData.babyChanging).toEqual({ available: true, source: 1, confidence: 'medium' });
    expect(res.body.sources).toEqual(['https://venue.example/access', 'https://council.example']);
    expect(res.body.confidence).toBe('web_enriched');

    // Persisted once, with sources split out of enrichedData and the hardcoded tier.
    expect(VenueEnrichment.findOneAndUpdate).toHaveBeenCalledTimes(1);
    const [query, update] = VenueEnrichment.findOneAndUpdate.mock.calls[0];
    expect(query).toEqual({ placeId: PLACE_ID });
    expect(update.confidence).toBe('web_enriched');
    expect(update.sources).toEqual(['https://venue.example/access', 'https://council.example']);
    expect(update.enrichedData.parking.confidence).toBe('high');
    expect(update.enrichedData).not.toHaveProperty('sources');
  });

  test('Anthropic failure — degrades to empty enrichment, nothing persisted', async () => {
    loginAs();
    mockMessagesCreate.mockRejectedValue(new Error('anthropic 529 overloaded'));

    const res = await getEnrichment();

    expect(res.status).toBe(200);
    expect(res.body.enrichedData).toEqual({});
    expect(res.body.sources).toEqual([]);
    expect(res.body.confidence).toBe('web_enriched');
    // No half-enriched state written.
    expect(VenueEnrichment.findOneAndUpdate).not.toHaveBeenCalled();
  });

  test('unparseable Claude response — degrades to empty enrichment, nothing persisted', async () => {
    loginAs();
    mockMessagesCreate.mockResolvedValue(
      claudeText("I'm sorry, I couldn't find reliable information for this venue.")
    );

    const res = await getEnrichment();

    expect(res.status).toBe(200);
    expect(res.body.enrichedData).toEqual({});
    expect(res.body.sources).toEqual([]);
    expect(VenueEnrichment.findOneAndUpdate).not.toHaveBeenCalled();
  });

  test('venueVerified: false — wrong-venue response rejected, degrades to empty, nothing persisted', async () => {
    loginAs();
    // Claude verified the sources were about a different branch: per STEP 1 it
    // nulls every fact and puts the mismatch in additionalNotes.
    mockMessagesCreate.mockResolvedValue(
      claudeText(
        JSON.stringify({
          venueVerified: false,
          parking: null,
          babyChanging: null,
          pramAccess: null,
          publicTransport: null,
          additionalNotes: 'Sources refer to the Rockwater branch in Shoreham, not the address provided.',
          sources: ['https://rockwater.example/shoreham'],
        })
      )
    );

    const res = await getEnrichment();

    expect(res.status).toBe(200);
    // Same degrade shape as the parse-fail / Anthropic-failure branches — the
    // mismatch note in additionalNotes never reaches the app.
    expect(res.body.enrichedData).toEqual({});
    expect(res.body.sources).toEqual([]);
    expect(res.body.confidence).toBe('web_enriched');
    // Nothing about the wrong venue is cached.
    expect(VenueEnrichment.findOneAndUpdate).not.toHaveBeenCalled();
  });
});
