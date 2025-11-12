const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { inMemoryUsers, useInMemoryStorage } = require('../utils/inMemoryStorage');

// Protect routes - require authentication
const protect = async (req, res, next) => {
  // Log all payment-related requests
  const isPaymentRoute = (req.path && req.path.includes('payment')) || 
                         (req.path && req.path.includes('create-payment')) || 
                         (req.path && req.path.includes('confirm-payment')) ||
                         (req.originalUrl && req.originalUrl.includes('/api/payments'));
  
  if (isPaymentRoute) {
    console.log('🔐 PROTECT MIDDLEWARE: Payment route detected');
    console.log('🔐 Path:', req.path);
    console.log('🔐 Original URL:', req.originalUrl);
    console.log('🔐 Authorization header present:', !!req.headers.authorization);
    console.log('🔐 Authorization header:', req.headers.authorization ? req.headers.authorization.substring(0, 20) + '...' : 'NONE');
  }
  
  let token;

  // Check for token in headers
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      // Get token from header
      token = req.headers.authorization.split(' ')[1];

      // Verify token
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      if (isPaymentRoute) {
        console.log('🔐 Token verified, user ID:', decoded.id);
      }

      // Get user from token (use in-memory storage if MongoDB not available)
      if (useInMemoryStorage()) {
        // For in-memory storage, find user by ID
        console.log('🔍 Looking for user with ID:', decoded.id);
        console.log('🔍 Available users:', Array.from(inMemoryUsers.values()).map(u => ({ id: u._id, email: u.email })));
        req.user = Array.from(inMemoryUsers.values()).find(u => u._id === decoded.id);
        console.log('🔍 Found user:', req.user ? { id: req.user._id, email: req.user.email } : 'null');
      } else {
        req.user = await User.findById(decoded.id).select('-password');
      }
      
      if (!req.user) {
        if (isPaymentRoute) {
          console.error('❌ PROTECT MIDDLEWARE: User not found for ID:', decoded.id);
        }
        return res.status(401).json({ message: 'User not found' });
      }

      if (!req.user.isActive) {
        if (isPaymentRoute) {
          console.error('❌ PROTECT MIDDLEWARE: User account is deactivated');
        }
        return res.status(401).json({ message: 'Account is deactivated' });
      }

      if (isPaymentRoute) {
        console.log('✅ PROTECT MIDDLEWARE: User authenticated:', req.user.id, req.user.userType);
      }
      next();
    } catch (error) {
      if (isPaymentRoute) {
        console.error('❌ PROTECT MIDDLEWARE: Token verification error:', error.message);
      }
      console.error('Token verification error:', error);
      return res.status(401).json({ message: 'Not authorized, token failed' });
    }
  }

  if (!token) {
    if (isPaymentRoute) {
      console.error('❌ PROTECT MIDDLEWARE: No token provided');
    }
    return res.status(401).json({ message: 'Not authorized, no token' });
  }
};

// Optional auth - doesn't require authentication but adds user if available
const optionalAuth = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      token = req.headers.authorization.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = await User.findById(decoded.id).select('-password');
    } catch (error) {
      // Token is invalid, but we don't fail the request
      console.log('Optional auth token invalid:', error.message);
    }
  }

  next();
};

// Require specific user type
const requireUserType = (userTypes) => {
  return (req, res, next) => {
    const isPaymentRoute = (req.path && req.path.includes('payment')) || 
                           (req.path && req.path.includes('create-payment')) || 
                           (req.path && req.path.includes('confirm-payment')) ||
                           (req.originalUrl && req.originalUrl.includes('/api/payments'));
    
    if (isPaymentRoute) {
      console.log('🔐 REQUIRE USER TYPE MIDDLEWARE: Checking user type');
      console.log('🔐 Required types:', userTypes);
      console.log('🔐 User type:', req.user ? req.user.userType : 'NO USER');
    }
    
    if (!req.user) {
      if (isPaymentRoute) {
        console.error('❌ REQUIRE USER TYPE MIDDLEWARE: No user found');
      }
      return res.status(401).json({ message: 'Authentication required' });
    }

    if (!userTypes.includes(req.user.userType)) {
      if (isPaymentRoute) {
        console.error('❌ REQUIRE USER TYPE MIDDLEWARE: User type mismatch');
        console.error('❌ User type:', req.user.userType, 'Required:', userTypes);
      }
      return res.status(403).json({ 
        message: `Access denied. Required user types: ${userTypes.join(', ')}` 
      });
    }

    if (isPaymentRoute) {
      console.log('✅ REQUIRE USER TYPE MIDDLEWARE: User type authorized');
    }
    next();
  };
};

// Require provider verification
const requireProviderVerification = async (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({ message: 'Authentication required' });
  }

  if (req.user.userType !== 'provider') {
    return res.status(403).json({ message: 'Provider access required' });
  }

  if (req.user.verificationStatus !== 'approved') {
    return res.status(403).json({ 
      message: 'Provider verification required',
      verificationStatus: req.user.verificationStatus
    });
  }

  next();
};

module.exports = {
  protect,
  optionalAuth,
  requireUserType,
  requireProviderVerification
}; 