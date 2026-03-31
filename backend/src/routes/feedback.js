const express             = require('express');
const router              = express.Router();
const PostVisitFeedback   = require('../models/PostVisitFeedback');
const ScheduledNotification = require('../models/ScheduledNotification');
const VenueEnrichment     = require('../models/VenueEnrichment');
const Booking             = require('../models/Booking');
const Event               = require('../models/Event');
const { protect }         = require('../middleware/auth');

// POST /api/feedback
router.post('/', protect, async (req, res) => {
  try {
    const {
      bookingId,
      attended,
      rating,
      babyChangingAccurate,
      pramAccessAccurate,
      parkingAccurate,
      comments,
    } = req.body;

    if (!bookingId) {
      return res.status(400).json({ message: 'bookingId is required' });
    }
    if (attended === undefined || attended === null) {
      return res.status(400).json({ message: 'attended is required' });
    }

    const booking = await Booking.findById(bookingId).populate('class', 'name location');
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Only the booking owner can submit feedback
    if (booking.parent.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorised to submit feedback for this booking' });
    }

    const scheduledNotif = await ScheduledNotification.findOne({
      bookingId: booking._id,
      status: { $in: ['sent', 'pending'] },
    });

    const feedback = await PostVisitFeedback.create({
      bookingId:            booking._id,
      classId:              booking.class?._id || booking.class,
      userId:               req.user.id,
      venuePlaceId:         booking.class?.location?.placeId || null,
      attended:             Boolean(attended),
      rating:               rating              ?? null,
      babyChangingAccurate: babyChangingAccurate ?? null,
      pramAccessAccurate:   pramAccessAccurate  ?? null,
      parkingAccurate:      parkingAccurate     ?? null,
      comments:             comments            || null,
      notificationSentAt:   scheduledNotif?.updatedAt || null,
      respondedAt:          new Date(),
    });

    if (scheduledNotif) {
      await ScheduledNotification.findByIdAndUpdate(scheduledNotif._id, { status: 'sent' });
    }

    await Event.create({
      userId:    req.user.id,
      eventType: 'feedback_submitted',
      classId:   booking.class?._id || null,
      metadata:  { bookingId, attended: Boolean(attended), rating: rating ?? null },
    }).catch(e => console.error('Event tracking error:', e.message));

    // Upgrade venue confidence after 3+ confirming parent feedbacks
    const venuePlaceId = booking.class?.location?.placeId;
    if (venuePlaceId) {
      maybeUpgradeVenueConfidence(venuePlaceId).catch(e =>
        console.error('Venue confidence upgrade error:', e.message)
      );
    }

    return res.status(201).json({ success: true, feedbackId: feedback._id });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({ message: 'Feedback already submitted for this booking' });
    }
    console.error('POST /api/feedback error:', err.message);
    return res.status(500).json({ message: 'Failed to save feedback' });
  }
});

// GET /api/feedback/:classId — aggregated feedback for a class
router.get('/:classId', async (req, res) => {
  try {
    const { classId } = req.params;
    const feedbacks = await PostVisitFeedback.find({ classId, attended: true });

    if (feedbacks.length === 0) {
      return res.json({ classId, count: 0 });
    }

    const ratings = feedbacks.filter(f => f.rating != null).map(f => f.rating);
    const avgRating = ratings.length
      ? Math.round((ratings.reduce((a, b) => a + b, 0) / ratings.length) * 10) / 10
      : null;

    const accuracy = (field) => {
      const relevant = feedbacks.filter(f => f[field] != null);
      if (!relevant.length) return null;
      const yes = relevant.filter(f => f[field] === true).length;
      return Math.round((yes / relevant.length) * 100);
    };

    return res.json({
      classId,
      count:                feedbacks.length,
      averageRating:        avgRating,
      babyChangingAccuracy: accuracy('babyChangingAccurate'),
      pramAccessAccuracy:   accuracy('pramAccessAccurate'),
      parkingAccuracy:      accuracy('parkingAccurate'),
    });
  } catch (err) {
    console.error('GET /api/feedback/:classId error:', err.message);
    return res.status(500).json({ message: 'Failed to fetch feedback' });
  }
});

async function maybeUpgradeVenueConfidence(venuePlaceId) {
  const confirming = await PostVisitFeedback.countDocuments({
    venuePlaceId,
    attended: true,
    $or: [
      { babyChangingAccurate: true },
      { pramAccessAccurate: true },
      { parkingAccurate: true },
    ],
  });
  if (confirming >= 3) {
    await VenueEnrichment.findOneAndUpdate(
      { placeId: venuePlaceId, confidence: 'web_enriched' },
      { confidence: 'parent_verified' }
    );
  }
}

module.exports = router;
