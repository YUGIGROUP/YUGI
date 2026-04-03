const express             = require('express');
const router              = express.Router();
const PostVisitFeedback   = require('../models/PostVisitFeedback');
const ScheduledNotification = require('../models/ScheduledNotification');
const VenueEnrichment     = require('../models/VenueEnrichment');
const Booking             = require('../models/Booking');
const Event               = require('../models/Event');
const auth                = require('../middleware/auth');

// POST /api/feedback
router.post('/', auth, async (req, res) => {
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
      return res.status(400).json({ error: 'bookingId is required' });
    }
    if (attended === undefined || attended === null) {
      return res.status(400).json({ error: 'attended is required' });
    }

    // Look up the booking for additional metadata
    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    // Find the matching scheduled notification so we can record when it was sent
    const scheduledNotif = await ScheduledNotification.findOne({
      bookingId: booking._id,
      status: { $in: ['sent', 'pending'] },
    });

    const feedback = await PostVisitFeedback.create({
      bookingId:           booking._id,
      classId:             booking.classId,
      userId:              req.user.id,
      venuePlaceId:        booking.venuePlaceId,
      attended:            Boolean(attended),
      rating:              rating              ?? null,
      babyChangingAccurate: babyChangingAccurate ?? null,
      pramAccessAccurate:  pramAccessAccurate  ?? null,
      parkingAccurate:     parkingAccurate     ?? null,
      comments:            comments            || null,
      notificationSentAt:  scheduledNotif?.updatedAt || null,
      respondedAt:         new Date(),
    });

    // Mark scheduled notification as responded
    if (scheduledNotif) {
      await ScheduledNotification.findByIdAndUpdate(scheduledNotif._id, { status: 'sent' });
    }

    // Track feedback_submitted event
    await Event.create({
      userId:    req.user.id,
      eventType: 'feedback_submitted',
      classId:   booking.classId || null,
      metadata:  { bookingId, attended: Boolean(attended), rating: rating ?? null },
    });

    // If 3+ feedbacks confirm venue data, upgrade confidence to 'parent_verified'
    if (booking.venuePlaceId) {
      await maybeUpgradeVenueConfidence(booking.venuePlaceId);
    }

    return res.status(201).json({ success: true, feedbackId: feedback._id });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({ error: 'Feedback already submitted for this booking' });
    }
    console.error('POST /api/feedback error:', err.message);
    return res.status(500).json({ error: 'Failed to save feedback' });
  }
});

// GET /api/feedback/pending — bookings where class ended 3+ hours ago with no feedback yet
router.get('/pending', auth, async (req, res) => {
  try {
    const threeHoursAgo = new Date(Date.now() - 3 * 60 * 60 * 1000);

    const bookings = await Booking.find({
      userId: req.user.id,
      classEndTime: { $lt: threeHoursAgo },
    }).select('_id className').lean();

    if (!bookings.length) {
      return res.json({ pending: [] });
    }

    const bookingIds = bookings.map(b => b._id);

    const reviewed = await PostVisitFeedback.find({
      bookingId: { $in: bookingIds },
    }).select('bookingId').lean();

    const reviewedSet = new Set(reviewed.map(f => f.bookingId.toString()));

    const pending = bookings
      .filter(b => !reviewedSet.has(b._id.toString()))
      .map(b => ({ bookingId: b._id, className: b.className }));

    return res.json({ pending });
  } catch (err) {
    console.error('GET /api/feedback/pending error:', err.message);
    return res.status(500).json({ error: 'Failed to fetch pending feedback' });
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
      count:                    feedbacks.length,
      averageRating:            avgRating,
      attendedCount:            feedbacks.length,
      babyChangingAccuracy:     accuracy('babyChangingAccurate'),
      pramAccessAccuracy:       accuracy('pramAccessAccurate'),
      parkingAccuracy:          accuracy('parkingAccurate'),
    });
  } catch (err) {
    console.error('GET /api/feedback/:classId error:', err.message);
    return res.status(500).json({ error: 'Failed to fetch feedback' });
  }
});

async function maybeUpgradeVenueConfidence(venuePlaceId) {
  try {
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
  } catch (err) {
    console.error('maybeUpgradeVenueConfidence error:', err.message);
  }
}

module.exports = router;
