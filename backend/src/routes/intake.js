const express = require('express');
const { body, validationResult } = require('express-validator');
const IntakeResponse = require('../models/IntakeResponse');
const Booking = require('../models/Booking');
const Class = require('../models/Class');
const { protect } = require('../middleware/auth');

const router = express.Router();

// @route   POST /api/intake
// @desc    Parent submits intake answers for a booking
// @access  Private
router.post('/', [
  protect,
  body('bookingId').notEmpty().withMessage('bookingId is required'),
  body('answers').isArray({ min: 1 }),
  body('answers.*.questionText').trim().notEmpty(),
  body('answers.*.answerType').isIn(['free_text', 'multiple_choice']),
  body('answers.*.answer').trim()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ message: 'Validation failed', errors: errors.array() });
    }

    const { bookingId, answers } = req.body;

    // Look up the booking when bookingId is a valid MongoDB ObjectId.
    // For local UUID bookings (Apple Pay simulation) there is no server record —
    // in that case we trust the authenticated user and use the classId from the body.
    const mongoose = require('mongoose');
    let classDoc;
    if (mongoose.Types.ObjectId.isValid(bookingId)) {
      const booking = await Booking.findById(bookingId).populate('class');
      if (!booking) {
        return res.status(404).json({ message: 'Booking not found' });
      }
      if (booking.parent.toString() !== req.user._id.toString()) {
        return res.status(403).json({ message: 'Not authorised' });
      }
      classDoc = booking.class;
    } else {
      // UUID fallback — classId must be supplied in the body
      const { classId } = req.body;
      if (!classId || !mongoose.Types.ObjectId.isValid(classId)) {
        return res.status(400).json({ message: 'classId required for non-API bookings' });
      }
      classDoc = await require('../models/Class').findById(classId);
      if (!classDoc) {
        return res.status(404).json({ message: 'Class not found' });
      }
    }

    // Prevent duplicate submission
    const existing = await IntakeResponse.findOne({ bookingId, parentId: req.user._id });
    if (existing) {
      return res.status(400).json({ message: 'Intake form already submitted for this booking' });
    }

    const response = await IntakeResponse.create({
      bookingId,
      classId: classDoc._id,
      parentId: req.user._id,
      providerId: classDoc.provider,
      answers
    });

    res.status(201).json({ success: true, data: response });
  } catch (err) {
    console.error('Intake POST error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/intake/class/:classId
// @desc    Provider gets all intake responses for a class
// @access  Private (provider who owns the class)
router.get('/class/:classId', protect, async (req, res) => {
  try {
    const classDoc = await Class.findById(req.params.classId);
    if (!classDoc) {
      return res.status(404).json({ message: 'Class not found' });
    }
    if (classDoc.provider.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Not authorised' });
    }

    const responses = await IntakeResponse.find({ classId: req.params.classId })
      .populate('parentId', 'fullName email')
      .populate('bookingId', 'bookingNumber sessionDate')
      .sort({ submittedAt: -1 });

    res.json({ success: true, data: responses });
  } catch (err) {
    console.error('Intake GET /class error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/intake/booking/:bookingId
// @desc    Get intake response for a specific booking
// @access  Private (parent who owns booking, or class provider)
router.get('/booking/:bookingId', protect, async (req, res) => {
  try {
    const response = await IntakeResponse.findOne({ bookingId: req.params.bookingId })
      .populate('parentId', 'fullName email')
      .populate('bookingId', 'bookingNumber sessionDate');

    if (!response) {
      return res.status(404).json({ message: 'Intake response not found' });
    }

    const userId = req.user._id.toString();
    const isOwner = response.parentId._id.toString() === userId;
    const isProvider = response.providerId.toString() === userId;

    if (!isOwner && !isProvider) {
      return res.status(403).json({ message: 'Not authorised' });
    }

    res.json({ success: true, data: response });
  } catch (err) {
    console.error('Intake GET /booking error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
