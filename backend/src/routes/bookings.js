const express = require('express');
const { body, validationResult } = require('express-validator');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const Booking = require('../models/Booking');
const Class = require('../models/Class');
const { protect, requireUserType } = require('../middleware/auth');
const emailService = require('../services/emailService');

const ScheduledNotification = require('../models/ScheduledNotification');

const router = express.Router();

// @route   POST /api/bookings
// @desc    Create a new booking
// @access  Private (parents and providers - providers can book for their own children)
router.post('/', [
  protect,
  requireUserType(['parent', 'provider']),
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

    // Apply sessionTime ("HH:MM" in UTC) to sessionDateTime so the stored
    // datetime carries the real hour/minute, not just midnight UTC. iOS only
    // reads sessionDate back, so without this combination, parents would see
    // every booking displayed as midnight UTC (= 1:00 am BST). Matches the
    // existing combination pattern in this file's calendar route (~line 454).
    if (sessionTime && /^\d{2}:\d{2}$/.test(sessionTime)) {
      const [hours, minutes] = sessionTime.split(':').map(n => parseInt(n, 10));
      sessionDateTime.setUTCHours(hours, minutes, 0, 0);
    }

    const now = new Date();
    if (sessionDateTime < now) {
      return res.status(400).json({ message: 'Cannot book for past dates' });
    }

    // Calculate pricing
    const basePrice = classItem.price;
    const serviceFee = 1.99;
    const totalAmount = basePrice + serviceFee;

    // Generate booking number before creating
    const date = new Date();
    const year = date.getFullYear().toString().slice(-2);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    
    let bookingNumber;
    try {
      // Count existing bookings with today's prefix
      const todayPrefix = `YUGI${year}${month}${day}`;
      const count = await Booking.countDocuments({
        bookingNumber: { $regex: `^${todayPrefix}` }
      });
      const sequence = (count + 1).toString().padStart(3, '0');
      bookingNumber = `${todayPrefix}${sequence}`;
      console.log(`✅ Generated booking number: ${bookingNumber}`);
    } catch (countError) {
      console.error('Error counting bookings, using timestamp fallback:', countError);
      // Fallback: use timestamp
      const timestamp = Date.now().toString().slice(-6);
      bookingNumber = `YUGI${timestamp}`;
      console.log(`⚠️ Using fallback booking number: ${bookingNumber}`);
    }

    // Create booking with bookingNumber
    const booking = await Booking.create({
      bookingNumber,
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

    // Populate class and provider info (with error handling)
    try {
      await booking.populate([
        { path: 'class', select: 'name description category price duration ageRange location provider' },
        { path: 'class.provider', select: 'fullName businessName phoneNumber' }
      ]);
    } catch (populateError) {
      console.error('Populate error (non-fatal):', populateError);
      // Continue even if populate fails - booking is still created
    }


    // Schedule post-visit feedback notification 3h after class ends (fire-and-forget)
    schedulePostVisitFeedbackNotification(booking, classItem).catch(err =>
      console.error('Notification scheduling error:', err.message)
    );

    res.status(201).json({
      success: true,
      message: 'Booking created successfully',
      data: booking
    });

  } catch (error) {
    console.error('Create booking error:', error);
    console.error('Error stack:', error.stack);
    console.error('Error details:', {
      message: error.message,
      name: error.name,
      code: error.code
    });
    res.status(500).json({ 
      message: 'Server error creating booking',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
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
// @desc    Cancel a booking with Stripe refund
// @access  Private
router.put('/:id/cancel', [
  protect,
  body('reason').optional().trim()
], async (req, res) => {
  try {
    const { reason } = req.body;

    const booking = await Booking.findById(req.params.id)
      .populate('class')
      .populate('parent', 'fullName email');

    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Authorization: parent who owns the booking, or provider of the class
    const isOwner = booking.parent._id.toString() === req.user.id;
    const isProvider = req.user.userType === 'provider' &&
                       booking.class.provider.toString() === req.user.id;

    if (!isOwner && !isProvider) {
      return res.status(403).json({ message: 'Not authorized to cancel this booking' });
    }

    // State guards
    if (booking.status === 'cancelled') {
      return res.status(400).json({ message: 'Booking is already cancelled' });
    }
    if (booking.status === 'completed') {
      return res.status(400).json({ message: 'Cannot cancel a completed booking' });
    }

    // Determine refund amount based on who is cancelling and timing
    const sessionDate = new Date(booking.sessionDate);
    const now = new Date();
    const hoursUntilSession = (sessionDate - now) / (1000 * 60 * 60);
    const SERVICE_FEE = 1.99;

    let refundAmount = 0;
    let refundReason = '';

    if (isProvider) {
      // Provider cancellation: full refund including service fee
      refundAmount = booking.totalAmount;
      refundReason = 'provider_cancellation';
    } else {
      // Parent cancellation: full refund minus service fee if >24h, otherwise nothing
      if (hoursUntilSession > 24) {
        refundAmount = Math.max(0, booking.totalAmount - SERVICE_FEE);
        refundReason = 'parent_cancellation_outside_window';
      } else {
        refundAmount = 0;
        refundReason = 'parent_cancellation_inside_window';
      }
    }

    console.log(`🚫 Cancelling booking ${booking.bookingNumber}: ${refundReason}, refund £${refundAmount.toFixed(2)}`);

    // Process Stripe refund if applicable
    let stripeRefund = null;
    if (refundAmount > 0 && booking.paymentStatus === 'paid' && booking.stripeChargeId) {
      try {
        const refundAmountInCents = Math.round(refundAmount * 100);
        stripeRefund = await stripe.refunds.create({
          charge: booking.stripeChargeId,
          amount: refundAmountInCents,
          reason: 'requested_by_customer',
          metadata: {
            bookingId: booking._id.toString(),
            bookingNumber: booking.bookingNumber,
            cancellationReason: refundReason,
            cancelledBy: isProvider ? 'provider' : 'parent'
          }
        });
        console.log(`✅ Stripe refund created: ${stripeRefund.id}, status: ${stripeRefund.status}`);
      } catch (stripeError) {
        console.error(`❌ Stripe refund failed:`, stripeError.message);
        return res.status(500).json({
          message: 'Failed to process refund. Please contact support.',
          error: stripeError.message
        });
      }
    } else if (refundAmount > 0 && !booking.stripeChargeId) {
      console.warn(`⚠️ Refund owed (£${refundAmount}) but no stripeChargeId on booking ${booking.bookingNumber}`);
    }

    // Update booking
    booking.status = 'cancelled';
    booking.cancelledAt = new Date();
    booking.cancellationReason = reason || refundReason;
    booking.refundAmount = refundAmount;
    if (refundAmount > 0 && stripeRefund) {
      booking.paymentStatus = 'refunded';
    }
    await booking.save();

    // Decrement class booking count
    await Class.findByIdAndUpdate(booking.class._id, {
      $inc: { currentBookings: -1 }
    });

    // Send cancellation email
    try {
      await emailService.sendCancellationEmail({
        booking,
        cancelledBy: isProvider ? 'provider' : 'parent',
        refundAmount,
        reason: refundReason
      });
    } catch (emailErr) {
      console.error('⚠️ Cancellation email failed (non-blocking):', emailErr.message);
    }

    res.json({
      success: true,
      message: refundAmount > 0
        ? `Booking cancelled. Refund of £${refundAmount.toFixed(2)} will appear on the original card in 5-10 business days.`
        : 'Booking cancelled. No refund applies as this cancellation is inside the 24-hour window.',
      data: {
        ...booking.toObject(),
        refundAmount,
        refundReason,
        stripeRefundId: stripeRefund?.id || null
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


// ── Post-visit feedback notification scheduler ────────────────────────────
async function schedulePostVisitFeedbackNotification(booking, classItem) {
  try {
    const durationMinutes = classItem.duration || 60; // default 60 min if not set

    // Parse sessionDate + sessionTime into a start datetime
    const sessionDate = new Date(booking.sessionDate);
    if (classItem.sessionTime || booking.sessionTime) {
      const timeParts = (booking.sessionTime || '').match(/(\d+):(\d+)/);
      if (timeParts) {
        sessionDate.setHours(parseInt(timeParts[1], 10), parseInt(timeParts[2], 10), 0, 0);
      }
    }

    // Calculate when the class actually ends
    const classEndTime = new Date(sessionDate.getTime() + durationMinutes * 60 * 1000);
    
    // Schedule feedback notification 3 hours after class ends
    const sendAt = new Date(classEndTime.getTime() + 3 * 60 * 60 * 1000);

    // Avoid duplicate notifications for same booking
    const existing = await ScheduledNotification.findOne({ bookingId: booking._id, status: 'pending' });
    if (existing) return;

    await ScheduledNotification.create({
      userId:    booking.parent,
      bookingId: booking._id,
      classId:   booking.class._id || booking.class,
      className: classItem.name || 'your class',
      sendAt,
    });

    console.log(`🔔 Feedback notification scheduled for booking ${booking._id} at ${sendAt.toISOString()}`);
  } catch (err) {
    console.error('schedulePostVisitFeedbackNotification error:', err.message);
    throw err;
  }
}

module.exports = router; 