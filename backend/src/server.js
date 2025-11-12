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
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? '*' 
    : [
        'http://localhost:3000',
        'http://192.168.1.72:3000',
        'http://127.0.0.1:3000'
      ],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

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

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/classes', classRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/providers', providerRoutes);
app.use('/api/admin', adminRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 YUGI Server running on port ${PORT}`);
  console.log(`📱 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/api/health`);
  console.log(`📱 Network access: http://192.168.1.72:${PORT}/api/health`);
  console.log(`🔴🔴🔴 SERVER STARTED WITH PAYMENT LOGGING ENABLED - VERSION 2 🔴🔴🔴`);
  console.log(`🔴 Payment route logging middleware is ACTIVE`);
}); 