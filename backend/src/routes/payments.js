const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { body, validationResult } = require('express-validator');
const Booking = require('../models/Booking');
const Class = require('../models/Class');
const User = require('../models/User');
const { protect, requireUserType, requireAdmin } = require('../middleware/auth');
const emailService = require('../services/emailService');
const { applyClassCompletion } = require('../utils/holdingPeriod');

const router = express.Router();

// @route   POST /api/payments/create-payment-intent
// @desc    Create a payment intent and charge the parent's saved card immediately
// @access  Private (parents and providers)
router.post('/create-payment-intent', [
  protect,
  requireUserType(['parent', 'provider']),
  body('bookingId').isMongoId(),
  body('paymentMethodId').isString().matches(/^pm_/).withMessage('paymentMethodId must be a Stripe payment method ID')
], async (req, res) => {
  console.log('💳 create-payment-intent', req.method, '- booking:', req.body.bookingId);

  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('❌ Validation errors:', errors.array());
      return res.status(400).json({ message: 'Validation failed', errors: errors.array() });
    }

    const { bookingId, paymentMethodId } = req.body;

    // Get booking and verify ownership
    const booking = await Booking.findById(bookingId).populate('class');
    if (!booking) {
      console.error('❌ Booking not found:', bookingId);
      return res.status(404).json({ message: 'Booking not found' });
    }

    if (booking.parent._id ? booking.parent._id.toString() !== req.user.id : booking.parent.toString() !== req.user.id) {
      console.error('❌ Unauthorized: User', req.user.id, 'does not own booking', bookingId);
      return res.status(403).json({ message: 'Not authorized to pay for this booking' });
    }

    if (booking.paymentStatus === 'paid' || booking.paymentStatus === 'held') {
      console.warn('⚠️ Booking already paid:', booking.bookingNumber, 'status:', booking.paymentStatus);
      return res.status(400).json({ message: 'Booking is already paid' });
    }

    // Get the parent's User record so we have stripeCustomerId
    const parentUser = await User.findById(req.user.id);
    if (!parentUser || !parentUser.stripeCustomerId) {
      console.error('❌ Parent has no Stripe customer ID:', req.user.id);
      return res.status(400).json({ message: 'No saved payment customer on file. Please add a card first.' });
    }

    // Create + confirm PaymentIntent in one call. Stripe will either succeed
    // immediately, require 3DS authentication, or fail.
    const amountInCents = Math.round(booking.totalAmount * 100);
    console.log('💳 create-payment-intent charging', amountInCents, 'pence - booking:', booking.bookingNumber);

    let paymentIntent;
    try {
      paymentIntent = await stripe.paymentIntents.create({
        amount: amountInCents,
        currency: 'gbp',
        customer: parentUser.stripeCustomerId,
        payment_method: paymentMethodId,
        confirm: true,
        off_session: false,
        payment_method_types: ['card'],
        metadata: {
          bookingId: booking._id.toString(),
          classId: booking.class._id.toString(),
          parentId: req.user.id,
          bookingNumber: booking.bookingNumber
        },
        description: `YUGI Booking: ${booking.class.name} - ${booking.bookingNumber}`
      });
    } catch (stripeError) {
      console.error('❌ Stripe charge failed:', stripeError.message);
      if (stripeError.payment_intent && stripeError.payment_intent.id) {
        booking.stripePaymentIntentId = stripeError.payment_intent.id;
        booking.paymentStatus = 'failed';
        await booking.save();
      }
      return res.status(400).json({
        message: stripeError.message || 'Payment failed',
        code: stripeError.code,
        decline_code: stripeError.decline_code,
        type: stripeError.type
      });
    }

    // Update booking with PI/charge info regardless of next step
    booking.stripePaymentIntentId = paymentIntent.id;
    if (paymentIntent.latest_charge) {
      booking.stripeChargeId = paymentIntent.latest_charge;
    }

    if (paymentIntent.status === 'succeeded') {
      // Card charged immediately. Funds sit on the platform in 'held' state
      // until the holding-period release cron transfers them to the provider's
      // Stripe Connect account. See T&Cs §2.2.
      booking.paymentStatus = 'held';
      booking.paymentDate = new Date();
      booking.fundsReleased = false;
      booking.status = 'confirmed';
      await booking.save();
      console.log('✅ create-payment-intent succeeded - PI:', paymentIntent.id, 'booking:', booking.bookingNumber);
      return res.json({
        success: true,
        status: 'succeeded',
        paymentIntentId: paymentIntent.id
      });
    }

    if (paymentIntent.status === 'requires_action' || paymentIntent.status === 'requires_source_action') {
      // Card needs 3D Secure / SCA. Return clientSecret so iOS can present
      // Stripe SDK's handleNextAction flow.
      await booking.save();
      console.log('🔐 create-payment-intent 3DS required - PI:', paymentIntent.id, 'booking:', booking.bookingNumber);
      return res.json({
        success: false,
        status: 'requires_action',
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id
      });
    }

    // Any other status is unexpected (requires_payment_method, processing, etc.)
    booking.paymentStatus = 'failed';
    await booking.save();
    console.error('❌ Unexpected PI status:', paymentIntent.status);
    return res.status(400).json({
      message: 'Payment could not be completed',
      status: paymentIntent.status,
      paymentIntentId: paymentIntent.id
    });

  } catch (error) {
    console.error('❌ create-payment-intent error:', error);
    console.error('Stack:', error.stack);
    res.status(500).json({
      message: 'Server error creating payment',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// @route   POST /api/payments/confirm-payment
// @desc    Confirm payment and update booking status
// @access  Private (parents and providers)
router.post('/confirm-payment', [
  protect,
  requireUserType(['parent', 'provider']),
  body('paymentIntentId').trim().isLength({ min: 1 }),
  body('bookingId').isMongoId()
], async (req, res) => {
  try {
    console.log('💳 confirm-payment', req.method, '- booking:', req.body.bookingId, 'PI:', req.body.paymentIntentId);

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('❌ confirm-payment validation failed:', errors.array());
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { paymentIntentId, bookingId } = req.body;

    // Get booking first to verify ownership
    const booking = await Booking.findById(bookingId)
      .populate('class')
      .populate('parent', 'fullName email');
    
    if (!booking) {
      console.error('❌ Booking not found:', bookingId);
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check ownership
    if (booking.parent._id.toString() !== req.user.id) {
      console.error('❌ Unauthorized: User', req.user.id, 'does not own booking', bookingId);
      return res.status(403).json({ message: 'Not authorized' });
    }

    // Retrieve payment intent from Stripe
    let paymentIntent;
    try {
      paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
      console.log('💳 confirm-payment retrieved PI:', paymentIntent.id, 'status:', paymentIntent.status);
    } catch (stripeError) {
      console.error('❌❌❌ STRIPE ERROR RETRIEVING PAYMENT INTENT ❌❌❌');
      console.error('❌ Error message:', stripeError.message);
      console.error('❌ Error type:', stripeError.type);
      return res.status(400).json({ 
        message: `Stripe error: ${stripeError.message}` 
      });
    }

    if (paymentIntent.status !== 'succeeded') {
      console.error('❌ Cannot confirm: PI not succeeded. Status:', paymentIntent.status);
      return res.status(400).json({
        message: 'Payment has not completed yet. Please complete payment before confirming.',
        status: paymentIntent.status,
        paymentIntentId: paymentIntent.id
      });
    }

    // Update booking payment status — held until the release cron transfers
    // funds to the provider's Connect account after the holding period.
    booking.paymentStatus = 'held';
    booking.stripeChargeId = paymentIntent.latest_charge;
    booking.paymentDate = new Date();
    booking.fundsReleased = false;
    booking.status = 'confirmed';
    await booking.save();

    console.log('✅ Payment confirmed successfully for booking:', booking.bookingNumber);

    // Send booking confirmation email
    try {
      // Populate class provider if not already populated
      if (!booking.class.provider || typeof booking.class.provider === 'string') {
        await booking.populate({
          path: 'class',
          populate: { path: 'provider', select: 'fullName businessName' }
        });
      }

      const parentEmail = booking.parent.email;
      const parentName = booking.parent.fullName || 'there';
      const providerName = booking.class.provider?.businessName || 
                          booking.class.provider?.fullName || 
                          'Unknown Provider';

      const bookingDetails = {
        parentName,
        bookingNumber: booking.bookingNumber,
        className: booking.class.name,
        providerName,
        sessionDate: booking.sessionDate,
        sessionTime: booking.sessionTime,
        children: booking.children,
        location: booking.class.location,
        totalAmount: booking.totalAmount,
        basePrice: booking.basePrice,
        serviceFee: booking.serviceFee
      };

      await emailService.sendBookingConfirmationEmail(parentEmail, bookingDetails);
      console.log('📧 Booking confirmation email sent to:', parentEmail);
    } catch (emailError) {
      console.error('❌ Failed to send booking confirmation email:', emailError);
      // Don't fail the request if email fails, just log it
    }

    res.json({
      success: true,
      message: 'Payment confirmed successfully',
      data: booking
    });

  } catch (error) {
    console.error('❌ Confirm payment error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      message: 'Server error confirming payment',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// @route   POST /api/payments/webhook
// @desc    Handle Stripe webhooks
// @access  Public
// Note: Raw body parsing is handled at server level for this route
router.post('/webhook', async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(event.data.object);
        break;
      
      case 'payment_intent.payment_failed':
        await handlePaymentFailure(event.data.object);
        break;
      
      case 'charge.refunded':
        await handleRefund(event.data.object);
        break;
      
      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// Handle successful payment
async function handlePaymentSuccess(paymentIntent) {
  try {
    const booking = await Booking.findOne({
      stripePaymentIntentId: paymentIntent.id
    });

    if (booking) {
      // Set payment as held until class completion + 3 working days
      const paymentDate = new Date();
      
      booking.paymentStatus = 'held';
      booking.stripeChargeId = paymentIntent.latest_charge;
      booking.status = 'confirmed';
      booking.paymentDate = paymentDate;
      booking.fundsReleased = false;
      // fundsReleaseDate will be set when class is completed
      await booking.save();

      console.log(`Payment succeeded for booking: ${booking.bookingNumber}`);
      console.log(`Funds will be held until class completion + 3 working days`);
    }
  } catch (error) {
    console.error('Error handling payment success:', error);
  }
}

// Handle failed payment
async function handlePaymentFailure(paymentIntent) {
  try {
    const booking = await Booking.findOne({
      stripePaymentIntentId: paymentIntent.id
    });

    if (booking) {
      booking.paymentStatus = 'failed';
      await booking.save();

      console.log(`Payment failed for booking: ${booking.bookingNumber}`);
    }
  } catch (error) {
    console.error('Error handling payment failure:', error);
  }
}

// Handle refund
async function handleRefund(charge) {
  try {
    const booking = await Booking.findOne({
      stripeChargeId: charge.id
    });

    if (booking) {
      booking.paymentStatus = 'refunded';
      booking.refundAmount = charge.amount_refunded / 100; // Convert from cents
      await booking.save();

      console.log(`Refund processed for booking: ${booking.bookingNumber}`);
    }
  } catch (error) {
    console.error('Error handling refund:', error);
  }
}

// Release is cron-driven (see Session 5 Phase 2b). This function is now a no-op
// kept for call-site compatibility; the actual release is owned by a polling
// job that selects bookings with paymentStatus='held' and fundsReleaseDate<=now.
// The previous in-memory setTimeout was unsafe across restarts/deploys/dyno sleep.
function scheduleFundsRelease(bookingId, releaseDate) {
  console.log(`📅 Booking ${bookingId} scheduled for release at ${releaseDate.toISOString()} (cron will pick this up)`);
}

// The real release implementation lives in services/fundsReleaseService.js and
// is driven by the funds-release cron in src/server.js. Routes here no longer
// own release; they only stamp completion + log the scheduled release date.

// Mark class as completed and schedule funds release
async function markClassAsCompleted(bookingId) {
  try {
    const booking = await Booking.findById(bookingId)
      .populate('class');
    
    if (!booking) {
      console.error(`Booking not found for class completion: ${bookingId}`);
      return;
    }
    
    if (booking.paymentStatus !== 'held') {
      console.log(`Booking ${booking.bookingNumber} is not in held status`);
      return;
    }

    // Stamp classCompletedAt + fundsReleaseDate via the shared helper so this
    // path matches PUT /api/bookings/:id/complete exactly. Also flip booking
    // status to 'completed' so the two completion concepts stay in sync.
    applyClassCompletion(booking);
    booking.status = 'completed';

    await booking.save();

    console.log(`Class completed for booking: ${booking.bookingNumber}`);
    console.log(`Funds will be released on: ${booking.fundsReleaseDate.toISOString()}`);

    // Cron will pick this up at fundsReleaseDate; no in-process timer.
    scheduleFundsRelease(booking._id, booking.fundsReleaseDate);
    
  } catch (error) {
    console.error('Error marking class as completed:', error);
  }
}

// @route   POST /api/payments/refund
// @desc    Process refund for a booking
// @access  Private
router.post('/refund', [
  protect,
  requireAdmin,
  body('bookingId').isMongoId(),
  body('amount').optional().isFloat({ min: 0 }),
  body('reason').optional().trim()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { bookingId, amount, reason } = req.body;

    const booking = await Booking.findById(bookingId)
      .populate('class');

    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Admin-gated via requireAdmin middleware — discretionary support tool for
    // dispute/goodwill refunds, so no per-user ownership check applies here.

    // Once funds have left the platform to the provider, a self-serve refund
    // is no longer possible — support handles the reversal manually.
    if (booking.fundsLeftPlatform()) {
      return res.status(409).json({
        message:
          "This booking's payment has already been released to the provider, " +
          "so it can't be cancelled with an automatic refund. Please contact " +
          "support@yugiapp.ai and we'll arrange this for you.",
      });
    }

    // Check if payment was made. 'held' bookings have been charged but not
    // yet transferred to the provider — funds are still on the platform, so
    // a normal charge refund works the same as for 'paid' (legacy) bookings.
    if (booking.paymentStatus !== 'paid' && booking.paymentStatus !== 'held') {
      return res.status(400).json({ message: 'No payment to refund' });
    }

    // Calculate refund amount
    const refundAmount = amount || booking.totalAmount;
    const refundAmountCents = Math.round(refundAmount * 100);

    // Process refund through Stripe
    const refund = await stripe.refunds.create({
      charge: booking.stripeChargeId,
      amount: refundAmountCents,
      reason: reason || 'requested_by_customer',
      metadata: {
        bookingId: booking._id.toString(),
        refundedBy: req.user.id
      }
    });

    // Update booking
    booking.paymentStatus = 'refunded';
    booking.refundAmount = refundAmount;
    await booking.save();

    res.json({
      success: true,
      message: 'Refund processed successfully',
      data: {
        refundId: refund.id,
        amount: refundAmount,
        booking: booking
      }
    });

  } catch (error) {
    console.error('Refund error:', error);
    res.status(500).json({ message: 'Server error processing refund' });
  }
});

// @route   GET /api/payments/payment-methods
// @desc    Get user's saved payment methods
// @access  Private
router.get('/payment-methods', protect, async (req, res) => {
  try {
    // In a real app, you'd store customer IDs and retrieve payment methods
    // For now, return empty array
    res.json({
      success: true,
      data: []
    });
  } catch (error) {
    console.error('Get payment methods error:', error);
    res.status(500).json({ message: 'Server error fetching payment methods' });
  }
});

// @route   GET /api/payments/held-funds
// @desc    Get held funds information for provider
// @access  Private (providers only)
router.get('/held-funds', [
  protect,
  requireUserType(['provider'])
], async (req, res) => {
  try {
    // Get all bookings for classes owned by this provider
    const bookings = await Booking.find({
      'class.provider': req.user.id,
      paymentStatus: { $in: ['held', 'paid'] }
    }).populate('class');
    
    const heldFunds = bookings.filter(booking => booking.paymentStatus === 'held');
    const releasedFunds = bookings.filter(booking => booking.paymentStatus === 'paid' && booking.fundsReleased);
    
    const totalHeld = heldFunds.reduce((sum, booking) => sum + booking.totalAmount, 0);
    const totalReleased = releasedFunds.reduce((sum, booking) => sum + booking.totalAmount, 0);
    
    // Calculate upcoming releases and class completion status
    const upcomingReleases = heldFunds.map(booking => {
      const isClassCompleted = !!booking.classCompletedAt;
      const daysUntilRelease = booking.fundsReleaseDate 
        ? Math.ceil((booking.fundsReleaseDate - new Date()) / (1000 * 60 * 60 * 24))
        : null;
      
      return {
        bookingId: booking._id,
        bookingNumber: booking.bookingNumber,
        amount: booking.totalAmount,
        className: booking.class.name,
        classCompletedAt: booking.classCompletedAt,
        fundsReleaseDate: booking.fundsReleaseDate,
        isClassCompleted,
        daysUntilRelease,
        sessionDate: booking.sessionDate,
        sessionTime: booking.sessionTime
      };
    }).sort((a, b) => {
      // Sort by: class completion status, then by release date
      if (a.isClassCompleted !== b.isClassCompleted) {
        return a.isClassCompleted ? 1 : -1; // Uncompleted classes first
      }
      if (a.fundsReleaseDate && b.fundsReleaseDate) {
        return a.fundsReleaseDate - b.fundsReleaseDate;
      }
      return 0;
    });
    
    res.json({
      success: true,
      data: {
        totalHeld,
        totalReleased,
        heldBookings: heldFunds.length,
        releasedBookings: releasedFunds.length,
        upcomingReleases
      }
    });
    
  } catch (error) {
    console.error('Get held funds error:', error);
    res.status(500).json({ message: 'Server error getting held funds' });
  }
});

// @route   POST /api/payments/mark-class-completed
// @desc    Mark a class as completed and schedule funds release
// @access  Private (providers only)
router.post('/mark-class-completed', [
  protect,
  requireUserType(['provider']),
  body('bookingId').isMongoId()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { bookingId } = req.body;

    const booking = await Booking.findById(bookingId)
      .populate('class');

    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check if provider owns this class
    if (booking.class.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to mark this class as completed' });
    }

    // Check if class is already completed
    if (booking.classCompletedAt) {
      return res.status(400).json({ message: 'Class is already marked as completed' });
    }

    // Mark class as completed
    await markClassAsCompleted(bookingId);

    res.json({
      success: true,
      message: 'Class marked as completed successfully',
      data: {
        bookingId: booking._id,
        fundsReleaseDate: booking.fundsReleaseDate
      }
    });

  } catch (error) {
    console.error('Mark class completed error:', error);
    res.status(500).json({ message: 'Server error marking class as completed' });
  }
});

module.exports = router; 