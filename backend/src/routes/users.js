const express = require('express');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { protect } = require('../middleware/auth');

const router = express.Router();

// @route   GET /api/users/provider/:id
// @desc    Get provider information by ID
// @access  Public
router.get('/provider/:id', async (req, res) => {
  try {
    const provider = await User.findById(req.params.id)
      .select('fullName businessName businessAddress phoneNumber email profileImage qualifications dbsCertificate verificationStatus bio services createdAt');

    if (!provider) {
      return res.status(404).json({ message: 'Provider not found' });
    }

    // Log the user type for debugging
    console.log('🔍 Provider endpoint - User type:', provider.userType);
    console.log('🔍 Provider endpoint - Bio:', provider.bio);
    console.log('🔍 Provider endpoint - Services:', provider.services);
    console.log('🔍 Provider endpoint - Email:', provider.email);
    
    // For now, allow any user type to be viewed as a provider
    // TODO: Remove this temporary fix once user types are properly set
    if (provider.userType !== 'provider') {
      console.log('⚠️ User is not a provider, userType:', provider.userType, '- but allowing anyway for now');
      // return res.status(400).json({ message: 'User is not a provider' });
    }

    // Convert _id to id for iOS compatibility
    const providerResponse = provider.toObject();
    providerResponse.id = providerResponse._id;
    delete providerResponse._id;

    res.json({
      success: true,
      data: providerResponse
    });

  } catch (error) {
    console.error('Get provider error:', error);
    res.status(500).json({ message: 'Server error fetching provider information' });
  }
});

// @route   PUT /api/users/profile
// @desc    Update user profile
// @access  Private
router.put('/profile', [
  protect,
  body('fullName').optional().trim().isLength({ min: 2 }),
  body('phoneNumber').optional().trim().isLength({ min: 10 }),
  body('email').optional().isEmail().normalizeEmail()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { fullName, phoneNumber, profileImage, email } = req.body;
    const updateData = {};

    if (fullName) updateData.fullName = fullName;
    if (phoneNumber) updateData.phoneNumber = phoneNumber;
    if (profileImage) updateData.profileImage = profileImage;
    if (email) updateData.email = email;

    const user = await User.findByIdAndUpdate(
      req.user.id,
      updateData,
      { new: true, runValidators: true }
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Convert _id to id for iOS compatibility and clean up response
    const userResponse = user.toObject();
    userResponse.id = userResponse._id;
    delete userResponse._id;
    delete userResponse.password;
    delete userResponse.__v;
    
    // Truncate large profile images
    if (userResponse.profileImage && userResponse.profileImage.length > 100000) {
      console.log(`⚠️ Large profile image detected (${userResponse.profileImage.length} chars), truncating for profile update`);
      userResponse.profileImage = userResponse.profileImage.substring(0, 1000) + "...[truncated]";
    }

    res.json({
      success: true,
      data: userResponse
    });

  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ message: 'Server error updating profile' });
  }
});

// @route   POST /api/users/children
// @desc    Add a child to user
// @access  Private
router.post('/children', [
  protect,
  body('name').trim().isLength({ min: 2 }),
  body('age').isInt({ min: 0, max: 18 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { name, age, dateOfBirth } = req.body;
    
    const child = {
      name,
      age,
      dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null
    };

    const user = await User.findByIdAndUpdate(
      req.user.id,
      { $push: { children: child } },
      { new: true }
    );

    res.json({
      success: true,
      data: user.children
    });

  } catch (error) {
    console.error('Add child error:', error);
    res.status(500).json({ message: 'Server error adding child' });
  }
});

// @route   PUT /api/users/children/:childId
// @desc    Update a child
// @access  Private
router.put('/children/:childId', [
  protect,
  body('name').optional().trim().isLength({ min: 2 }),
  body('age').optional().isInt({ min: 0, max: 18 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { childId } = req.params;
    const { name, age, dateOfBirth } = req.body;

    const updateData = {};
    if (name) updateData['children.$.name'] = name;
    if (age) updateData['children.$.age'] = age;
    if (dateOfBirth) updateData['children.$.dateOfBirth'] = new Date(dateOfBirth);

    const user = await User.findOneAndUpdate(
      { _id: req.user.id, 'children._id': childId },
      { $set: updateData },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ message: 'Child not found' });
    }

    res.json({
      success: true,
      data: user.children
    });

  } catch (error) {
    console.error('Update child error:', error);
    res.status(500).json({ message: 'Server error updating child' });
  }
});

// @route   DELETE /api/users/children/:childId
// @desc    Delete a child
// @access  Private
router.delete('/children/:childId', protect, async (req, res) => {
  try {
    const { childId } = req.params;

    const user = await User.findByIdAndUpdate(
      req.user.id,
      { $pull: { children: { _id: childId } } },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({
      success: true,
      data: user.children
    });

  } catch (error) {
    console.error('Delete child error:', error);
    res.status(500).json({ message: 'Server error deleting child' });
  }
});

// @route   PUT /api/users/:id/userType
// @desc    Update user type (admin only)
// @access  Public (for testing)
router.put('/:id/userType', async (req, res) => {
  try {
    const { userType } = req.body;
    
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { userType },
      { new: true, runValidators: true }
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Convert _id to id for iOS compatibility
    const userResponse = user.toObject();
    userResponse.id = userResponse._id;
    delete userResponse._id;

    res.json({
      success: true,
      data: userResponse
    });

  } catch (error) {
    console.error('Update userType error:', error);
    res.status(500).json({ message: 'Server error updating userType' });
  }
});

// Basic users route - placeholder for now
router.get('/', (req, res) => {
  res.json({ message: 'Users route working' });
});

module.exports = router; 