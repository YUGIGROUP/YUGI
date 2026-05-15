const express = require('express');
const router = express.Router();
const Document = require('../models/Document');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const documentUpload = require('../middleware/documentUpload');
const { uploadDocument, deleteDocument } = require('../services/s3Service');
const { sendAdminNotification } = require('../services/pushNotificationService');

const VALID_TYPES = ['insurance', 'dbs', 'qualifications', 'business_registration'];

/**
 * POST /api/providers/documents
 * Upload a new verification document.
 * multipart/form-data: file=<file>, documentType=<string>, expiryDate=<ISO date string, optional>
 */
router.post('/documents', protect, documentUpload.single('file'), async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    const { documentType, expiryDate } = req.body;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ success: false, error: 'No file uploaded' });
    }

    if (!VALID_TYPES.includes(documentType)) {
      return res.status(400).json({
        success: false,
        error: `Invalid documentType. Must be one of: ${VALID_TYPES.join(', ')}`,
      });
    }

    // Validate expiryDate for DBS — required, must be in the future
    let parsedExpiry = null;
    if (documentType === 'dbs') {
      if (!expiryDate) {
        return res.status(400).json({ success: false, error: 'expiryDate is required for DBS documents' });
      }
      parsedExpiry = new Date(expiryDate);
      if (isNaN(parsedExpiry.getTime()) || parsedExpiry <= new Date()) {
        return res.status(400).json({ success: false, error: 'expiryDate must be a valid future date' });
      }
    } else if (expiryDate) {
      parsedExpiry = new Date(expiryDate);
      if (isNaN(parsedExpiry.getTime())) {
        parsedExpiry = null;
      }
    }

    // Upload to S3
    const { s3Key } = await uploadDocument({
      userId: userId.toString(),
      documentType,
      fileBuffer: file.buffer,
      mimeType: file.mimetype,
      originalFileName: file.originalname,
    });

    // Persist Document row
    const doc = await Document.create({
      userId,
      documentType,
      s3Key,
      originalFileName: file.originalname,
      mimeType: file.mimetype,
      sizeBytes: file.size,
      status: 'pending',
      expiryDate: parsedExpiry,
    });

    // Update user verificationStatus to underReview if pending
    const user = await User.findById(userId);
    if (user && user.verificationStatus === 'pending') {
      user.verificationStatus = 'underReview';
      user.verificationSubmittedAt = new Date();
      await user.save();
    }

    // Notify admin queue
    try {
      const title = 'New verification document';
      const body = `${user?.fullName || 'A provider'} uploaded a ${documentType.replace('_', ' ')} document for review.`;
      const payload = { type: 'document_review', documentId: doc._id.toString() };

      const admins = await User.find({ isAdmin: true, deviceToken: { $ne: null }, devicePlatform: 'ios' })
        .select('deviceToken')
        .lean();

      await Promise.all(
        admins.map(admin =>
          sendAdminNotification({ deviceToken: admin.deviceToken, title, body, payload })
            .catch(err => console.error('Admin document review push failed:', err.message))
        )
      );
    } catch (e) {
      console.warn('Failed to send admin notification:', e.message);
    }

    return res.status(201).json({ success: true, document: doc });
  } catch (err) {
    // Multer file-size / mime errors come through here
    if (err.message?.includes('File too large') || err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ success: false, error: 'File too large. Maximum 10MB.' });
    }
    if (err.message?.includes('Invalid file type')) {
      return res.status(400).json({ success: false, error: err.message });
    }
    console.error('Document upload error:', err);
    return res.status(500).json({ success: false, error: 'Failed to upload document' });
  }
});

/**
 * GET /api/providers/me/documents
 * List the current provider's documents.
 */
router.get('/me/documents', protect, async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    const docs = await Document.find({ userId })
      .sort({ uploadedAt: -1 })
      .select('-s3Key') // Don't expose S3 keys to clients
      .lean();
    return res.json({ success: true, documents: docs });
  } catch (err) {
    console.error('List provider documents error:', err);
    return res.status(500).json({ success: false, error: 'Failed to list documents' });
  }
});

/**
 * DELETE /api/providers/documents/:id
 * Provider deletes one of their own documents — only if status is still pending.
 */
router.delete('/documents/:id', protect, async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    const doc = await Document.findOne({ _id: req.params.id, userId });

    if (!doc) {
      return res.status(404).json({ success: false, error: 'Document not found' });
    }
    if (doc.status !== 'pending') {
      return res.status(403).json({ success: false, error: 'Only pending documents can be deleted' });
    }

    try {
      await deleteDocument(doc.s3Key);
    } catch (e) {
      console.warn('Failed to delete from S3 (continuing):', e.message);
    }

    await Document.deleteOne({ _id: doc._id });
    return res.json({ success: true });
  } catch (err) {
    console.error('Delete document error:', err);
    return res.status(500).json({ success: false, error: 'Failed to delete document' });
  }
});

module.exports = router;
