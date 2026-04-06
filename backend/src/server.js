const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const connectDB = require('../config/database');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const classRoutes = require('./routes/classes');
const bookingRoutes = require('./routes/bookings');
const paymentRoutes = require('./routes/payments');
const providerRoutes = require('./routes/providers');
const adminRoutes = require('./routes/admin');
const eventsRoutes = require('./routes/events');
const intakeRoutes = require('./routes/intake');
const venueRoutes = require('./routes/venues');

const feedbackRoutes = require('./routes/feedback');

const app = express();
const PORT = process.env.PORT || 3001;

// Connect to MongoDB
if (process.env.MONGODB_URI) {
  connectDB();
} else {
  console.log('🔧 Running in development mode without database - using in-memory storage');
}

// Security middleware
app.use(helmet());
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : ['http://localhost:3000', 'http://192.168.1.72:3000', 'http://127.0.0.1:3000'];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true); // mobile apps / server-to-server
    if (process.env.NODE_ENV !== 'production') return callback(null, true);
    if (ALLOWED_ORIGINS.includes(origin)) return callback(null, true);
    callback(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests — please try again later' },
});
app.use('/api/', limiter);

// Feedback submission: 20/hour per user
const feedbackLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 20,
  keyGenerator: req => (req.user ? `user:${req.user.id || req.user._id}` : req.ip),
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Feedback submission limit reached — please try again later' },
});

// Class generation: 10/hour per user
const classGenerationLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 10,
  keyGenerator: req => (req.user ? `user:${req.user.id || req.user._id}` : req.ip),
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Class generation limit reached — please try again later' },
});

// Body parsing middleware
// Skip JSON parsing for Stripe webhook (needs raw body for signature verification)
app.use((req, res, next) => {
  if (req.originalUrl === '/api/payments/webhook') {
    // Use raw body parser for webhook
    express.raw({ type: 'application/json' })(req, res, next);
  } else {
    // Use JSON parser for all other routes
    express.json({ limit: '10mb' })(req, res, next);
  }
});
app.use(express.urlencoded({ extended: true }));

// MongoDB injection sanitisation — strip $-prefixed keys from user input
function sanitiseObject(obj) {
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return obj;
  for (const key of Object.keys(obj)) {
    if (key.startsWith('$')) { delete obj[key]; } else { sanitiseObject(obj[key]); }
  }
  return obj;
}
app.use((req, _res, next) => {
  if (req.body   && typeof req.body   === 'object') sanitiseObject(req.body);
  if (req.query  && typeof req.query  === 'object') sanitiseObject(req.query);
  next();
});


// Static files for admin interface
app.use('/admin', express.static('public/admin'));

// Compression middleware (disabled in development to simplify client decoding)
if (process.env.NODE_ENV !== 'development') {
  app.use(compression());
}

// Logging middleware
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
}

// Root endpoint for Railway
app.get('/', (req, res) => {
  res.json({ 
    message: 'YUGI API Server',
    status: 'running'
  });
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'YUGI API is running',
    timestamp: new Date().toISOString()
  });
});

// Logging middleware for payment routes - runs BEFORE routes are mounted
app.use('/api/payments', (req, res, next) => {
  console.log('🔴🔴🔴 PAYMENT ROUTE HIT (SERVER LEVEL) 🔴🔴🔴');
  console.log('🔴 Method:', req.method);
  console.log('🔴 Path:', req.path);
  console.log('🔴 Original URL:', req.originalUrl);
  console.log('🔴 Timestamp:', new Date().toISOString());
  console.log('🔴 Headers present:', !!req.headers);
  console.log('🔴 Body present:', !!req.body);
  next();
});

// Log ALL requests to see what's happening
app.use((req, res, next) => {
  if (req.originalUrl && req.originalUrl.includes('payment')) {
    console.log('🟡🟡🟡 ANY MIDDLEWARE - PAYMENT REQUEST DETECTED 🟡🟡🟡');
    console.log('🟡 URL:', req.originalUrl);
    console.log('🟡 Method:', req.method);
  }
  next();
});

// Per-route rate limiters
app.use('/api/feedback', feedbackLimiter);
app.use('/api/classes/generate', classGenerationLimiter);

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/classes', classRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/providers', providerRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/events', eventsRoutes);
app.use('/api/intake', intakeRoutes);
app.use('/api/venues', venueRoutes);
app.use('/api/feedback', feedbackRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err.message);
  res.status(err.status || 500).json({
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong!',
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ message: 'Route not found' });
});



// ─── Post-visit feedback notification background job ─────────────────────────
// Runs every 5 minutes; sends APNs notifications for past-due ScheduledNotifications.
function startNotificationJob() {
  const INTERVAL_MS = 5 * 60 * 1000;

  async function processScheduledNotifications() {
    const ScheduledNotification = require('./models/ScheduledNotification');
    const User                  = require('./models/User');
    const Event                 = require('./models/Event');
    const { sendPostVisitFeedbackNotification } = require('./services/pushNotificationService');

    try {
      const pending = await ScheduledNotification.find({
        sendAt: { $lte: new Date() },
        status: 'pending',
      }).populate('userId', 'deviceToken devicePlatform');

      if (pending.length > 0) {
        console.log(`🔔 Notification job: ${pending.length} pending notification(s)`);
      }

      for (const notif of pending) {
        try {
          const user = notif.userId; // populated
          if (!user || !user.deviceToken || user.devicePlatform !== 'ios') {
            notif.status = 'failed';
            await notif.save();
            continue;
          }

          const result = await sendPostVisitFeedbackNotification({
            deviceToken: user.deviceToken,
            bookingId:   notif.bookingId.toString(),
            className:   notif.className,
          });

          notif.status = result.success ? 'sent' : 'failed';
          await notif.save();

          if (result.success) {
            await Event.create({
              userId:    user._id,
              eventType: 'feedback_notification_sent',
              classId:   notif.classId || null,
              metadata:  { bookingId: notif.bookingId.toString(), className: notif.className },
            }).catch(e => console.error('Event tracking error:', e.message));
            console.log(`✅ Notification sent for booking ${notif.bookingId}`);
          } else {
            console.error(`❌ Notification failed for booking ${notif.bookingId}:`, result.reason);
          }
        } catch (err) {
          console.error(`Error processing notification ${notif._id}:`, err.message);
          notif.status = 'failed';
          await notif.save();
        }
      }
    } catch (err) {
      console.error('Notification job error:', err.message);
    }
  }

  processScheduledNotifications();
  setInterval(processScheduledNotifications, INTERVAL_MS);
  console.log('🔔 Notification job started (every 5 minutes)');
}

if (process.env.MONGODB_URI) {
  // Start notification job only when DB is connected
  const mongoose = require('mongoose');
  mongoose.connection.once('open', startNotificationJob);
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 YUGI Server running on port ${PORT}`);
  console.log(`📱 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/api/health`);
  console.log(`📱 Network access: http://192.168.1.72:${PORT}/api/health`);
  console.log(`🔴🔴🔴 SERVER STARTED WITH PAYMENT LOGGING ENABLED - VERSION 2 🔴🔴🔴`);
  console.log(`🔴 Payment route logging middleware is ACTIVE`);
}); 