const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { protect } = require('../middleware/auth');

// POST /api/auth/signup - User registration
router.post('/signup', async (req, res) => {
  console.log('🔐 Backend: Signup request received:', { email: req.body.email, userType: req.body.userType, firebaseUid: req.body.firebaseUid });
  try {
    const { email, fullName, phoneNumber, userType, password, businessInfo, children } = req.body;

    // Validate required fields (password is optional with Firebase Auth)
    if (!email || !fullName || !userType) {
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['email', 'fullName', 'userType']
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      // If user exists, return success with existing user data
      return res.status(200).json({
        token: `jwt_token_${existingUser._id}_${Date.now()}`,
        user: existingUser.toProfileJSON()
      });
    }

    // Create new user
    const userData = {
      email: email.toLowerCase(),
      fullName,
      phoneNumber: phoneNumber || 'Not provided',
      userType,
      firebaseUid: req.body.firebaseUid || `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    };

    // Add provider-specific data
    if (userType === 'provider' && businessInfo) {
      userData.businessInfo = businessInfo;
    }

    // Add parent-specific data
    if (userType === 'parent' && children) {
      userData.children = children;
    }

    const user = new User(userData);
    await user.save();

    // Return user data with token (without sensitive info)
    res.status(201).json({
      token: `jwt_token_${user._id}_${Date.now()}`,
      user: user.toProfileJSON()
    });
  } catch (error) {
    console.error('Signup error:', error);
    
    // Handle duplicate Firebase UID error
    if (error.code === 11000 && error.keyPattern && error.keyPattern.firebaseUid) {
      // Find existing user with this Firebase UID
      const existingUser = await User.findOne({ firebaseUid: req.body.firebaseUid });
      if (existingUser) {
        return res.status(200).json({
          token: `jwt_token_${existingUser._id}_${Date.now()}`,
          user: existingUser.toProfileJSON()
        });
      }
    }
    
    res.status(500).json({
      error: 'Failed to create user',
      message: error.message
    });
  }
});

// POST /api/auth/login - User login
router.post('/login', async (req, res) => {
  console.log('🔐 Backend: Login request received:', { email: req.body.email, firebaseUid: req.body.firebaseUid });
  try {
    const { email, firebaseUid } = req.body;

    // Validate required fields
    if (!email) {
      return res.status(400).json({
        error: 'Email is required'
      });
    }

    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    // Update Firebase UID if provided
    if (firebaseUid && !user.firebaseUid) {
      user.firebaseUid = firebaseUid;
      await user.save();
    }

    // Return user data with token
    res.json({
      token: `jwt_token_${user._id}_${Date.now()}`,
      user: user.toProfileJSON()
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      error: 'Failed to login',
      message: error.message
    });
  }
});

// GET /api/auth/me - Get current user (requires authentication)
router.get('/me', protect, async (req, res) => {
  try {
    res.json({
      success: true,
      data: req.user.toProfileJSON()
    });
  } catch (error) {
    console.error('Get current user error:', error);
    res.status(500).json({
      error: 'Failed to get current user',
      message: error.message
    });
  }
});

// GET /api/auth/profile - Get current user profile
router.get('/profile', async (req, res) => {
  try {
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({
        error: 'User ID is required'
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    res.json({
      user: user.toProfileJSON()
    });

  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      error: 'Failed to get profile',
      message: error.message
    });
  }
});

// PUT /api/auth/profile - Update user profile
router.put('/profile', async (req, res) => {
  try {
    const { userId } = req.query;
    const updateData = req.body;

    if (!userId) {
      return res.status(400).json({
        error: 'User ID is required'
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    // Update allowed fields
    const allowedFields = ['fullName', 'phoneNumber', 'profileImage', 'businessInfo', 'children'];
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        user[field] = updateData[field];
      }
    }

    await user.save();

    res.json({
      message: 'Profile updated successfully',
      user: user.toProfileJSON()
    });

  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      error: 'Failed to update profile',
      message: error.message
    });
  }
});

module.exports = router;
