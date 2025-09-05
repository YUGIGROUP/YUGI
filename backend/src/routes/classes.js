const express = require('express');
const { body, validationResult, query } = require('express-validator');
const Class = require('../models/Class');
const { protect, optionalAuth, requireProviderVerification } = require('../middleware/auth');

const router = express.Router();

// @route   GET /api/classes
// @desc    Get all published classes with optional filtering
// @access  Public (with optional auth)
router.get('/', optionalAuth, async (req, res) => {
  try {
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
      filter['location.address.formatted'] = { $regex: location, $options: 'i' };
    }

    // Text search
    if (search) {
      filter.$text = { $search: search };
    }

    // Pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Execute query
    const classes = await Class.find(filter)
      .populate('provider', 'fullName businessName verificationStatus')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Get total count for pagination
    const total = await Class.countDocuments(filter);

    res.json({
      success: true,
      data: classes,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('Get classes error:', error);
    res.status(500).json({ message: 'Server error fetching classes' });
  }
});

// @route   GET /api/classes/:id
// @desc    Get a specific class by ID
// @access  Public
router.get('/:id', async (req, res) => {
  try {
    const classItem = await Class.findById(req.params.id)
      .populate('provider', 'fullName businessName verificationStatus phoneNumber');

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    if (!classItem.isActive || !classItem.isPublished) {
      return res.status(404).json({ message: 'Class not available' });
    }

    res.json({
      success: true,
      data: classItem
    });

  } catch (error) {
    console.error('Get class error:', error);
    res.status(500).json({ message: 'Server error fetching class' });
  }
});

// @route   POST /api/classes
// @desc    Create a new class (providers only)
// @access  Private
router.post('/', [
  protect,
  requireProviderVerification,
  body('name').trim().isLength({ min: 3, max: 100 }),
  body('description').trim().isLength({ min: 10 }),
  body('category').isIn(['baby', 'toddler', 'wellness']),
  body('individualChildSpots').isIn(['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15']),
  body('siblingPairs').isIn(['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15']),
  body('siblingPrice').isFloat({ min: 0 }),
  body('price').isFloat({ min: 0 }),
  body('adultsPaySame').isBoolean(),
  body('adultPrice').isFloat({ min: 0 }),
  body('adultsFree').isBoolean(),
  body('maxCapacity').isInt({ min: 1 }),
  body('duration').isInt({ min: 15 }),
  body('ageRange').trim().isLength({ min: 1 }),
  body('recurringDays').isArray(),
  body('timeSlots').isArray({ min: 1 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const classData = {
      ...req.body,
      provider: req.user.id,
      isPublished: false // Start as draft
    };

    const newClass = await Class.create(classData);

    res.status(201).json({
      success: true,
      message: 'Class created successfully',
      data: newClass
    });

  } catch (error) {
    console.error('Create class error:', error);
    res.status(500).json({ message: 'Server error creating class' });
  }
});

// @route   PUT /api/classes/:id
// @desc    Update a class (owner only)
// @access  Private
router.put('/:id', [
  protect,
  requireProviderVerification,
  body('name').optional().trim().isLength({ min: 3, max: 100 }),
  body('description').optional().trim().isLength({ min: 10 }),
  body('category').optional().isIn(['baby', 'toddler', 'preschool', 'music', 'art', 'sport', 'education', 'other']),
  body('price').optional().isFloat({ min: 0 }),
  body('maxCapacity').optional().isInt({ min: 1 }),
  body('duration').optional().isInt({ min: 15 }),
  body('totalSessions').optional().isInt({ min: 1 }),
  body('ageRange').optional().trim().isLength({ min: 1 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check ownership
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to update this class' });
    }

    const updatedClass = await Class.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    res.json({
      success: true,
      message: 'Class updated successfully',
      data: updatedClass
    });

  } catch (error) {
    console.error('Update class error:', error);
    res.status(500).json({ message: 'Server error updating class' });
  }
});

// @route   POST /api/classes/:id/publish
// @desc    Publish a class (make it visible to parents)
// @access  Private
router.post('/:id/publish', protect, requireProviderVerification, async (req, res) => {
  try {
    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check ownership
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to publish this class' });
    }

    // Validate required fields for publishing
    if (!classItem.name || !classItem.description || !classItem.price || 
        !classItem.maxCapacity || !classItem.duration || !classItem.ageRange ||
        classItem.recurringDays.length === 0 || classItem.timeSlots.length === 0) {
      return res.status(400).json({ 
        message: 'All required fields must be completed before publishing' 
      });
    }

    classItem.isPublished = true;
    await classItem.save();

    res.json({
      success: true,
      message: 'Class published successfully',
      data: classItem
    });

  } catch (error) {
    console.error('Publish class error:', error);
    res.status(500).json({ message: 'Server error publishing class' });
  }
});

// @route   POST /api/classes/:id/unpublish
// @desc    Unpublish a class (make it draft)
// @access  Private
router.post('/:id/unpublish', protect, requireProviderVerification, async (req, res) => {
  try {
    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check ownership
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to unpublish this class' });
    }

    classItem.isPublished = false;
    await classItem.save();

    res.json({
      success: true,
      message: 'Class unpublished successfully',
      data: classItem
    });

  } catch (error) {
    console.error('Unpublish class error:', error);
    res.status(500).json({ message: 'Server error unpublishing class' });
  }
});

// @route   DELETE /api/classes/:id
// @desc    Delete a class (owner only)
// @access  Private
router.delete('/:id', protect, requireProviderVerification, async (req, res) => {
  try {
    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check ownership
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to delete this class' });
    }

    // Check if class has bookings
    if (classItem.currentBookings > 0) {
      return res.status(400).json({ 
        message: 'Cannot delete class with existing bookings' 
      });
    }

    await Class.findByIdAndDelete(req.params.id);

    res.json({
      success: true,
      message: 'Class deleted successfully'
    });

  } catch (error) {
    console.error('Delete class error:', error);
    res.status(500).json({ message: 'Server error deleting class' });
  }
});

// @route   GET /api/classes/provider/my-classes
// @desc    Get all classes for the authenticated provider
// @access  Private
router.get('/provider/my-classes', protect, requireProviderVerification, async (req, res) => {
  try {
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

    res.json({
      success: true,
      data: classes,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('Get provider classes error:', error);
    res.status(500).json({ message: 'Server error fetching provider classes' });
  }
});

module.exports = router; 