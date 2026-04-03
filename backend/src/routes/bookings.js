const express              = require('express');
const router               = express.Router();
const Booking              = require('../models/Booking');
const ScheduledNotification = require('../models/ScheduledNotification');
const { protect: auth }    = require('../middleware/auth');

// POST /api/bookings
// Records a confirmed booking and schedules a post-visit feedback notification
// for 3 hours after the class ends.
router.post('/', auth, async (req, res) => {
  try {
    const {
      externalBookingId,
      classId,
      className,
      venuePlaceId,
      venueName,
      classStartTime,
      duration, // minutes
    } = req.body;

    if (!externalBookingId || !classId || !className || !classStartTime || !duration) {
      return res.status(400).json({
        error: 'externalBookingId, classId, className, classStartTime, and duration are required',
      });
    }

    const startTime = new Date(classStartTime);
    if (isNaN(startTime.getTime())) {
      return res.status(400).json({ error: 'classStartTime must be a valid ISO8601 date' });
    }

    const durationMinutes = Number(duration);
    if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) {
      return res.status(400).json({ error: 'duration must be a positive number (minutes)' });
    }

    const classEndTime = new Date(startTime.getTime() + durationMinutes * 60 * 1000);
    const sendAt       = new Date(classEndTime.getTime() + 3 * 60 * 60 * 1000);

    // Upsert — re-booking after cancellation should update rather than error
    const booking = await Booking.findOneAndUpdate(
      { externalBookingId },
      {
        userId: req.user.id,
        classId,
        className,
        venuePlaceId: venuePlaceId || null,
        venueName:    venueName    || null,
        classStartTime: startTime,
        duration:       durationMinutes,
        classEndTime,
      },
      { upsert: true, new: true }
    );

    // Create notification only if none already pending for this booking
    const existing = await ScheduledNotification.findOne({ bookingId: booking._id, status: 'pending' });
    if (!existing) {
      await ScheduledNotification.create({
        userId:    req.user.id,
        bookingId: booking._id,
        classId,
        className,
        sendAt,
      });
    }

    return res.status(201).json({
      success:   true,
      bookingId: booking._id,
      sendAt,
    });
  } catch (err) {
    console.error('POST /api/bookings error:', err.message);
    return res.status(500).json({ error: 'Failed to record booking' });
  }
});

module.exports = router;
