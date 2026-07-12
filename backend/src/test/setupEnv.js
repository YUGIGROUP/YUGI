// Test-environment bootstrap, loaded via jest.config.js `setupFiles` before any
// test module (and therefore before src/server.js) is required.
//
// - STRIPE_SECRET_KEY: the Stripe SDK throws synchronously at module load when
//   the key is falsy (`require('stripe')(undefined)`), so a dummy is required
//   just to import the payment routes / app.
// - RESEND_API_KEY: routes/waitlist.js constructs `new Resend(...)` at module
//   scope, which likewise throws on a missing key when the app is imported.
// - JWT_SECRET: the auth middleware verifies tokens with process.env.JWT_SECRET
//   at request time, so a dummy secret lets tests sign tokens the app accepts.
// - NODE_ENV=test: keeps the app out of production-only branches.
// - MONGODB_URI is deleted so no test can ever open a connection to a real
//   database; server.js only calls connectDB()/starts crons when it is set.
process.env.STRIPE_SECRET_KEY = 'sk_test_dummy';
process.env.RESEND_API_KEY = 're_test_dummy';
process.env.JWT_SECRET = 'test_jwt_secret';
process.env.NODE_ENV = 'test';
delete process.env.MONGODB_URI;
