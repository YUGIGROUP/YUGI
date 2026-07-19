// Route-level tests for the recommended-classes radius filter —
// GET /api/classes?recommend=true (routes/classes.js) — driven through the
// exported Express app with supertest.
//
// Same DB-less pattern as the other route tests: the User model (for optionalAuth),
// the Class model, and the external venueDataService are mocked so nothing touches
// a real database or network. See src/test/setupEnv.js for the dummy env keys that
// let the app import. The real doabilityService (pure haversine + scoring) runs
// unmocked — that's the code under test alongside the route.

const jwt = require('jsonwebtoken');

// optionalAuth() does `User.findById(id).select('-password')`.
jest.mock('../../models/User', () => ({
  findById: jest.fn(),
}));

// Class model — find() returns a chainable, thenable query stub. The stub honours
// the Mongo `category` filter (that's the filter the radius runs AFTER), so tests
// can verify category + radius compose.
jest.mock('../../models/Class', () => ({
  find: jest.fn(),
  countDocuments: jest.fn(),
}));

// transformClassForIOS calls into venueDataService; stub it so the transform never
// hits Google/Anthropic. Returning coordinates: null makes the transform fall back
// to each class's own coordinates.
jest.mock('../../services/venueDataService', () => ({
  getRealVenueData: jest.fn().mockResolvedValue({
    parkingInfo: 'Street parking available nearby',
    babyChangingFacilities: 'Baby changing available',
    accessibilityNotes: null,
    coordinates: null,
    source: 'fallback',
  }),
  getGooglePlacesData: jest.fn().mockResolvedValue(null),
  getCoordinatesForAddress: jest.fn().mockResolvedValue(null),
}));

const request = require('supertest');
const User = require('../../models/User');
const Class = require('../../models/Class');
const app = require('../../server');

// ---- Coordinates ----------------------------------------------------------
// Parent searches from Liverpool city centre.
const LIVERPOOL = { lat: 53.4084, lng: -2.9916 };
// London — ~280 km away, comfortably outside the default 25 km radius.
const LONDON = { lat: 51.5074, lng: -0.1278 };

// A chainable, awaitable query stub mirroring the Mongoose query surface the
// route uses (.populate().lean() on the recommend path).
function mockQuery(data) {
  const q = {};
  q.populate = jest.fn(() => q);
  q.lean = jest.fn(() => q);
  q.skip = jest.fn(() => q);
  q.limit = jest.fn(() => q);
  q.sort = jest.fn(() => q);
  q.then = (resolve, reject) => Promise.resolve(data).then(resolve, reject);
  return q;
}

// Build a minimal published class doc with real coordinates.
// recurringDays / classDates default to a plain recurring Monday class; day tests
// override them to model recurring vs one-off (classDates) scheduling.
function makeClass({
  id,
  name,
  lat,
  lng,
  category = 'yoga',
  hasCoords = true,
  recurringDays = ['monday'],
  classDates = [],
}) {
  return {
    _id: id,
    name,
    category,
    price: 10,
    ageRange: '0-12 months',
    currentBookings: 0,
    maxParticipants: 10,
    recurringDays,
    classDates,
    timeSlots: [{ startTime: '10:00' }],
    duration: 1,
    provider: { _id: 'prov-1', businessName: 'Test Provider' },
    location: {
      name: `${name} Venue`,
      address: { street: '1 Test St', city: 'Testville', postalCode: 'T1 1TT' },
      coordinates: hasCoords ? { latitude: lat, longitude: lng } : { latitude: 0, longitude: 0 },
    },
  };
}

// Point Class.find at a dataset, applying the Mongo-side category filter so the
// radius (which runs after) composes with it exactly as it does in production.
function seedClasses(dataset) {
  Class.find.mockImplementation((filter) => {
    let data = dataset;
    if (filter && filter.category) {
      data = data.filter((c) => c.category === filter.category);
    }
    return mockQuery(data);
  });
  Class.countDocuments.mockResolvedValue(dataset.length);
}

// Authenticate as a parent (optionalAuth path).
function loginAsParent(overrides = {}) {
  const doc = {
    id: 'user-1',
    _id: 'user-1',
    isActive: true,
    userType: 'parent',
    children: [],
    location: { lat: LIVERPOOL.lat, lng: LIVERPOOL.lng },
    ...overrides,
  };
  doc.select = jest.fn().mockReturnValue(doc);
  User.findById.mockReturnValue(doc);
  return doc;
}

function tokenFor(id) {
  return jwt.sign({ id }, process.env.JWT_SECRET);
}

// Fire a recommended search from Liverpool. Extra query params merged in.
function search(extra = {}) {
  const params = new URLSearchParams({
    recommend: 'true',
    latitude: String(LIVERPOOL.lat),
    longitude: String(LIVERPOOL.lng),
    ...extra,
  });
  return request(app)
    .get(`/api/classes?${params.toString()}`)
    .set('Authorization', `Bearer ${tokenFor('user-1')}`);
}

// Names present in the response data.
function namesOf(res) {
  return res.body.data.map((c) => c.name);
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('GET /api/classes?recommend=true — radius filter', () => {
  test('(a) class within the default radius is returned', async () => {
    loginAsParent();
    seedClasses([
      makeClass({ id: 'near-1', name: 'Liverpool Baby Yoga', lat: 53.41, lng: -2.98 }),
    ]);

    const res = await search();

    expect(res.status).toBe(200);
    expect(res.body.recommendationEnabled).toBe(true);
    expect(namesOf(res)).toEqual(['Liverpool Baby Yoga']);
    expect(res.body.pagination.total).toBe(1);
  });

  test('(b) class beyond the default radius is excluded', async () => {
    loginAsParent();
    seedClasses([
      makeClass({ id: 'near-1', name: 'Liverpool Baby Yoga', lat: 53.41, lng: -2.98 }),
      makeClass({ id: 'far-1', name: 'London Baby Yoga', lat: LONDON.lat, lng: LONDON.lng }),
    ]);

    const res = await search();

    expect(res.status).toBe(200);
    expect(namesOf(res)).toEqual(['Liverpool Baby Yoga']);
    expect(namesOf(res)).not.toContain('London Baby Yoga');
    // total reflects the radius-filtered set, not the raw match count.
    expect(res.body.pagination.total).toBe(1);
  });

  test('(c) radiusKm param overrides the default, widening the search', async () => {
    loginAsParent();
    seedClasses([
      makeClass({ id: 'near-1', name: 'Liverpool Baby Yoga', lat: 53.41, lng: -2.98 }),
      makeClass({ id: 'far-1', name: 'London Baby Yoga', lat: LONDON.lat, lng: LONDON.lng }),
    ]);

    // 500 km comfortably includes London (~280 km away), which the 25 km default excluded.
    const res = await search({ radiusKm: '500' });

    expect(res.status).toBe(200);
    expect(namesOf(res).sort()).toEqual(['Liverpool Baby Yoga', 'London Baby Yoga']);
    expect(res.body.pagination.total).toBe(2);
  });

  test('(d) radius + category stack: in-radius wrong-category excluded, in-radius right-category returned', async () => {
    loginAsParent();
    seedClasses([
      // In radius, right category → returned.
      makeClass({ id: 'yoga-near', name: 'Liverpool Baby Yoga', lat: 53.41, lng: -2.98, category: 'yoga' }),
      // In radius, WRONG category → excluded by the (Mongo) category filter.
      makeClass({ id: 'swim-near', name: 'Liverpool Baby Swim', lat: 53.41, lng: -2.98, category: 'swimming' }),
      // Right category but OUT of radius → excluded by the radius filter.
      makeClass({ id: 'yoga-far', name: 'London Baby Yoga', lat: LONDON.lat, lng: LONDON.lng, category: 'yoga' }),
    ]);

    const res = await search({ category: 'yoga' });

    expect(res.status).toBe(200);
    expect(namesOf(res)).toEqual(['Liverpool Baby Yoga']);
    expect(namesOf(res)).not.toContain('Liverpool Baby Swim'); // in radius, wrong category
    expect(namesOf(res)).not.toContain('London Baby Yoga');    // right category, out of radius
    expect(res.body.pagination.total).toBe(1);
  });

  test('classes without coordinates are excluded from radius-filtered results', async () => {
    loginAsParent();
    seedClasses([
      makeClass({ id: 'near-1', name: 'Liverpool Baby Yoga', lat: 53.41, lng: -2.98 }),
      makeClass({ id: 'no-coords', name: 'Mystery Location Class', lat: 0, lng: 0, hasCoords: false }),
    ]);

    const res = await search();

    expect(res.status).toBe(200);
    expect(namesOf(res)).toEqual(['Liverpool Baby Yoga']);
    expect(namesOf(res)).not.toContain('Mystery Location Class');
  });
});

// The next calendar date landing on the given weekday (0=Sun … 6=Sat), always in
// the future so it counts as an "upcoming" classDate.
function nextWeekday(targetDay) {
  const d = new Date();
  d.setHours(12, 0, 0, 0);
  do {
    d.setDate(d.getDate() + 1);
  } while (d.getDay() !== targetDay);
  return d;
}

describe('GET /api/classes?recommend=true — day-membership filter', () => {
  const WEDNESDAY = 3;

  test('(a) Wednesday selected → a Saturday-only class is excluded', async () => {
    loginAsParent();
    seedClasses([
      makeClass({ id: 'wed', name: 'Wednesday Yoga', lat: 53.41, lng: -2.98, recurringDays: ['wednesday'] }),
      makeClass({ id: 'sat', name: 'Saturday Yoga', lat: 53.41, lng: -2.98, recurringDays: ['saturday'] }),
    ]);

    const res = await search({ preferredDays: 'wednesday' });

    expect(res.status).toBe(200);
    expect(namesOf(res)).not.toContain('Saturday Yoga');
    expect(res.body.pagination.total).toBe(1);
  });

  test('(b) class recurring on Wednesday is returned', async () => {
    loginAsParent();
    seedClasses([
      makeClass({ id: 'wed', name: 'Wednesday Yoga', lat: 53.41, lng: -2.98, recurringDays: ['wednesday'] }),
    ]);

    const res = await search({ preferredDays: 'wednesday' });

    expect(res.status).toBe(200);
    expect(namesOf(res)).toEqual(['Wednesday Yoga']);
  });

  test('(c) one-off class whose classDate falls on a Wednesday is returned', async () => {
    loginAsParent();
    seedClasses([
      // One-off class: no recurring days, only a specific upcoming Wednesday date.
      makeClass({
        id: 'oneoff',
        name: 'One-off Wednesday Workshop',
        lat: 53.41,
        lng: -2.98,
        recurringDays: [],
        classDates: [nextWeekday(WEDNESDAY)],
      }),
    ]);

    const res = await search({ preferredDays: 'wednesday' });

    expect(res.status).toBe(200);
    expect(namesOf(res)).toEqual(['One-off Wednesday Workshop']);
  });

  test('(d) days + radius stack: a right-day class out of radius is excluded', async () => {
    loginAsParent();
    seedClasses([
      makeClass({ id: 'near-wed', name: 'Liverpool Wednesday Yoga', lat: 53.41, lng: -2.98, recurringDays: ['wednesday'] }),
      makeClass({ id: 'far-wed', name: 'London Wednesday Yoga', lat: LONDON.lat, lng: LONDON.lng, recurringDays: ['wednesday'] }),
    ]);

    const res = await search({ preferredDays: 'wednesday' });

    expect(res.status).toBe(200);
    expect(namesOf(res)).toEqual(['Liverpool Wednesday Yoga']);
    expect(namesOf(res)).not.toContain('London Wednesday Yoga'); // right day, out of radius
    expect(res.body.pagination.total).toBe(1);
  });
});
