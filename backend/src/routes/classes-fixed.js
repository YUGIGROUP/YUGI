const express = require('express');
const { body, validationResult, query } = require('express-validator');
const Class = require('../models/Class');
const { protect, optionalAuth, requireProviderVerification } = require('../middleware/auth');

const router = express.Router();

// Middleware to normalize category in responses
const normalizeCategoryInResponse = (req, res, next) => {
  const originalJson = res.json;
  res.json = function(data) {
    if (data && data.data) {
      if (Array.isArray(data.data)) {
        // Handle array of classes
        data.data = data.data.map(classItem => {
          if (classItem.category) {
            classItem.category = classItem.category.charAt(0).toUpperCase() + classItem.category.slice(1).toLowerCase();
          }
          return classItem;
        });
      } else if (data.data.category) {
        // Handle single class
        data.data.category = data.data.category.charAt(0).toUpperCase() + data.data.category.slice(1).toLowerCase();
      }
    }
    return originalJson.call(this, data);
  };
  next();
};

// Helper function to transform class for iOS compatibility
const transformClassForIOS = (classItem) => {
  const classObj = classItem.toObject();
  classObj.id = classObj._id;
  delete classObj._id;

  // Ensure location object exists with all required fields
  const location = classObj.location || {};
  const address = location.address || {};
  const coordinates = location.coordinates || {};

  return {
    ...classObj,
    // Ensure location object matches iOS expectations
    location: {
      id: `location-${classObj.id}`,
      name: location.name || '',
      address: {
        street: address.street || '',
        city: address.city || '',
        state: address.state || '',
        postalCode: address.postalCode || '',
        country: address.country || 'United Kingdom'
      },
      coordinates: {
        latitude: coordinates.latitude || 0,
        longitude: coordinates.longitude || 0
      },
      accessibilityNotes: location.accessibilityNotes || null,
      parkingInfo: location.parkingInfo || null,
      babyChangingFacilities: location.babyChangingFacilities || null
    },
    // Create schedule object from recurringDays and timeSlots
    schedule: {
      startDate: new Date(),
      endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      recurringDays: classObj.recurringDays || ['monday'],
      timeSlots: (classObj.timeSlots || []).map(slot => ({
        startTime: new Date(`2000-01-01T${slot.startTime}:00Z`),
        duration: classObj.duration * 60
      })),
      totalSessions: 1
    },
    // Create pricing object
    pricing: {
      amount: classObj.price,
      currency: 'GBP',
      type: 'perSession',
      description: 'Per session'
    },
    // Map currentBookings to currentEnrollment
    currentEnrollment: classObj.currentBookings || 0,
    // Add isFavorite field
    isFavorite: false
  };
};

// @route   GET /api/classes
// @desc    Get all published classes with optional filtering
// @access  Public (with optional auth)
router.get('/', optionalAuth, normalizeCategoryInResponse, async (req, res) => {
  try {
    console.log('🔍 GET /api/classes - Fetching published classes');
    
    const {
      category,
      search,
      minPrice,
      maxPrice,
      ageRange,
      location,
      page = 1,
      limit = 20
    } = req.query;

    // Build filter object
    const filter = {
      isActive: true,
      isPublished: true
    };

    // Category filter
    if (category) {
      filter.category = category;
    }

    // Price range filter
    if (minPrice || maxPrice) {
      filter.price = {};
      if (minPrice) filter.price.$gte = parseFloat(minPrice);
      if (maxPrice) filter.price.$lte = parseFloat(maxPrice);
    }

    // Age range filter
    if (ageRange) {
      filter.ageRange = { $regex: ageRange, $options: 'i' };
    }

    // Location filter
    if (location) {
      filter['location.name'] = { $regex: location, $options: 'i' };
    }

    // Text search
    if (search) {
      filter.$text = { $search: search };
    }

    // Pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);

    console.log('🔍 Filter:', JSON.stringify(filter, null, 2));

    // Execute query
    const classes = await Class.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Get total count for pagination
    const total = await Class.countDocuments(filter);

    console.log(`✅ Found ${classes.length} published classes (total: ${total})`);

    // Transform classes to match iOS model expectations
    const transformedClasses = classes.map(transformClassForIOS);

    res.json({
      success: true,
      data: transformedClasses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('❌ Get classes error:', error);
    res.status(500).json({ message: 'Server error fetching classes' });
  }
});

// @route   GET /api/classes/:id
// @desc    Get a specific class by ID
// @access  Public
router.get('/:id', async (req, res) => {
  try {
    console.log(`🔍 GET /api/classes/${req.params.id} - Fetching class by ID`);
    
    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    if (!classItem.isActive || !classItem.isPublished) {
      return res.status(404).json({ message: 'Class not available' });
    }

    const transformedClass = transformClassForIOS(classItem);

    res.json({
      success: true,
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Get class by ID error:', error);
    res.status(500).json({ message: 'Server error fetching class' });
  }
});

// @route   POST /api/classes
// @desc    Create a new class (providers only)
// @access  Private
router.post('/', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse,
  body('name').trim().isLength({ min: 3, max: 100 }),
  body('description').optional().custom((value) => {
    if (value === undefined || value === null || value.trim() === '') {
      return true; // Allow empty/undefined values
    }
    return value.trim().length >= 3; // Validate non-empty values
  }),
  body('category').custom((value) => {
    const normalizedValue = value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
    return ['Baby', 'Toddler', 'Wellness'].includes(normalizedValue);
  }).withMessage('Category must be one of: baby, toddler, wellness (case insensitive)'),
  body('individualChildSpots').isInt({ min: 0, max: 15 }),
  body('siblingPairs').isInt({ min: 0, max: 15 }),
  body('siblingPrice').isFloat({ min: 0 }),
  body('price').isFloat({ min: 0 }),
  body('adultsPaySame').isBoolean(),
  body('adultPrice').isFloat({ min: 0 }),
  body('adultsFree').isBoolean(),
  body('maxCapacity').isInt({ min: 1 }),
  body('duration').isInt({ min: 15 }),
  body('ageRange').optional().custom((value) => {
    if (value === undefined || value === null || value.trim() === '') {
      return true; // Allow empty/undefined values
    }
    return value.trim().length >= 1; // Validate non-empty values
  }),
  body('recurringDays').optional().isArray(),
  body('timeSlots').isArray({ min: 1 })
], async (req, res) => {
  try {
    console.log('🔍 POST /api/classes - Creating new class');
    console.log('🔍 Request body:', JSON.stringify(req.body, null, 2));
    console.log('🔍 User ID:', req.user.id);

    // Check if user is a provider
    if (req.user.userType !== 'provider') {
      return res.status(403).json({ message: 'Only providers can create classes' });
    }

    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed', 
        errors: errors.array() 
      });
    }

    // Create class data
    const classData = {
      ...req.body,
      provider: req.user.id
    };

    console.log('🔍 Class data to save:', JSON.stringify(classData, null, 2));

    // Create the class
    const newClass = new Class(classData);
    const savedClass = await newClass.save();

    console.log('✅ Class created successfully:', savedClass.name);

    // Transform the response for iOS compatibility
    const transformedClass = transformClassForIOS(savedClass);

    res.status(201).json({
      success: true,
      message: 'Class created successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Create class error:', error);
    res.status(500).json({ message: 'Server error creating class' });
  }
});

// @route   PUT /api/classes/:id
// @desc    Update a class
// @access  Private
router.put('/:id', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 PUT /api/classes/${req.params.id} - Updating class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to update this class' });
    }

    // Update the class
    const updatedClass = await Class.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: new Date() },
      { new: true, runValidators: true }
    );

    console.log('✅ Class updated successfully:', updatedClass.name);

    // Transform the response for iOS compatibility
    const transformedClass = transformClassForIOS(updatedClass);

    res.json({
      success: true,
      message: 'Class updated successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Update class error:', error);
    res.status(500).json({ message: 'Server error updating class' });
  }
});

// @route   POST /api/classes/:id/publish
// @desc    Publish a class
// @access  Private
router.post('/:id/publish', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 POST /api/classes/${req.params.id}/publish - Publishing class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to publish this class' });
    }

    // Update the class to published
    const updatedClass = await Class.findByIdAndUpdate(
      req.params.id,
      { isPublished: true, updatedAt: new Date() },
      { new: true }
    );

    console.log('✅ Class published successfully:', updatedClass.name);

    // Transform the response for iOS compatibility
    const transformedClass = transformClassForIOS(updatedClass);

    res.json({
      success: true,
      message: 'Class published successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Publish class error:', error);
    res.status(500).json({ message: 'Server error publishing class' });
  }
});

// @route   POST /api/classes/:id/unpublish
// @desc    Unpublish a class
// @access  Private
router.post('/:id/unpublish', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 POST /api/classes/${req.params.id}/unpublish - Unpublishing class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to unpublish this class' });
    }

    // Update the class to unpublished
    const updatedClass = await Class.findByIdAndUpdate(
      req.params.id,
      { isPublished: false, updatedAt: new Date() },
      { new: true }
    );

    console.log('✅ Class unpublished successfully:', updatedClass.name);

    // Transform the response for iOS compatibility
    const transformedClass = transformClassForIOS(updatedClass);

    res.json({
      success: true,
      message: 'Class unpublished successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Unpublish class error:', error);
    res.status(500).json({ message: 'Server error unpublishing class' });
  }
});

// @route   DELETE /api/classes/:id
// @desc    Delete a class
// @access  Private
router.delete('/:id', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 DELETE /api/classes/${req.params.id} - Deleting class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to delete this class' });
    }

    // Delete the class
    await Class.findByIdAndDelete(req.params.id);

    console.log('✅ Class deleted successfully:', classItem.name);

    res.json({
      success: true,
      message: 'Class deleted successfully'
    });

  } catch (error) {
    console.error('❌ Delete class error:', error);
    res.status(500).json({ message: 'Server error deleting class' });
  }
});

// @route   GET /api/classes/provider/my-classes
// @desc    Get all classes for the authenticated provider
// @access  Private
router.get('/provider/my-classes', protect, /* requireProviderVerification, */ normalizeCategoryInResponse, async (req, res) => {
  try {
    console.log('🔍 GET /api/classes/provider/my-classes - Fetching provider classes');
    console.log('🔍 Provider ID:', req.user.id);

    const { status, page = 1, limit = 20 } = req.query;

    const filter = {
      provider: req.user.id
    };

    // Filter by status
    if (status === 'published') {
      filter.isPublished = true;
    } else if (status === 'draft') {
      filter.isPublished = false;
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const classes = await Class.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Class.countDocuments(filter);

    console.log(`✅ Found ${classes.length} classes for provider (total: ${total})`);

    // Transform classes to match iOS model expectations
    const transformedClasses = classes.map(transformClassForIOS);

    res.json({
      success: true,
      data: transformedClasses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('❌ Get provider classes error:', error);
    res.status(500).json({ message: 'Server error fetching provider classes' });
  }
});

module.exports = router;
