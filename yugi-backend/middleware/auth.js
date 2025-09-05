const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Protect routes - require authentication
const protect = async (req, res, next) => {
  let token;

  // Check for token in headers
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      // Get token from header
      token = req.headers.authorization.split(' ')[1];

      // For now, we'll use a simple token format since we're not using JWT yet
      // In production, you should use proper JWT verification
      if (token.startsWith('jwt_token_')) {
        const userId = token.split('_')[2]; // Extract user ID from token
        req.user = await User.findById(userId);

        if (!req.user) {
          return res.status(401).json({ message: 'User not found' });
        }

        next();
      } else {
        return res.status(401).json({ message: 'Invalid token format' });
      }
    } catch (error) {
      console.error('Token verification error:', error);
      return res.status(401).json({ message: 'Not authorized, token failed' });
    }
  }

  if (!token) {
    return res.status(401).json({ message: 'Not authorized, no token' });
  }
};

module.exports = {
  protect
};
