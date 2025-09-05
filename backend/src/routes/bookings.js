const express = require('express');
const { body, validationResult } = require('express-validator');
const Booking = require('../models/Booking');
const Class = require('../models/Class');
const { protect, requireUserType } = require('../middleware/auth');

const router = express.Router();

// @route   POST /api/bookings
// @desc    Create a new booking
// @access  Private (parents only)
router.post('/', [
  protect,
  requireUserType(['parent']),
  body('classId').isMongoId(),
  body('children').isArray({ min: 1 }),
  body('children.*.name').trim().isLength({ min: 1 }),
  body('children.*.age').isInt({ min: 0, max: 18 }),
  body('sessionDate').isISO8601(),
  body('sessionTime').trim().isLength({ min: 1 }),
  body('specialRequests').optional().trim()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { classId, children, sessionDate, sessionTime, specialRequests } = req.body;

    // Check if class exists and is available
    const classItem = await Class.findById(classId);
    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    if (!classItem.isActive || !classItem.isPublished) {
      return res.status(400).json({ message: 'Class is not available for booking' });
    }

    // Check if class is full
    if (classItem.currentBookings >= classItem.maxCapacity) {
      return res.status(400).json({ message: 'Class is full' });
    }

    // Check if session date is valid
    const sessionDateTime = new Date(sessionDate);
    const now = new Date();
    if (sessionDateTime < now) {
      return res.status(400).json({ message: 'Cannot book for past dates' });
    }

    // Calculate pricing
    const basePrice = classItem.price;
    const serviceFee = 1.99;
    const totalAmount = basePrice + serviceFee;

    // Create booking
    const booking = await Booking.create({
      parent: req.user.id,
      class: classId,
      children,
      sessionDate: sessionDateTime,
      sessionTime,
      basePrice,
      serviceFee,
      totalAmount,
      specialRequests
    });

    // Update class booking count
    await Class.findByIdAndUpdate(classId, {
      $inc: { currentBookings: 1 }
    });

    // Populate class and provider info
    await booking.populate([
      { path: 'class', select: 'name description category price duration ageRange location provider' },
      { path: 'class.provider', select: 'fullName businessName phoneNumber' }
    ]);

    res.status(201).json({
      success: true,
      message: 'Booking created successfully',
      data: booking
    });

  } catch (error) {
    console.error('Create booking error:', error);
    res.status(500).json({ message: 'Server error creating booking' });
  }
});

// @route   GET /api/bookings
// @desc    Get user's bookings
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;

    const filter = {};

    // Filter by user type
    if (req.user.userType === 'parent') {
      filter.parent = req.user.id;
    } else if (req.user.userType === 'provider') {
      // For providers, get bookings for their classes
      const userClasses = await Class.find({ provider: req.user.id }).select('_id');
      filter.class = { $in: userClasses.map(c => c._id) };
    }

    // Filter by status
    if (status) {
      filter.status = status;
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const bookings = await Booking.find(filter)
      .populate([
        { path: 'class', select: 'name description category price duration ageRange location images' },
        { path: 'class.provider', select: 'fullName businessName phoneNumber' },
        { path: 'parent', select: 'fullName email phoneNumber' }
      ])
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Booking.countDocuments(filter);

    res.json({
      success: true,
      data: bookings,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('Get bookings error:', error);
    res.status(500).json({ message: 'Server error fetching bookings' });
  }
});

// @route   GET /api/bookings/:id
// @desc    Get a specific booking
// @access  Private
router.get('/:id', protect, async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id)
      .populate([
        { path: 'class', select: 'name description category price duration ageRange location images' },
        { path: 'class.provider', select: 'fullName businessName phoneNumber email' },
        { path: 'parent', select: 'fullName email phoneNumber' }
      ]);

    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check authorization
    const isOwner = booking.parent._id.toString() === req.user.id;
    const isProvider = req.user.userType === 'provider' && 
                      booking.class.provider._id.toString() === req.user.id;

    if (!isOwner && !isProvider) {
      return res.status(403).json({ message: 'Not authorized to view this booking' });
    }

    res.json({
      success: true,
      data: booking
    });

  } catch (error) {
    console.error('Get booking error:', error);
    res.status(500).json({ message: 'Server error fetching booking' });
  }
});

// @route   PUT /api/bookings/:id/cancel
// @desc    Cancel a booking
// @access  Private
router.put('/:id/cancel', [
  protect,
  body('reason').optional().trim()
], async (req, res) => {
  try {
    const { reason } = req.body;

    const booking = await Booking.findById(req.params.id)
      .populate('class');

    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check authorization
    const isOwner = booking.parent.toString() === req.user.id;
    const isProvider = req.user.userType === 'provider' && 
                      booking.class.provider.toString() === req.user.id;

    if (!isOwner && !isProvider) {
      return res.status(403).json({ message: 'Not authorized to cancel this booking' });
    }

    // Check if booking can be cancelled
    if (booking.status === 'cancelled') {
      return res.status(400).json({ message: 'Booking is already cancelled' });
    }

    if (booking.status === 'completed') {
      return res.status(400).json({ message: 'Cannot cancel completed booking' });
    }

    // Calculate refund (if applicable)
    const sessionDate = new Date(booking.sessionDate);
    const now = new Date();
    const hoursUntilSession = (sessionDate - now) / (1000 * 60 * 60);

    let refundAmount = 0;
    if (hoursUntilSession > 24) {
      // Full refund if cancelled more than 24 hours before
      refundAmount = booking.totalAmount;
    } else if (hoursUntilSession > 2) {
      // 50% refund if cancelled more than 2 hours before
      refundAmount = booking.totalAmount * 0.5;
    }

    // Update booking
    booking.status = 'cancelled';
    booking.cancelledAt = new Date();
    booking.cancellationReason = reason;
    booking.refundAmount = refundAmount;

    if (booking.paymentStatus === 'paid' && refundAmount > 0) {
      booking.paymentStatus = 'refunded';
    }

    await booking.save();

    // Update class booking count
    await Class.findByIdAndUpdate(booking.class._id, {
      $inc: { currentBookings: -1 }
    });

    res.json({
      success: true,
      message: 'Booking cancelled successfully',
      data: {
        ...booking.toObject(),
        refundAmount
      }
    });

  } catch (error) {
    console.error('Cancel booking error:', error);
    res.status(500).json({ message: 'Server error cancelling booking' });
  }
});

// @route   PUT /api/bookings/:id/confirm
// @desc    Confirm a booking (providers only)
// @access  Private
router.put('/:id/confirm', protect, requireUserType(['provider']), async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id)
      .populate('class');

    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check if provider owns the class
    if (booking.class.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to confirm this booking' });
    }

    if (booking.status !== 'pending') {
      return res.status(400).json({ message: 'Booking is not in pending status' });
    }

    booking.status = 'confirmed';
    await booking.save();

    res.json({
      success: true,
      message: 'Booking confirmed successfully',
      data: booking
    });

  } catch (error) {
    console.error('Confirm booking error:', error);
    res.status(500).json({ message: 'Server error confirming booking' });
  }
});

// @route   PUT /api/bookings/:id/complete
// @desc    Mark booking as completed (providers only)
// @access  Private
router.put('/:id/complete', protect, requireUserType(['provider']), async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id)
      .populate('class');

    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check if provider owns the class
    if (booking.class.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to complete this booking' });
    }

    if (booking.status !== 'confirmed') {
      return res.status(400).json({ message: 'Booking must be confirmed before completing' });
    }

    booking.status = 'completed';
    await booking.save();

    res.json({
      success: true,
      message: 'Booking marked as completed',
      data: booking
    });

  } catch (error) {
    console.error('Complete booking error:', error);
    res.status(500).json({ message: 'Server error completing booking' });
  }
});

module.exports = router; 