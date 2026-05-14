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

// GET /api/saved-venues/pending-prompt
router.get('/pending-prompt', auth, async (req, res) => {
  try {
    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - (24 * 60 * 60 * 1000));
    const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));

    const savedVenue = await SavedVenue.findOne({
      userId: req.user.id,
      savedAt: { $gte: sevenDaysAgo, $lte: twentyFourHoursAgo },
      promptShown: false,
      feedbackSubmitted: false,
      didNotVisit: false,
    })
      .sort({ savedAt: -1 })
      .select('placeId venueName savedAt')
      .lean();

    if (!savedVenue) {
      return res.status(200).json({ pending: false });
    }

    return res.status(200).json({
      pending: true,
      savedVenue: {
        placeId: savedVenue.placeId,
        venueName: savedVenue.venueName,
        savedAt: savedVenue.savedAt,
      },
    });
  } catch (err) {
    console.error('GET /api/saved-venues/pending-prompt error:', err.message);
    return res.status(500).json({ error: 'Failed to fetch pending venue prompt' });
  }
});

// POST /api/saved-venues/:placeId/mark-prompt-shown
router.post('/:placeId/mark-prompt-shown', auth, async (req, res) => {
  try {
    const { placeId } = req.params;

    const updated = await SavedVenue.findOneAndUpdate(
      { userId: req.user.id, placeId },
      {
        $set: {
          promptShown: true,
          promptShownAt: new Date(),
        },
      },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ error: 'Saved venue not found' });
    }

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('POST /api/saved-venues/:placeId/mark-prompt-shown error:', err.message);
    return res.status(500).json({ error: 'Failed to mark venue prompt shown' });
  }
});

// Mark a saved venue as not visited — parent saved it but didn't go.
// Captures negative-space data + prevents re-prompting.
router.post('/:placeId/mark-not-visited', auth, async (req, res) => {
  try {
    const { placeId } = req.params;
    const updated = await SavedVenue.findOneAndUpdate(
      { userId: req.user.id, placeId },
      {
        $set: {
          didNotVisit: true,
          didNotVisitAt: new Date(),
          promptShown: true,
          promptShownAt: new Date(),
        },
      },
      { new: true }
    );
    if (!updated) {
      return res.status(404).json({ success: false, error: 'SavedVenue not found' });
    }
    return res.json({ success: true, savedVenue: updated });
  } catch (err) {
    console.error('mark-not-visited error:', err);
    return res.status(500).json({ success: false, error: 'Failed to mark not visited' });
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
