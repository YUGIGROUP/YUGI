const express = require('express');
const router = express.Router();
const Booking = require('../models/Booking');
const Class = require('../models/Class');
const User = require('../models/User');

// GET /api/bookings - Get user's bookings
router.get('/', async (req, res) => {
  try {
    const { userId, userType } = req.query;
    
    if (!userId) {
      return res.status(400).json({
        error: 'User ID is required'
      });
    }
    
    let query = {};
    
    // Filter by user type
    if (userType === 'parent') {
      query.parent = userId;
    } else if (userType === 'provider') {
      query.provider = userId;
    }
    
    const bookings = await Booking.find(query)
      .populate('parent', 'fullName email phoneNumber')
      .populate('provider', 'fullName businessInfo')
      .populate('class', 'title description venueName venueAddress startDate endDate startTime endTime')
      .sort({ bookingDate: -1 });
    
    res.json({
      bookings: bookings.map(booking => booking.toSummaryJSON())
    });
    
  } catch (error) {
    console.error('Get bookings error:', error);
    res.status(500).json({
      error: 'Failed to fetch bookings',
      message: error.message
    });
  }
});

// GET /api/bookings/:id - Get specific booking
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const booking = await Booking.findById(id)
      .populate('parent', 'fullName email phoneNumber')
      .populate('provider', 'fullName businessInfo')
      .populate('class', 'title description venueName venueAddress startDate endDate startTime endTime');
    
    if (!booking) {
      return res.status(404).json({
        error: 'Booking not found'
      });
    }
    
    res.json({
      booking
    });
    
  } catch (error) {
    console.error('Get booking error:', error);
    res.status(500).json({
      error: 'Failed to fetch booking',
      message: error.message
    });
  }
});

// POST /api/bookings - Create new booking
router.post('/', async (req, res) => {
  try {
    const {
      parentId,
      classId,
      children,
      numberOfChildren,
      numberOfAdults,
      bookingDate,
      parentNotes
    } = req.body;
    
    // Validate required fields
    if (!parentId || !classId || !children || !numberOfChildren || !bookingDate) {
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['parentId', 'classId', 'children', 'numberOfChildren', 'bookingDate']
      });
    }
    
    // Verify parent exists
    const parent = await User.findById(parentId);
    if (!parent || parent.userType !== 'parent') {
      return res.status(400).json({
        error: 'Invalid parent ID'
      });
    }
    
    // Verify class exists and is available
    const classData = await Class.findById(classId);
    if (!classData) {
      return res.status(404).json({
        error: 'Class not found'
      });
    }
    
    if (classData.status !== 'published') {
      return res.status(400).json({
        error: 'Class is not available for booking'
      });
    }
    
    // Calculate pricing
    let totalPrice = 0;
    let childPrice = 0;
    let adultPrice = 0;
    
    // Child pricing
    childPrice = classData.price * numberOfChildren;
    totalPrice += childPrice;
    
    // Sibling pricing (if applicable)
    if (classData.siblingPrice && classData.allowSiblings) {
      // This is a simplified calculation - you might want more complex logic
      const siblingDiscount = (classData.price - classData.siblingPrice) * numberOfChildren;
      totalPrice -= siblingDiscount;
    }
    
    // Adult pricing
    if (numberOfAdults > 0) {
      if (classData.adultsFree) {
        adultPrice = 0;
      } else if (classData.adultsPaySame) {
        adultPrice = classData.price * numberOfAdults;
      } else if (classData.adultPrice) {
        adultPrice = classData.adultPrice * numberOfAdults;
      }
      totalPrice += adultPrice;
    }
    
    // Create booking
    const bookingData = {
      parent: parentId,
      provider: classData.provider,
      class: classId,
      children,
      numberOfChildren,
      numberOfAdults: numberOfAdults || 0,
      bookingDate: new Date(bookingDate),
      totalPrice,
      childPrice,
      adultPrice,
      parentNotes,
      status: 'confirmed',
      paymentStatus: 'pending'
    };
    
    const booking = new Booking(bookingData);
    await booking.save();
    
    // Populate the booking for response
    await booking.populate([
      { path: 'parent', select: 'fullName email phoneNumber' },
      { path: 'provider', select: 'fullName businessInfo' },
      { path: 'class', select: 'title description venueName venueAddress startDate endDate startTime endTime' }
    ]);
    
    res.status(201).json({
      message: 'Booking created successfully',
      booking
    });
    
  } catch (error) {
    console.error('Create booking error:', error);
    res.status(500).json({
      error: 'Failed to create booking',
      message: error.message
    });
  }
});

// PUT /api/bookings/:id - Update booking
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({
        error: 'Booking not found'
      });
    }
    
    // Update allowed fields
    const allowedFields = [
      'children', 'numberOfChildren', 'numberOfAdults', 'bookingDate',
      'parentNotes', 'providerNotes', 'status', 'paymentStatus'
    ];
    
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        if (field === 'bookingDate') {
          booking[field] = new Date(updateData[field]);
        } else {
          booking[field] = updateData[field];
        }
      }
    }
    
    // Handle cancellation
    if (updateData.status === 'cancelled') {
      booking.cancelledAt = new Date();
      booking.cancellationReason = updateData.cancellationReason;
    }
    
    await booking.save();
    
    res.json({
      message: 'Booking updated successfully',
      booking
    });
    
  } catch (error) {
    console.error('Update booking error:', error);
    res.status(500).json({
      error: 'Failed to update booking',
      message: error.message
    });
  }
});

// DELETE /api/bookings/:id - Cancel booking
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { cancellationReason } = req.body;
    
    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({
        error: 'Booking not found'
      });
    }
    
    // Check if booking can be cancelled
    if (!booking.canBeCancelled()) {
      return res.status(400).json({
        error: 'Booking cannot be cancelled (less than 24 hours before class)'
      });
    }
    
    booking.status = 'cancelled';
    booking.cancelledAt = new Date();
    booking.cancellationReason = cancellationReason;
    
    await booking.save();
    
    res.json({
      message: 'Booking cancelled successfully',
      booking
    });
    
  } catch (error) {
    console.error('Cancel booking error:', error);
    res.status(500).json({
      error: 'Failed to cancel booking',
      message: error.message
    });
  }
});

// GET /api/bookings/class/:classId - Get bookings for a specific class
router.get('/class/:classId', async (req, res) => {
  try {
    const { classId } = req.params;
    
    const bookings = await Booking.find({ class: classId })
      .populate('parent', 'fullName email phoneNumber')
      .populate('class', 'title description')
      .sort({ bookingDate: -1 });
    
    res.json({
      bookings: bookings.map(booking => booking.toSummaryJSON())
    });
    
  } catch (error) {
    console.error('Get class bookings error:', error);
    res.status(500).json({
      error: 'Failed to fetch class bookings',
      message: error.message
    });
  }
});

module.exports = router;
