// Unit tests for requireAdmin middleware, exercised in isolation with mocked
// req/res/next. Pure in-memory: no Express app, no HTTP, no Mongo — importing
// the middleware must not open any connection.
//
// The route-level counterpart now exists: src/routes/__tests__/paymentsRefund.test.js
// drives POST /api/payments/refund through the exported Express app with
// supertest and asserts non-admins get 403 (defence against the requireAdmin
// middleware being removed/reordered on the route definition). These unit tests
// remain the fast, isolated check on requireAdmin's own logic.

const { requireAdmin } = require('../auth');

// Minimal Express-style res double: status() is chainable and records the code,
// json() records the payload.
function mockRes() {
  const res = {
    statusCode: undefined,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
  return res;
}

describe('requireAdmin', () => {
  test('no req.user -> 401, next not called', () => {
    const req = {};
    const res = mockRes();
    const next = jest.fn();

    requireAdmin(req, res, next);

    expect(res.statusCode).toBe(401);
    expect(next).not.toHaveBeenCalled();
  });

  test('req.user with isAdmin false -> 403, next not called', () => {
    const req = { user: { isAdmin: false } };
    const res = mockRes();
    const next = jest.fn();

    requireAdmin(req, res, next);

    expect(res.statusCode).toBe(403);
    expect(next).not.toHaveBeenCalled();
  });

  test('req.user with isAdmin true -> next called, no status set', () => {
    const req = { user: { isAdmin: true } };
    const res = mockRes();
    const next = jest.fn();

    requireAdmin(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    expect(res.statusCode).toBeUndefined();
  });
});
