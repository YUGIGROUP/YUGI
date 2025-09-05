const express = require('express');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const Class = require('../models/Class');
const Booking = require('../models/Booking');
const { protect, requireUserType } = require('../middleware/auth');
const { sendEmail } = require('../services/emailService');

const router = express.Router();

// Admin middleware - only allow admin users
const requireAdmin = async (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({ message: 'Authentication required' });
  }

  if (req.user.userType !== 'admin') {
    return res.status(403).json({ message: 'Admin access required' });
  }

  next();
};

// @route   GET /api/admin/providers/pending
// @desc    Get all pending provider applications
// @access  Private (admin only)
router.get('/providers/pending', protect, requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 10, status } = req.query;
    
    let query = { userType: 'provider' };
    
    if (status) {
      query.verificationStatus = status;
    } else {
      // Default to pending and under review
      query.verificationStatus = { $in: ['pending', 'underReview'] };
    }

    const providers = await User.find(query)
      .select('-password')
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit)
      .exec();

    const total = await User.countDocuments(query);

    res.json({
      success: true,
      data: {
        providers,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });

  } catch (error) {
    console.error('Get pending providers error:', error);
    res.status(500).json({ message: 'Server error fetching pending providers' });
  }
});

// @route   GET /api/admin/providers/:id
// @desc    Get specific provider application details
// @access  Private (admin only)
router.get('/providers/:id', protect, requireAdmin, async (req, res) => {
  try {
    const provider = await User.findById(req.params.id)
      .select('-password');

    if (!provider) {
      return res.status(404).json({ message: 'Provider not found' });
    }

    if (provider.userType !== 'provider') {
      return res.status(400).json({ message: 'User is not a provider' });
    }

    res.json({
      success: true,
      data: provider
    });

  } catch (error) {
    console.error('Get provider details error:', error);
    res.status(500).json({ message: 'Server error fetching provider details' });
  }
});

// @route   PUT /api/admin/providers/:id/verify
// @desc    Approve or reject provider application
// @access  Private (admin only)
router.put('/providers/:id/verify', [
  protect,
  requireAdmin,
  body('action').isIn(['approve', 'reject']).withMessage('Action must be approve or reject'),
  body('reason').optional().trim().isLength({ min: 10 }).withMessage('Reason must be at least 10 characters')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { action, reason } = req.body;
    const providerId = req.params.id;

    const provider = await User.findById(providerId);
    if (!provider) {
      return res.status(404).json({ message: 'Provider not found' });
    }

    if (provider.userType !== 'provider') {
      return res.status(400).json({ message: 'User is not a provider' });
    }

    // Update verification status
    provider.verificationStatus = action === 'approve' ? 'approved' : 'rejected';
    provider.verificationDate = new Date();
    
    if (action === 'reject' && reason) {
      provider.rejectionReason = reason;
    }

    await provider.save();

    // Send email notification
    const emailSubject = action === 'approve' 
      ? 'Your YUGI Provider Application Has Been Approved! 🎉'
      : 'Update on Your YUGI Provider Application';

    const emailBody = action === 'approve' 
      ? `
        <h2>Congratulations! Your application has been approved!</h2>
        <p>Dear ${provider.fullName},</p>
        <p>Great news! Your YUGI provider application has been approved. You can now:</p>
        <ul>
          <li>Create and publish classes</li>
          <li>Manage bookings and schedules</li>
          <li>Connect with parents and children</li>
          <li>Access your provider dashboard</li>
        </ul>
        <p>Welcome to the YUGI community! We're excited to have you on board.</p>
        <p>Best regards,<br>The YUGI Team</p>
      `
      : `
        <h2>Update on Your Provider Application</h2>
        <p>Dear ${provider.fullName},</p>
        <p>Thank you for your interest in becoming a YUGI provider. After careful review, we were unable to approve your application at this time.</p>
        <p><strong>Reason:</strong> ${reason}</p>
        <p>You may reapply in the future with updated documentation. If you have any questions, please don't hesitate to contact our support team.</p>
        <p>Best regards,<br>The YUGI Team</p>
      `;

    try {
      await sendEmail(provider.email, emailSubject, emailBody);
    } catch (emailError) {
      console.error('Failed to send verification email:', emailError);
      // Don't fail the request if email fails
    }

    res.json({
      success: true,
      message: `Provider application ${action}d successfully`,
      data: {
        verificationStatus: provider.verificationStatus,
        verificationDate: provider.verificationDate,
        rejectionReason: provider.rejectionReason
      }
    });

  } catch (error) {
    console.error('Verify provider error:', error);
    res.status(500).json({ message: 'Server error processing verification' });
  }
});

// @route   GET /api/admin/dashboard
// @desc    Get admin dashboard statistics
// @access  Private (admin only)
router.get('/dashboard', protect, requireAdmin, async (req, res) => {
  try {
    // Get counts
    const totalUsers = await User.countDocuments();
    const totalProviders = await User.countDocuments({ userType: 'provider' });
    const pendingProviders = await User.countDocuments({ 
      userType: 'provider', 
      verificationStatus: { $in: ['pending', 'underReview'] } 
    });
    const approvedProviders = await User.countDocuments({ 
      userType: 'provider', 
      verificationStatus: 'approved' 
    });
    const totalClasses = await Class.countDocuments();
    const publishedClasses = await Class.countDocuments({ isPublished: true });
    const totalBookings = await Booking.countDocuments();
    const completedBookings = await Booking.countDocuments({ status: 'completed' });

    // Get recent pending applications
    const recentPending = await User.find({ 
      userType: 'provider', 
      verificationStatus: { $in: ['pending', 'underReview'] } 
    })
    .select('fullName businessName email verificationStatus createdAt')
    .sort({ createdAt: -1 })
    .limit(5);

    res.json({
      success: true,
      data: {
        stats: {
          totalUsers,
          totalProviders,
          pendingProviders,
          approvedProviders,
          totalClasses,
          publishedClasses,
          totalBookings,
          completedBookings
        },
        recentPending
      }
    });

  } catch (error) {
    console.error('Get admin dashboard error:', error);
    res.status(500).json({ message: 'Server error fetching admin dashboard' });
  }
});

// @route   GET /api/admin/providers
// @desc    Get all providers with filtering
// @access  Private (admin only)
router.get('/providers', protect, requireAdmin, async (req, res) => {
  try {
    const { 
      page = 1, 
      limit = 20, 
      status, 
      search,
      sortBy = 'createdAt',
      sortOrder = 'desc'
    } = req.query;

    let query = { userType: 'provider' };
    
    if (status) {
      query.verificationStatus = status;
    }

    if (search) {
      query.$or = [
        { fullName: { $regex: search, $options: 'i' } },
        { businessName: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } }
      ];
    }

    const sortOptions = {};
    sortOptions[sortBy] = sortOrder === 'desc' ? -1 : 1;

    const providers = await User.find(query)
      .select('-password')
      .sort(sortOptions)
      .limit(limit * 1)
      .skip((page - 1) * limit)
      .exec();

    const total = await User.countDocuments(query);

    res.json({
      success: true,
      data: {
        providers,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });

  } catch (error) {
    console.error('Get providers error:', error);
    res.status(500).json({ message: 'Server error fetching providers' });
  }
});

module.exports = router; 