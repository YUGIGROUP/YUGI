// Route-level tests for venue-fact feedback submission —
// POST /api/venues/:placeId/feedback (routes/venues.js) — driven through the
// exported Express app with supertest. This is the route that writes to the
// VenueFactFeedback append-only event log and (for source=save_prompt) updates
// the denormalised SavedVenue.feedbackSubmitted marker.
//
// Same DB-less pattern as the other route tests: the User model (for protect),
// the VenueFactFeedback event log, and the SavedVenue summary marker are mocked
// so nothing touches a real database. See src/test/setupEnv.js for the dummy env
// keys that let the app import.

const jwt = require('jsonwebtoken');

// protect() does `User.findById(id).select('-password')`.
jest.mock('../../models/User', () => ({
  findById: jest.fn(),
}));

// Append-only event log. insertMany echoes the events back so the handler's
// `created.length` reflects what it actually tried to write.
jest.mock('../../models/VenueFactFeedback', () => ({
  insertMany: jest.fn((events) => Promise.resolve(events)),
}));

// Denormalised summary marker, only written for source=save_prompt.
jest.mock('../../models/SavedVenue', () => ({
  findOneAndUpdate: jest.fn().mockResolvedValue({}),
}));

const request = require('supertest');
const User = require('../../models/User');
const VenueFactFeedback = require('../../models/VenueFactFeedback');
const SavedVenue = require('../../models/SavedVenue');
const app = require('../../server');

const PLACE_ID = 'place-123';

function loginAs(overrides = {}) {
  const doc = {
    id: 'user-1',
    _id: 'user-1',
    isActive: true,
    isAdmin: false,
    userType: 'parent',
    ...overrides,
  };
  doc.select = jest.fn().mockReturnValue(doc);
  User.findById.mockReturnValue(doc);
  return doc;
}

function tokenFor(id) {
  return jwt.sign({ id }, process.env.JWT_SECRET);
}

function post(body, { auth = true } = {}) {
  const req = request(app).post(`/api/venues/${PLACE_ID}/feedback`);
  if (auth) req.set('Authorization', `Bearer ${tokenFor('user-1')}`);
  return req.send(body);
}

// A minimal valid single-fact body; `source` is filled in per-test.
function validBody(source, extra = {}) {
  return {
    venueName: 'Test Venue',
    source,
    facts: [{ factPath: 'accessibility.babyChanging', agreed: true }],
    ...extra,
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  VenueFactFeedback.insertMany.mockImplementation((events) => Promise.resolve(events));
  SavedVenue.findOneAndUpdate.mockResolvedValue({});
});

describe('POST /api/venues/:placeId/feedback', () => {
  test('happy path (save_prompt) — writes event log AND updates SavedVenue summary marker', async () => {
    loginAs();

    const res = await post(validBody('save_prompt'));

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ success: true, eventsCreated: 1 });

    // Event log: one correctly-mapped event.
    expect(VenueFactFeedback.insertMany).toHaveBeenCalledTimes(1);
    const events = VenueFactFeedback.insertMany.mock.calls[0][0];
    expect(events).toEqual([
      expect.objectContaining({
        placeId: PLACE_ID,
        venueName: 'Test Venue',
        factPath: 'accessibility.babyChanging',
        parentId: 'user-1',
        agreed: true,
        source: 'save_prompt',
      }),
    ]);

    // Denormalised summary marker set for save_prompt.
    expect(SavedVenue.findOneAndUpdate).toHaveBeenCalledWith(
      { userId: 'user-1', placeId: PLACE_ID },
      { $set: { feedbackSubmitted: true, feedbackSubmittedAt: expect.any(Date) } }
    );
  });

  test('happy path (mark_visited) — writes event log but does NOT touch the summary marker', async () => {
    loginAs();

    const res = await post(validBody('mark_visited'));

    expect(res.status).toBe(201);
    expect(VenueFactFeedback.insertMany).toHaveBeenCalledTimes(1);
    // Summary write is gated on source=save_prompt.
    expect(SavedVenue.findOneAndUpdate).not.toHaveBeenCalled();
  });

  test('overallComment — appends an extra "overall" event', async () => {
    loginAs();

    const res = await post(validBody('mark_visited', { overallComment: 'Lovely spot' }));

    expect(res.status).toBe(201);
    expect(res.body.eventsCreated).toBe(2);
    const events = VenueFactFeedback.insertMany.mock.calls[0][0];
    expect(events).toHaveLength(2);
    expect(events[1]).toEqual(
      expect.objectContaining({
        placeId: PLACE_ID,
        factPath: 'overall',
        parentId: 'user-1',
        agreed: true,
        comment: 'Lovely spot',
        source: 'mark_visited',
      })
    );
  });

  test('validation — invalid source → 400, nothing written', async () => {
    loginAs();

    const res = await post(validBody('not_a_source'));

    expect(res.status).toBe(400);
    expect(VenueFactFeedback.insertMany).not.toHaveBeenCalled();
    expect(SavedVenue.findOneAndUpdate).not.toHaveBeenCalled();
  });

  test('validation — facts[0].agreed not a boolean → 400, nothing written', async () => {
    loginAs();

    const res = await post({
      venueName: 'Test Venue',
      source: 'mark_visited',
      facts: [{ factPath: 'accessibility.babyChanging', agreed: 'yes' }],
    });

    expect(res.status).toBe(400);
    expect(VenueFactFeedback.insertMany).not.toHaveBeenCalled();
  });

  test('unauthenticated — no token → 401, nothing written', async () => {
    loginAs();

    const res = await post(validBody('save_prompt'), { auth: false });

    expect(res.status).toBe(401);
    expect(VenueFactFeedback.insertMany).not.toHaveBeenCalled();
    expect(SavedVenue.findOneAndUpdate).not.toHaveBeenCalled();
  });

  test('event-log write failure — insertMany throws → 500', async () => {
    loginAs();
    VenueFactFeedback.insertMany.mockRejectedValue(new Error('db down'));

    const res = await post(validBody('mark_visited'));

    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
