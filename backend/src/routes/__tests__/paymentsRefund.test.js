// Route-level regression test for POST /api/payments/refund, driven through the
// exported Express app with supertest. This is the test the requireAdmin unit
// suite flagged as "STILL OWED": authorization for this route depends ENTIRELY
// on the `protect` + `requireAdmin` middleware in the route definition (there is
// no in-handler admin re-check), so we assert non-admins are rejected with 403
// before any Stripe call — defence against that middleware being removed or
// reordered.
//
// DB-less strategy: with NODE_ENV=test (see src/test/setupEnv.js) the auth
// middleware does NOT use the in-memory user path — that path only activates
// under NODE_ENV=development. It falls through to the real Mongoose
// User.findById, which, with no MONGODB_URI, would buffer and hang ~10s before
// failing. So we mock the User and Booking models (and the Stripe client) to
// resolve instantly and let us control who the token maps to. No real database
// or network is touched.

const jwt = require('jsonwebtoken');

// Stripe client mock — the route does `require('stripe')(key)` at module load
// and calls stripe.refunds.create(...) only inside the handler. We assert this
// is never reached for unauthorized requests.
const mockStripeRefundCreate = jest.fn();
jest.mock('stripe', () =>
  jest.fn(() => ({
    refunds: { create: mockStripeRefundCreate },
  }))
);

// User model mock — protect() does `await User.findById(id).select('-password')`.
jest.mock('../../models/User', () => ({
  findById: jest.fn(),
}));

// Booking model mock — the refund handler does
// `await Booking.findById(bookingId).populate('class')`.
jest.mock('../../models/Booking', () => ({
  findById: jest.fn(),
}));

const request = require('supertest');
const User = require('../../models/User');
const Booking = require('../../models/Booking');
const app = require('../../server');

// Make User.findById(...).select(...) resolve to the given user (or null).
function whenTokenResolvesTo(user) {
  User.findById.mockReturnValue({
    select: jest.fn().mockResolvedValue(user),
  });
}

function tokenFor(id) {
  return jwt.sign({ id }, process.env.JWT_SECRET);
}

// A syntactically valid Mongo ObjectId so express-validator's isMongoId() passes
// and control reaches the handler body in the admin case.
const VALID_BOOKING_ID = '507f1f77bcf86cd799439011';

beforeEach(() => {
  jest.clearAllMocks();
});

describe('POST /api/payments/refund authorization', () => {
  test('no Authorization header -> 401, no Stripe call', async () => {
    const res = await request(app)
      .post('/api/payments/refund')
      .send({ bookingId: VALID_BOOKING_ID });

    expect(res.status).toBe(401);
    expect(User.findById).not.toHaveBeenCalled();
    expect(mockStripeRefundCreate).not.toHaveBeenCalled();
  });

  test('valid JWT for non-admin user -> 403, handler never reached (no Stripe call)', async () => {
    whenTokenResolvesTo({
      _id: 'user-1',
      id: 'user-1',
      isActive: true,
      isAdmin: false,
      userType: 'parent',
    });

    const res = await request(app)
      .post('/api/payments/refund')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID });

    expect(res.status).toBe(403);
    // Proof the handler was never entered: Booking was never looked up and
    // Stripe was never asked to create a refund.
    expect(Booking.findById).not.toHaveBeenCalled();
    expect(mockStripeRefundCreate).not.toHaveBeenCalled();
  });

  test('valid JWT for admin user -> passes middleware into handler (404 from DB-less lookup)', async () => {
    whenTokenResolvesTo({
      _id: 'admin-1',
      id: 'admin-1',
      isActive: true,
      isAdmin: true,
      userType: 'admin',
    });

    // Handler does Booking.findById(id).populate('class'); with no booking it
    // returns 404 "Booking not found". We mock it to null to reproduce that
    // path without a database.
    Booking.findById.mockReturnValue({
      populate: jest.fn().mockResolvedValue(null),
    });

    const res = await request(app)
      .post('/api/payments/refund')
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
      .send({ bookingId: VALID_BOOKING_ID });

    // The point of this case is that the admin got PAST protect + requireAdmin.
    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
    // With a valid bookingId (validators pass) and no booking found, the handler
    // returns 404 — reached only because middleware let the admin through.
    expect(res.status).toBe(404);
    expect(Booking.findById).toHaveBeenCalledWith(VALID_BOOKING_ID);
    // No booking -> no refund attempted.
    expect(mockStripeRefundCreate).not.toHaveBeenCalled();
  });
});
