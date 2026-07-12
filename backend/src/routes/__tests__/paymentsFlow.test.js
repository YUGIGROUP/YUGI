// Route-level tests for the payment flow — POST /api/payments/create-payment-intent
// and POST /api/payments/confirm-payment — driven through the exported Express
// app with supertest. Same DB-less pattern as paymentsRefund.test.js: the User
// and Booking models, the Stripe client, and the email service are all mocked so
// nothing touches a real database or network. See src/test/setupEnv.js for the
// dummy env keys that let the app import.

const jwt = require('jsonwebtoken');

// Stripe client mock. The payment routes do `require('stripe')(key)` at module
// load; the handlers call paymentIntents.create / paymentIntents.retrieve. We
// drive those per-test and assert create() is never reached when a request is
// rejected before charging.
const mockPICreate = jest.fn();
const mockPIRetrieve = jest.fn();
jest.mock('stripe', () =>
  jest.fn(() => ({
    paymentIntents: { create: mockPICreate, retrieve: mockPIRetrieve },
    refunds: { create: jest.fn() },
  }))
);

// User model mock. protect() does `User.findById(id).select('-password')`; the
// create-payment-intent handler also does `await User.findById(req.user.id)`
// directly (no .select). The doc below satisfies both: findById returns the doc,
// .select() returns the same doc, and awaiting a plain object yields the object.
jest.mock('../../models/User', () => ({
  findById: jest.fn(),
}));

// Booking model mock — handlers do Booking.findById(id).populate('class')[.populate('parent',…)].
jest.mock('../../models/Booking', () => ({
  findById: jest.fn(),
}));

// Email service mock — confirm-payment's success path sends a booking email
// (best-effort, already wrapped in try/catch). Mock it so the test stays
// hermetic and never reaches out to Resend/SES.
jest.mock('../../services/emailService', () => ({
  sendBookingConfirmationEmail: jest.fn().mockResolvedValue(true),
}));

const request = require('supertest');
const User = require('../../models/User');
const Booking = require('../../models/Booking');
const app = require('../../server');

const VALID_BOOKING_ID = '507f1f77bcf86cd799439011';
const VALID_PM = 'pm_card_visa';

// Sets User.findById to resolve to a doc usable by both protect() and the
// handler's direct await. Returns the doc for assertions.
function loginAs(overrides = {}) {
  const doc = {
    id: 'user-1',
    _id: 'user-1',
    isActive: true,
    isAdmin: false,
    userType: 'parent',
    stripeCustomerId: 'cus_123',
    ...overrides,
  };
  doc.select = jest.fn().mockReturnValue(doc); // .select('-password') -> doc
  User.findById.mockReturnValue(doc);
  return doc;
}

function tokenFor(id) {
  return jwt.sign({ id }, process.env.JWT_SECRET);
}

// A thenable, infinitely-chainable query stand-in: .populate() returns itself,
// awaiting it resolves to `resolved`. Covers both single .populate('class') and
// chained .populate('class').populate('parent', …).
function bookingQuery(resolved) {
  const q = {
    populate: jest.fn(() => q),
    then: (resolve, reject) => Promise.resolve(resolved).then(resolve, reject),
  };
  return q;
}

function makeBooking(overrides = {}) {
  return {
    _id: 'booking-1',
    bookingNumber: 'BK-1',
    totalAmount: 50,
    paymentStatus: 'pending',
    status: 'pending',
    fundsReleased: undefined,
    stripePaymentIntentId: undefined,
    stripeChargeId: undefined,
    parent: { _id: 'user-1', email: 'parent@test.com', fullName: 'Parent Test' },
    class: {
      _id: 'class-1',
      name: 'Art Class',
      location: 'London',
      provider: { businessName: 'Provider Ltd' },
    },
    save: jest.fn().mockResolvedValue(true),
    populate: jest.fn().mockResolvedValue(true),
    ...overrides,
  };
}

function whenBookingIs(booking) {
  Booking.findById.mockReturnValue(bookingQuery(booking));
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('POST /api/payments/create-payment-intent', () => {
  test('success — succeeded PI → 200 and booking captured (held/confirmed/fundsReleased false)', async () => {
    loginAs();
    const booking = makeBooking();
    whenBookingIs(booking);
    mockPICreate.mockResolvedValue({ id: 'pi_1', status: 'succeeded', latest_charge: 'ch_1' });

    const res = await request(app)
      .post('/api/payments/create-payment-intent')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentMethodId: VALID_PM });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, status: 'succeeded', paymentIntentId: 'pi_1' });
    // Booking updated as the handler intends.
    expect(booking.paymentStatus).toBe('held');
    expect(booking.fundsReleased).toBe(false);
    expect(booking.status).toBe('confirmed');
    expect(booking.stripePaymentIntentId).toBe('pi_1');
    expect(booking.stripeChargeId).toBe('ch_1');
    expect(booking.save).toHaveBeenCalled();
  });

  test('3DS — requires_action PI → passes clientSecret through, success false', async () => {
    loginAs();
    const booking = makeBooking();
    whenBookingIs(booking);
    mockPICreate.mockResolvedValue({
      id: 'pi_2',
      status: 'requires_action',
      client_secret: 'pi_2_secret_abc',
    });

    const res = await request(app)
      .post('/api/payments/create-payment-intent')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentMethodId: VALID_PM });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      success: false,
      status: 'requires_action',
      clientSecret: 'pi_2_secret_abc',
      paymentIntentId: 'pi_2',
    });
    // Not captured: no success state written.
    expect(booking.paymentStatus).not.toBe('held');
    expect(booking.status).not.toBe('confirmed');
  });

  test('declined — StripeCardError → 400 with decline info, no success state written', async () => {
    loginAs();
    const booking = makeBooking();
    whenBookingIs(booking);
    mockPICreate.mockRejectedValue({
      type: 'StripeCardError',
      code: 'card_declined',
      decline_code: 'generic_decline',
      message: 'Your card was declined.',
      payment_intent: { id: 'pi_3' },
    });

    const res = await request(app)
      .post('/api/payments/create-payment-intent')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentMethodId: VALID_PM });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe('card_declined');
    expect(res.body.decline_code).toBe('generic_decline');
    expect(res.body.type).toBe('StripeCardError');
    // Handler records a failed charge, never a captured one.
    expect(booking.paymentStatus).toBe('failed');
    expect(booking.status).not.toBe('confirmed');
    expect(booking.fundsReleased).not.toBe(true);
  });

  test('validation — paymentMethodId not matching /^pm_/ → 400, Stripe never called', async () => {
    loginAs();
    whenBookingIs(makeBooking());

    const res = await request(app)
      .post('/api/payments/create-payment-intent')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentMethodId: 'not-a-pm-id' });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('Validation failed');
    expect(mockPICreate).not.toHaveBeenCalled();
  });

  // Added (money-touching): double-charge guard.
  test('already paid — booking held/paid → 400, Stripe never called', async () => {
    loginAs();
    whenBookingIs(makeBooking({ paymentStatus: 'held' }));

    const res = await request(app)
      .post('/api/payments/create-payment-intent')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentMethodId: VALID_PM });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('Booking is already paid');
    expect(mockPICreate).not.toHaveBeenCalled();
  });

  // Added (money-touching): paying for someone else's booking.
  test('wrong owner — booking owned by another user → 403, Stripe never called', async () => {
    loginAs({ id: 'user-1', _id: 'user-1' });
    whenBookingIs(makeBooking({ parent: { _id: 'someone-else' } }));

    const res = await request(app)
      .post('/api/payments/create-payment-intent')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentMethodId: VALID_PM });

    expect(res.status).toBe(403);
    expect(mockPICreate).not.toHaveBeenCalled();
  });

  // Added (money-touching): any PI status other than succeeded/requires_action
  // writes a failed state to the booking.
  test('unexpected PI status — e.g. processing → 400 with status echoed, booking marked failed', async () => {
    loginAs();
    const booking = makeBooking();
    whenBookingIs(booking);
    mockPICreate.mockResolvedValue({ id: 'pi_4', status: 'processing' });

    const res = await request(app)
      .post('/api/payments/create-payment-intent')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentMethodId: VALID_PM });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('processing');
    expect(res.body.paymentIntentId).toBe('pi_4');
    expect(booking.paymentStatus).toBe('failed');
    expect(booking.status).not.toBe('confirmed');
    expect(booking.save).toHaveBeenCalled();
  });
});

describe('POST /api/payments/confirm-payment', () => {
  test('succeeded PI → 200 and booking confirmed (held/confirmed/fundsReleased false)', async () => {
    loginAs();
    const booking = makeBooking();
    whenBookingIs(booking);
    mockPIRetrieve.mockResolvedValue({ id: 'pi_1', status: 'succeeded', latest_charge: 'ch_1' });

    const res = await request(app)
      .post('/api/payments/confirm-payment')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentIntentId: 'pi_1' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(booking.paymentStatus).toBe('held');
    expect(booking.status).toBe('confirmed');
    expect(booking.fundsReleased).toBe(false);
    expect(booking.stripeChargeId).toBe('ch_1');
    expect(booking.save).toHaveBeenCalled();
  });

  test('PI not succeeded → 400 unexpected-status branch, no booking write', async () => {
    loginAs();
    const booking = makeBooking();
    whenBookingIs(booking);
    mockPIRetrieve.mockResolvedValue({ id: 'pi_x', status: 'requires_payment_method' });

    const res = await request(app)
      .post('/api/payments/confirm-payment')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentIntentId: 'pi_x' });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('requires_payment_method');
    expect(res.body.paymentIntentId).toBe('pi_x');
    // Handler returns before touching the booking.
    expect(booking.save).not.toHaveBeenCalled();
    expect(booking.paymentStatus).toBe('pending');
  });

  test('booking not found → 404, Stripe never retrieved', async () => {
    loginAs();
    whenBookingIs(null);

    const res = await request(app)
      .post('/api/payments/confirm-payment')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ bookingId: VALID_BOOKING_ID, paymentIntentId: 'pi_1' });

    expect(res.status).toBe(404);
    expect(mockPIRetrieve).not.toHaveBeenCalled();
  });
});
