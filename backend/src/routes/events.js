const express = require('express');
const router  = express.Router();
const Event   = require('../models/Event');
const { protect } = require('../middleware/auth');

const VALID_EVENT_TYPES = [
  'class_viewed',
  'class_searched',
  'booking_started',
  'booking_completed',
  'booking_cancelled',
  'venue_checked',
  'filter_used',
  'class_favorited',
  'doability_warning_seen',
  'venue_enrichment_requested',
];

function buildEventDoc(body, userId) {
  const { eventType, classId, metadata, timestamp, sessionId, parentLocation, venueLocation } = body;
  return {
    userId,
    eventType,
    classId:        classId        || null,
    metadata:       metadata       || {},
    timestamp:      timestamp      ? new Date(timestamp) : new Date(),
    sessionId:      sessionId      || null,
    parentLocation: parentLocation || null,
    venueLocation:  venueLocation  || null,
  };
}

// POST /api/events — single event
router.post('/', protect, async (req, res) => {
  try {
    const { eventType } = req.body;
    if (!eventType || !VALID_EVENT_TYPES.includes(eventType)) {
      return res.status(400).json({ error: `Invalid eventType. Must be one of: ${VALID_EVENT_TYPES.join(', ')}` });
    }
    const event = await Event.create(buildEventDoc(req.body, req.user._id));
    return res.status(201).json({ success: true, eventId: event._id });
  } catch (err) {
    console.error('POST /api/events error:', err.message);
    return res.status(500).json({ error: 'Failed to record event' });
  }
});

// POST /api/events/batch — multiple events at once
router.post('/batch', protect, async (req, res) => {
  try {
    const { events } = req.body;
    if (!Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ error: 'events must be a non-empty array' });
    }
    const invalid = events.find(e => !VALID_EVENT_TYPES.includes(e.eventType));
    if (invalid) {
      return res.status(400).json({ error: `Invalid eventType "${invalid.eventType}"` });
    }
    const docs = events.map(e => buildEventDoc(e, req.user._id));
    const inserted = await Event.insertMany(docs, { ordered: false });
    return res.status(201).json({ success: true, count: inserted.length });
  } catch (err) {
    console.error('POST /api/events/batch error:', err.message);
    return res.status(500).json({ error: 'Failed to record events' });
  }
});

// GET /api/events/stats — admin only
router.get('/stats', protect, async (req, res) => {
  try {
    if (req.user.userType !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    const [countsByType, mostViewedClasses, searchTerms, cancellationReasons] = await Promise.all([
      Event.aggregate([
        { $group: { _id: '$eventType', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
      ]),
      Event.aggregate([
        { $match: { eventType: 'class_viewed', classId: { $ne: null } } },
        { $group: { _id: '$classId', views: { $sum: 1 } } },
        { $sort: { views: -1 } },
        { $limit: 20 },
        { $lookup: { from: 'classes', localField: '_id', foreignField: '_id', as: 'class' } },
        { $unwind: { path: '$class', preserveNullAndEmptyArrays: true } },
        { $project: { classId: '$_id', views: 1, name: '$class.name', _id: 0 } },
      ]),
      Event.aggregate([
        { $match: { eventType: 'class_searched', 'metadata.query': { $exists: true, $ne: '' } } },
        { $group: { _id: '$metadata.query', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 20 },
        { $project: { term: '$_id', count: 1, _id: 0 } },
      ]),
      Event.aggregate([
        { $match: { eventType: 'booking_cancelled' } },
        { $group: { _id: { $ifNull: ['$metadata.reason', 'no_reason_given'] }, count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $project: { reason: '$_id', count: 1, _id: 0 } },
      ]),
    ]);
    return res.json({
      countsByType: countsByType.reduce((acc, { _id, count }) => { acc[_id] = count; return acc; }, {}),
      mostViewedClasses,
      mostSearchedTerms: searchTerms,
      cancellationReasons,
    });
  } catch (err) {
    console.error('GET /api/events/stats error:', err.message);
    return res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

module.exports = router;
