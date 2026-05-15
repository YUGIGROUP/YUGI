const express = require('express');
const router = express.Router();
const Document = require('../models/Document');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const { getSignedViewUrl } = require('../services/s3Service');

// Inline admin gate — same pattern as routes/admin.js, supports both isAdmin and userType
const requireAdmin = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({ message: 'Authentication required' });
  }
  if (req.user.userType !== 'admin' && !req.user.isAdmin) {
    return res.status(403).json({ message: 'Admin access required' });
  }
  next();
};

/**
 * GET /api/admin/documents/pending
 * Admin review queue — list all documents needing review.
 */
router.get('/documents/pending', protect, requireAdmin, async (req, res) => {
  try {
    const docs = await Document.find({ status: 'pending' })
      .populate('userId', 'fullName email businessName')
      .sort({ uploadedAt: 1 }) // Oldest first — fairness
      .lean();
    return res.json({ success: true, documents: docs });
  } catch (err) {
    console.error('Admin pending list error:', err);
    return res.status(500).json({ success: false, error: 'Failed to list pending documents' });
  }
});

/**
 * GET /api/admin/documents/:id
 * Detail view with a signed download URL (15 min expiry).
 */
router.get('/documents/:id', protect, requireAdmin, async (req, res) => {
  try {
    const doc = await Document.findById(req.params.id)
      .populate('userId', 'fullName email businessName businessAddress verificationStatus')
      .lean();
    if (!doc) {
      return res.status(404).json({ success: false, error: 'Document not found' });
    }

    const viewUrl = await getSignedViewUrl(doc.s3Key, 900);

    // Don't leak s3Key to client
    delete doc.s3Key;

    return res.json({ success: true, document: doc, viewUrl });
  } catch (err) {
    console.error('Admin doc detail error:', err);
    return res.status(500).json({ success: false, error: 'Failed to load document' });
  }
});

/**
 * POST /api/admin/documents/:id/approve
 */
router.post('/documents/:id/approve', protect, requireAdmin, async (req, res) => {
  try {
    const adminId = req.user._id || req.user.id;
    const doc = await Document.findById(req.params.id);
    if (!doc) {
      return res.status(404).json({ success: false, error: 'Document not found' });
    }
    if (doc.status !== 'pending') {
      return res.status(400).json({ success: false, error: `Cannot approve document with status: ${doc.status}` });
    }

    doc.status = 'approved';
    doc.reviewedAt = new Date();
    doc.reviewedBy = adminId;
    await doc.save();

    // If this provider now has at least one approved insurance doc, promote their verificationStatus
    const hasApprovedInsurance = await Document.exists({ userId: doc.userId, documentType: 'insurance', status: 'approved' });
    if (hasApprovedInsurance) {
      const user = await User.findById(doc.userId);
      if (user && user.verificationStatus !== 'approved') {
        user.verificationStatus = 'approved';
        user.verificationDate = new Date();
        await user.save();
      }
    }

    return res.json({ success: true, document: doc });
  } catch (err) {
    console.error('Approve document error:', err);
    return res.status(500).json({ success: false, error: 'Failed to approve document' });
  }
});

/**
 * POST /api/admin/documents/:id/reject
 * Body: { reason: string }
 */
router.post('/documents/:id/reject', protect, requireAdmin, async (req, res) => {
  try {
    const adminId = req.user._id || req.user.id;
    const { reason } = req.body;

    if (!reason || typeof reason !== 'string' || reason.trim().length === 0) {
      return res.status(400).json({ success: false, error: 'reason is required' });
    }

    const doc = await Document.findById(req.params.id);
    if (!doc) {
      return res.status(404).json({ success: false, error: 'Document not found' });
    }
    if (doc.status !== 'pending') {
      return res.status(400).json({ success: false, error: `Cannot reject document with status: ${doc.status}` });
    }

    doc.status = 'rejected';
    doc.reviewedAt = new Date();
    doc.reviewedBy = adminId;
    doc.rejectionReason = reason.trim();
    await doc.save();

    return res.json({ success: true, document: doc });
  } catch (err) {
    console.error('Reject document error:', err);
    return res.status(500).json({ success: false, error: 'Failed to reject document' });
  }
});

module.exports = router;
