const express = require('express');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const Class = require('../models/Class');
const Booking = require('../models/Booking');
const { protect, requireUserType } = require('../middleware/auth');

const router = express.Router();

// @route   GET /api/providers/dashboard
// @desc    Get provider dashboard data
// @access  Private (providers only)
router.get('/dashboard', protect, requireUserType(['provider']), async (req, res) => {
  try {
    const userId = req.user.id;

    // Get provider's classes
    const classes = await Class.find({ provider: userId });
    
    // Get recent bookings
    const recentBookings = await Booking.find({
      class: { $in: classes.map(c => c._id) }
    })
    .populate('class', 'name')
    .populate('parent', 'fullName')
    .sort({ createdAt: -1 })
    .limit(10);

    // Calculate statistics
    const totalClasses = classes.length;
    const publishedClasses = classes.filter(c => c.isPublished).length;
    const totalBookings = recentBookings.length;
    const totalRevenue = recentBookings
      .filter(b => b.paymentStatus === 'paid')
      .reduce((sum, b) => sum + b.totalAmount, 0);

    res.json({
      success: true,
      data: {
        stats: {
          totalClasses,
          publishedClasses,
          totalBookings,
          totalRevenue: parseFloat(totalRevenue.toFixed(2))
        },
        recentBookings,
        verificationStatus: req.user.verificationStatus
      }
    });

  } catch (error) {
    console.error('Get provider dashboard error:', error);
    res.status(500).json({ message: 'Server error fetching dashboard data' });
  }
});

// @route   PUT /api/providers/business-info
// @desc    Update provider business information
// @access  Private (providers only)
router.put('/business-info', [
  protect,
  requireUserType(['provider']),
  body('businessName').optional().trim().isLength({ min: 2 }),
  body('businessAddress').optional().trim().isLength({ min: 5 }),
  body('phoneNumber').optional().trim()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { businessName, businessAddress, phoneNumber } = req.body;

    const updatedUser = await User.findByIdAndUpdate(
      req.user.id,
      {
        businessName,
        businessAddress,
        phoneNumber
      },
      { new: true, runValidators: true }
    );

    res.json({
      success: true,
      message: 'Business information updated successfully',
      data: updatedUser
    });

  } catch (error) {
    console.error('Update business info error:', error);
    res.status(500).json({ message: 'Server error updating business information' });
  }
});

// @route   GET /api/providers/verification-status
// @desc    Get provider verification status
// @access  Private (providers only)
router.get('/verification-status', protect, requireUserType(['provider']), async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    
    res.json({
      success: true,
      data: {
        verificationStatus: user.verificationStatus,
        qualifications: user.qualifications,
        dbsCertificate: user.dbsCertificate,
        businessName: user.businessName,
        businessAddress: user.businessAddress
      }
    });

  } catch (error) {
    console.error('Get verification status error:', error);
    res.status(500).json({ message: 'Server error fetching verification status' });
  }
});

// @route   POST /api/providers/request-verification
// @desc    Request verification review
// @access  Private (providers only)
router.post('/request-verification', protect, requireUserType(['provider']), async (req, res) => {
  try {
    const user = await User.findById(req.user.id);

    if (!user.qualifications || !user.dbsCertificate) {
      return res.status(400).json({ 
        message: 'Qualifications and DBS certificate are required for verification' 
      });
    }

    if (user.verificationStatus === 'underReview') {
      return res.status(400).json({ 
        message: 'Verification is already under review' 
      });
    }

    user.verificationStatus = 'underReview';
    await user.save();

    res.json({
      success: true,
      message: 'Verification request submitted successfully',
      data: {
        verificationStatus: user.verificationStatus
      }
    });

  } catch (error) {
    console.error('Request verification error:', error);
    res.status(500).json({ message: 'Server error requesting verification' });
  }
});

// @route   GET /api/providers/analytics
// @desc    Get provider analytics
// @access  Private (providers only)
router.get('/analytics', protect, requireUserType(['provider']), async (req, res) => {
  try {
    const { period = '30' } = req.query; // days
    const userId = req.user.id;

    // Get date range
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(period));

    // Get provider's classes
    const classes = await Class.find({ provider: userId });
    const classIds = classes.map(c => c._id);

    // Get bookings in date range
    const bookings = await Booking.find({
      class: { $in: classIds },
      createdAt: { $gte: startDate, $lte: endDate }
    });

    // Calculate analytics
    const totalBookings = bookings.length;
    const confirmedBookings = bookings.filter(b => b.status === 'confirmed').length;
    const completedBookings = bookings.filter(b => b.status === 'completed').length;
    const cancelledBookings = bookings.filter(b => b.status === 'cancelled').length;
    
    const totalRevenue = bookings
      .filter(b => b.paymentStatus === 'paid')
      .reduce((sum, b) => sum + b.totalAmount, 0);

    const averageRating = classes.reduce((sum, c) => sum + c.averageRating, 0) / classes.length || 0;

    res.json({
      success: true,
      data: {
        period: parseInt(period),
        bookings: {
          total: totalBookings,
          confirmed: confirmedBookings,
          completed: completedBookings,
          cancelled: cancelledBookings
        },
        revenue: parseFloat(totalRevenue.toFixed(2)),
        averageRating: parseFloat(averageRating.toFixed(1)),
        totalClasses: classes.length
      }
    });

  } catch (error) {
    console.error('Get analytics error:', error);
    res.status(500).json({ message: 'Server error fetching analytics' });
  }
});

module.exports = router; 