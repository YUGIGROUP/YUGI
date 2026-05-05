const express = require('express');
const router = express.Router();
const SavedVenue = require('../models/SavedVenue');
const { protect: auth } = require('../middleware/auth');

// POST /api/saved-venues
router.post('/', auth, async (req, res) => {
  try {
    const { placeId, venueName } = req.body;

    if (!placeId || !venueName) {
      return res.status(400).json({ error: 'placeId and venueName are required' });
    }

    const savedAt = new Date();
    const savedVenue = await SavedVenue.findOneAndUpdate(
      { userId: req.user.id, placeId },
      {
        $set: {
          venueName,
          savedAt,
          promptShown: false,
          promptShownAt: null,
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    return res.status(200).json(savedVenue);
  } catch (err) {
    console.error('POST /api/saved-venues error:', err.message);
    return res.status(500).json({ error: 'Failed to save venue' });
  }
});

// DELETE /api/saved-venues/:placeId
router.delete('/:placeId', auth, async (req, res) => {
  try {
    const { placeId } = req.params;
    await SavedVenue.deleteOne({ userId: req.user.id, placeId });
    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('DELETE /api/saved-venues/:placeId error:', err.message);
    return res.status(500).json({ error: 'Failed to remove saved venue' });
  }
});

// GET /api/saved-venues
router.get('/', auth, async (req, res) => {
  try {
    const savedVenues = await SavedVenue.find({ userId: req.user.id })
      .sort({ savedAt: -1 })
      .lean();
    return res.status(200).json(savedVenues);
  } catch (err) {
    console.error('GET /api/saved-venues error:', err.message);
    return res.status(500).json({ error: 'Failed to fetch saved venues' });
  }
});

// GET /api/saved-venues/:placeId
router.get('/:placeId', auth, async (req, res) => {
  try {
    const { placeId } = req.params;
    const savedVenue = await SavedVenue.findOne({ userId: req.user.id, placeId })
      .select('savedAt')
      .lean();

    if (!savedVenue) {
      return res.status(200).json({ saved: false });
    }

    return res.status(200).json({
      saved: true,
      savedAt: savedVenue.savedAt,
    });
  } catch (err) {
    console.error('GET /api/saved-venues/:placeId error:', err.message);
    return res.status(500).json({ error: 'Failed to fetch saved venue status' });
  }
});

module.exports = router;
