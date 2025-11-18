const express = require('express');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const emailService = require('../services/emailService');
const { inMemoryUsers, useInMemoryStorage } = require('../utils/inMemoryStorage');

const router = express.Router();

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || '30d'
  });
};

// @route   POST /api/auth/signup
// @desc    Register a new user
// @access  Public
router.post('/signup', [
  body('email').isEmail().normalizeEmail(),
  body('fullName').trim().isLength({ min: 2 }),
  body('userType').isIn(['parent', 'provider', 'other'])
], async (req, res) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { email, password, firebaseUid, fullName, userType, phoneNumber, businessName, businessAddress, businessInfo, profileImage } = req.body;

    // Validate that either password or firebaseUid is provided
    if (!password && !firebaseUid) {
      return res.status(400).json({ 
        message: 'Either password or firebaseUid is required' 
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists with this email' });
    }

    // Create user object
    const userData = {
      email,
      fullName,
      userType,
      phoneNumber
    };
    
    // Add profile image if provided
    if (profileImage) {
      userData.profileImage = profileImage;
    }

    // Add password or firebaseUid
    if (firebaseUid) {
      // For Firebase authentication, we'll use the firebaseUid as the password
      // This is a temporary solution - in production you might want to store firebaseUid separately
      userData.password = firebaseUid;
      console.log(`Firebase signup for user: ${email} with UID: ${firebaseUid}`);
    } else {
      userData.password = password;
    }

    // Add provider-specific fields if user is a provider
    if (userType === 'provider') {
      // Handle both direct fields and nested businessInfo object
      let finalBusinessName = businessName;
      let finalBusinessAddress = businessAddress;
      
      if (businessInfo) {
        finalBusinessName = businessInfo.businessName || businessName;
        finalBusinessAddress = businessInfo.address || businessAddress;
      }
      
      if (!finalBusinessName || !finalBusinessAddress) {
        return res.status(400).json({ 
          message: 'Business name and address are required for providers' 
        });
      }
      userData.businessName = finalBusinessName;
      userData.businessAddress = finalBusinessAddress;
    }

    // Create user
    const user = await User.create(userData);

    // Generate token
    const token = generateToken(user._id);

    res.status(201).json({
      token,
      user: {
        id: user._id,
        email: user.email,
        fullName: user.fullName,
        userType: user.userType,
        profileImage: user.profileImage || null,
        phoneNumber: user.phoneNumber || null,
        businessName: user.businessName || null,
        businessAddress: user.businessAddress || null,
        qualifications: user.qualifications || null,
        dbsCertificate: user.dbsCertificate || null,
        verificationStatus: user.verificationStatus || 'pending',
        children: user.children || [],
        isActive: user.isActive !== undefined ? user.isActive : true,
        isEmailVerified: user.isEmailVerified !== undefined ? user.isEmailVerified : false,
        createdAt: user.createdAt || new Date().toISOString(),
        updatedAt: user.updatedAt || new Date().toISOString(),
        location: user.location || null
      }
    });

  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ message: 'Server error during signup' });
  }
});

// @route   POST /api/auth/login
// @desc    Authenticate user & get token (supports both password and Firebase UID)
// @access  Public
router.post('/login', [
  body('email').isEmail().normalizeEmail()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { email, password, firebaseUid } = req.body;

    // Check for user (use in-memory storage if MongoDB not available)
    let user;
    if (useInMemoryStorage()) {
      user = inMemoryUsers.get(email);
    } else {
      user = await User.findOne({ email });
    }
    
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // Check if user is active
    if (!user.isActive) {
      return res.status(401).json({ message: 'Account is deactivated' });
    }

    // Firebase authentication (preferred)
    if (firebaseUid) {
      // For Firebase auth, we trust the Firebase UID
      // In production, you should verify the Firebase token on the server
      console.log(`Firebase login for user: ${email} with UID: ${firebaseUid}`);
    } 
    // Traditional password authentication
    else if (password) {
      // For in-memory storage, we'll accept any password for development
      if (useInMemoryStorage()) {
        console.log(`In-memory login for user: ${email}`);
      } else {
        const isMatch = await user.comparePassword(password);
        if (!isMatch) {
          return res.status(401).json({ message: 'Invalid credentials' });
        }
      }
    } else {
      return res.status(400).json({ message: 'Either password or firebaseUid is required' });
    }

    // Generate token
    const token = generateToken(user._id);

    res.json({
      token,
      user: {
        id: user._id,
        email: user.email,
        fullName: user.fullName,
        userType: user.userType,
        profileImage: user.profileImage || null,
        phoneNumber: user.phoneNumber || null,
        businessName: user.businessName || null,
        businessAddress: user.businessAddress || null,
        qualifications: user.qualifications || null,
        dbsCertificate: user.dbsCertificate || null,
        verificationStatus: user.verificationStatus || 'pending',
        children: user.children || [],
        isActive: user.isActive !== undefined ? user.isActive : true,
        isEmailVerified: user.isEmailVerified !== undefined ? user.isEmailVerified : false,
        createdAt: user.createdAt || new Date().toISOString(),
        updatedAt: user.updatedAt || new Date().toISOString(),
        location: user.location || null
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error during login' });
  }
});

// @route   GET /api/auth/me
// @desc    Get current user
// @access  Private
router.get('/me', protect, async (req, res) => {
  try {
    let user;
    if (useInMemoryStorage()) {
      // For in-memory storage, req.user is already the full user object
      user = req.user;
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
    } else {
      user = await User.findById(req.user.id);
    }
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Convert _id to id for iOS compatibility and clean up response
    const userResponse = user.toObject ? user.toObject() : { ...user };
    userResponse.id = userResponse._id;
    delete userResponse._id;
    delete userResponse.password; // Ensure password is removed
    delete userResponse.__v; // Remove Mongoose version field
    
    // Handle large profile images - truncate if too large (over 100KB)
    if (userResponse.profileImage && userResponse.profileImage.length > 100000) {
      console.log(`⚠️ Large profile image detected (${userResponse.profileImage.length} chars), truncating for /api/auth/me`);
      userResponse.profileImage = userResponse.profileImage.substring(0, 1000) + "...[truncated]";
    }
    
    res.json({
      data: userResponse
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/upload-documents
// @desc    Upload provider documents (qualifications, DBS)
// @access  Private
router.post('/upload-documents', protect, async (req, res) => {
  try {
    const { qualifications, dbsCertificate } = req.body;

    // Check if user is a provider
    if (req.user.userType !== 'provider') {
      return res.status(403).json({ message: 'Only providers can upload documents' });
    }

    // Update user with document URLs
    const user = await User.findByIdAndUpdate(
      req.user.id,
      {
        qualifications,
        dbsCertificate,
        verificationStatus: 'underReview'
      },
      { new: true }
    );

    res.json({
      success: true,
      message: 'Documents uploaded successfully. Verification in progress.',
      user: {
        id: user._id,
        verificationStatus: user.verificationStatus
      }
    });

  } catch (error) {
    console.error('Upload documents error:', error);
    res.status(500).json({ message: 'Server error uploading documents' });
  }
});

// @route   POST /api/auth/change-password
// @desc    Change user password
// @access  Private
router.post('/change-password', [
  protect,
  body('currentPassword').exists(),
  body('newPassword').isLength({ min: 8 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { currentPassword, newPassword } = req.body;

    // Get user with password
    const user = await User.findById(req.user.id).select('+password');
    
    // Check current password
    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(400).json({ message: 'Current password is incorrect' });
    }

    // Update password
    user.password = newPassword;
    await user.save();

    res.json({
      success: true,
      message: 'Password changed successfully'
    });

  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ message: 'Server error changing password' });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    Send password reset email
// @access  Public
router.post('/forgot-password', [
  body('email').isEmail().normalizeEmail()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { email } = req.body;

    // Check if user exists
    const user = await User.findOne({ email });
    if (!user) {
      // Don't reveal if user exists or not for security
      return res.json({
        success: true,
        message: 'If an account with that email exists, a password reset link has been sent'
      });
    }

    // Generate reset token (simple implementation - in production, use crypto.randomBytes)
    const resetToken = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
    
    // Store reset token and expiry (1 hour from now)
    user.resetPasswordToken = resetToken;
    user.resetPasswordExpires = new Date(Date.now() + 3600000); // 1 hour
    await user.save();

    // Send password reset email
    try {
      await emailService.sendPasswordResetEmail(email, user.fullName, resetToken);
    } catch (emailError) {
      console.error('Email sending error:', emailError);
      // Don't fail the request if email fails, just log it
    }

    res.json({
      success: true,
      message: 'If an account with that email exists, a password reset link has been sent'
    });

  } catch (error) {
    console.error('Forgot password error:', error);
    res.status(500).json({ message: 'Server error processing request' });
  }
});

// @route   POST /api/auth/reset-password
// @desc    Reset password with token
// @access  Public
router.post('/reset-password', [
  body('token').exists(),
  body('newPassword').isLength({ min: 8 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { token, newPassword } = req.body;

    // Find user with valid reset token
    const user = await User.findOne({
      resetPasswordToken: token,
      resetPasswordExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({ message: 'Invalid or expired reset token' });
    }

    // Update password and clear reset token
    user.password = newPassword;
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;
    await user.save();

    res.json({
      success: true,
      message: 'Password reset successfully'
    });

  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({ message: 'Server error resetting password' });
  }
});

module.exports = router; 