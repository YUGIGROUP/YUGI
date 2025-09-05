const express = require('express');
const router = express.Router();
const Class = require('../models/Class');
const User = require('../models/User');

// GET /api/classes - Get all published classes
router.get('/', async (req, res) => {
  try {
    const { category, search, providerId } = req.query;
    
    let query = { status: 'published' };
    
    // Filter by category
    if (category) {
      query.category = category;
    }
    
    // Filter by provider
    if (providerId) {
      query.provider = providerId;
    }
    
    // Search functionality
    if (search) {
      query.$text = { $search: search };
    }
    
    const classes = await Class.find(query)
      .populate('provider', 'fullName businessInfo profileImage')
      .sort({ createdAt: -1 });
    
    res.json({
      classes: classes.map(cls => cls.toSummaryJSON())
    });
    
  } catch (error) {
    console.error('Get classes error:', error);
    res.status(500).json({
      error: 'Failed to fetch classes',
      message: error.message
    });
  }
});

// GET /api/classes/:id - Get specific class
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const classData = await Class.findById(id)
      .populate('provider', 'fullName businessInfo profileImage');
    
    if (!classData) {
      return res.status(404).json({
        error: 'Class not found'
      });
    }
    
    res.json({
      class: classData
    });
    
  } catch (error) {
    console.error('Get class error:', error);
    res.status(500).json({
      error: 'Failed to fetch class',
      message: error.message
    });
  }
});

// POST /api/classes - Create new class
router.post('/', async (req, res) => {
  try {
    const {
      title,
      description,
      category,
      price,
      siblingPrice,
      adultsPaySame,
      adultPrice,
      adultsFree,
      individualChildSpots,
      siblingPairs,
      allowSiblings,
      startDate,
      endDate,
      startTime,
      endTime,
      daysOfWeek,
      venueName,
      venueAddress,
      latitude,
      longitude,
      classImage,
      providerId
    } = req.body;
    
    // Validate required fields
    const requiredFields = [
      'title', 'description', 'category', 'price', 'individualChildSpots',
      'siblingPairs', 'startDate', 'endDate', 'startTime', 'endTime',
      'daysOfWeek', 'venueName', 'venueAddress', 'latitude', 'longitude', 'providerId'
    ];
    
    for (const field of requiredFields) {
      if (!req.body[field]) {
        return res.status(400).json({
          error: `Missing required field: ${field}`
        });
      }
    }
    
    // Verify provider exists
    const provider = await User.findById(providerId);
    if (!provider || provider.userType !== 'provider') {
      return res.status(400).json({
        error: 'Invalid provider ID'
      });
    }
    
    // Create new class
    const classData = {
      title,
      description,
      category,
      price,
      siblingPrice,
      adultsPaySame,
      adultPrice,
      adultsFree,
      individualChildSpots,
      siblingPairs,
      allowSiblings: siblingPairs !== '0',
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      startTime,
      endTime,
      daysOfWeek,
      venueName,
      venueAddress,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      classImage,
      provider: providerId,
      status: 'draft'
    };
    
    const newClass = new Class(classData);
    await newClass.save();
    
    res.status(201).json({
      message: 'Class created successfully',
      class: newClass
    });
    
  } catch (error) {
    console.error('Create class error:', error);
    res.status(500).json({
      error: 'Failed to create class',
      message: error.message
    });
  }
});

// PUT /api/classes/:id - Update class
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    const classData = await Class.findById(id);
    if (!classData) {
      return res.status(404).json({
        error: 'Class not found'
      });
    }
    
    // Update allowed fields
    const allowedFields = [
      'title', 'description', 'category', 'price', 'siblingPrice',
      'adultsPaySame', 'adultPrice', 'adultsFree', 'individualChildSpots',
      'siblingPairs', 'startDate', 'endDate', 'startTime', 'endTime',
      'daysOfWeek', 'venueName', 'venueAddress', 'latitude', 'longitude',
      'classImage', 'status'
    ];
    
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        if (field === 'startDate' || field === 'endDate') {
          classData[field] = new Date(updateData[field]);
        } else if (field === 'latitude' || field === 'longitude') {
          classData[field] = parseFloat(updateData[field]);
        } else {
          classData[field] = updateData[field];
        }
      }
    }
    
    // Update allowSiblings based on siblingPairs
    if (updateData.siblingPairs !== undefined) {
      classData.allowSiblings = updateData.siblingPairs !== '0';
    }
    
    await classData.save();
    
    res.json({
      message: 'Class updated successfully',
      class: classData
    });
    
  } catch (error) {
    console.error('Update class error:', error);
    res.status(500).json({
      error: 'Failed to update class',
      message: error.message
    });
  }
});

// DELETE /api/classes/:id - Delete class
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const classData = await Class.findById(id);
    if (!classData) {
      return res.status(404).json({
        error: 'Class not found'
      });
    }
    
    await Class.findByIdAndDelete(id);
    
    res.json({
      message: 'Class deleted successfully'
    });
    
  } catch (error) {
    console.error('Delete class error:', error);
    res.status(500).json({
      error: 'Failed to delete class',
      message: error.message
    });
  }
});

// GET /api/classes/provider/:providerId - Get classes by provider
router.get('/provider/:providerId', async (req, res) => {
  try {
    const { providerId } = req.params;
    
    const classes = await Class.find({ provider: providerId })
      .populate('provider', 'fullName businessInfo profileImage')
      .sort({ createdAt: -1 });
    
    res.json({
      classes: classes.map(cls => cls.toSummaryJSON())
    });
    
  } catch (error) {
    console.error('Get provider classes error:', error);
    res.status(500).json({
      error: 'Failed to fetch provider classes',
      message: error.message
    });
  }
});

module.exports = router;
