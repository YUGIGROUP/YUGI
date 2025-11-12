const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { body, validationResult } = require('express-validator');
const Booking = require('../models/Booking');
const Class = require('../models/Class');
const { protect, requireUserType } = require('../middleware/auth');

const router = express.Router();

// Logging middleware that runs before all other middleware
router.use((req, res, next) => {
  // Log ALL requests to payment routes (check both path and originalUrl)
  const isPaymentRoute = req.path.includes('payment') || 
                         req.path.includes('create-payment') || 
                         req.path.includes('confirm-payment') ||
                         req.originalUrl.includes('/api/payments');
  
  if (isPaymentRoute) {
    console.log('🔵🔵🔵 PAYMENT ROUTE REQUEST 🔵🔵🔵');
    console.log('🔵 Method:', req.method);
    console.log('🔵 Path:', req.path);
    console.log('🔵 Full URL:', req.originalUrl);
    console.log('🔵 Headers:', JSON.stringify(req.headers, null, 2));
    console.log('🔵 Body:', JSON.stringify(req.body, null, 2));
    console.log('🔵 Query:', JSON.stringify(req.query, null, 2));
  }
  next();
});

// @route   POST /api/payments/create-payment-intent
// @desc    Create a payment intent for a booking
// @access  Private (parents and providers)
router.post('/create-payment-intent', [
  protect,
  requireUserType(['parent', 'provider']),
  body('bookingId').isMongoId()
], async (req, res) => {
  console.log('🔵🔵🔵 CREATE PAYMENT INTENT ROUTE HANDLER EXECUTED 🔵🔵🔵');
  console.log('🔵 CREATE PAYMENT INTENT ROUTE HIT');
  console.log('🔵 Request body:', JSON.stringify(req.body, null, 2));
  console.log('🔵 User:', req.user ? { id: req.user.id, type: req.user.userType } : 'NO USER');
  
  try {
    console.log('💳 Create payment intent request received:', {
      bookingId: req.body.bookingId,
      userId: req.user.id
    });

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('❌ Validation errors:', errors.array());
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { bookingId } = req.body;

    // Get booking
    console.log('💳 Fetching booking:', bookingId);
    const booking = await Booking.findById(bookingId)
      .populate('class');

    if (!booking) {
      console.error('❌ Booking not found:', bookingId);
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check ownership
    if (booking.parent.toString() !== req.user.id) {
      console.error('❌ Unauthorized: User', req.user.id, 'does not own booking', bookingId);
      return res.status(403).json({ message: 'Not authorized to pay for this booking' });
    }

    // Check if already paid
    if (booking.paymentStatus === 'paid') {
      console.warn('⚠️ Booking already paid:', booking.bookingNumber);
      return res.status(400).json({ message: 'Booking is already paid' });
    }

    // Create payment intent
    const amountInCents = Math.round(booking.totalAmount * 100);
    console.log('💳 Creating Stripe payment intent:', {
      amount: amountInCents,
      currency: 'gbp',
      bookingNumber: booking.bookingNumber
    });

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInCents,
      currency: 'gbp',
      metadata: {
        bookingId: booking._id.toString(),
        classId: booking.class._id.toString(),
        parentId: req.user.id
      },
      description: `YUGI Booking: ${booking.class.name} - ${booking.bookingNumber}`
    });

    console.log('✅ Payment intent created:', {
      id: paymentIntent.id,
      status: paymentIntent.status,
      amount: paymentIntent.amount
    });

    // Update booking with payment intent ID
    booking.stripePaymentIntentId = paymentIntent.id;
    await booking.save();

    res.json({
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id
    });

  } catch (error) {
    console.error('❌ Create payment intent error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      message: 'Server error creating payment intent',
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
  console.log('🔵🔵🔵 CONFIRM PAYMENT ROUTE HANDLER EXECUTED 🔵🔵🔵');
  console.log('🔵🔵🔵 CONFIRM PAYMENT ROUTE HIT 🔵🔵🔵');
  console.log('🔵 Request body:', JSON.stringify(req.body, null, 2));
  console.log('🔵 User:', req.user ? { id: req.user.id, type: req.user.userType } : 'NO USER');
  console.log('🔵 Headers:', JSON.stringify(req.headers, null, 2));
  
  try {
    console.log('💳 Confirm payment request received:', {
      paymentIntentId: req.body.paymentIntentId,
      bookingId: req.body.bookingId,
      userId: req.user.id
    });

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('❌❌❌ VALIDATION ERRORS ❌❌❌');
      console.error('❌ Validation errors:', JSON.stringify(errors.array(), null, 2));
      console.error('❌ Request body was:', JSON.stringify(req.body, null, 2));
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { paymentIntentId, bookingId } = req.body;

    // Get booking first to verify ownership
    const booking = await Booking.findById(bookingId)
      .populate('class');
    
    if (!booking) {
      console.error('❌ Booking not found:', bookingId);
      return res.status(404).json({ message: 'Booking not found' });
    }

    // Check ownership
    if (booking.parent.toString() !== req.user.id) {
      console.error('❌ Unauthorized: User', req.user.id, 'does not own booking', bookingId);
      return res.status(403).json({ message: 'Not authorized' });
    }

    // Retrieve payment intent from Stripe
    console.log('💳💳💳 RETRIEVING PAYMENT INTENT FROM STRIPE 💳💳💳');
    console.log('💳 Payment intent ID:', paymentIntentId);
    let paymentIntent;
    try {
      paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
      console.log('💳 Payment intent retrieved successfully');
      console.log('💳 Payment intent status:', paymentIntent.status);
      console.log('💳 Payment intent amount:', paymentIntent.amount);
      console.log('💳 Payment intent currency:', paymentIntent.currency);
    } catch (stripeError) {
      console.error('❌❌❌ STRIPE ERROR RETRIEVING PAYMENT INTENT ❌❌❌');
      console.error('❌ Error:', JSON.stringify(stripeError, null, 2));
      console.error('❌ Error message:', stripeError.message);
      console.error('❌ Error type:', stripeError.type);
      return res.status(400).json({ 
        message: `Stripe error: ${stripeError.message}` 
      });
    }

    // If payment intent is not succeeded, confirm it with a test payment method
    if (paymentIntent.status !== 'succeeded') {
      console.log('💳 Payment intent not succeeded, confirming with test card...');
      console.log('💳 Current payment intent status:', paymentIntent.status);
      
      try {
        // Check if we're in test mode (test keys start with sk_test_)
        const stripeKey = process.env.STRIPE_SECRET_KEY;
        const isTestMode = stripeKey && stripeKey.startsWith('sk_test_');
        console.log('💳 Stripe mode:', isTestMode ? 'TEST' : 'LIVE');
        console.log('💳 Stripe key prefix:', stripeKey ? stripeKey.substring(0, 12) + '...' : 'NOT SET');
        console.log('💳 Stripe key length:', stripeKey ? stripeKey.length : 0);
        
        if (!isTestMode) {
          console.warn('⚠️ Using LIVE Stripe keys - cannot use test card numbers');
          return res.status(400).json({ 
            message: 'Cannot confirm payment with test card in live mode. Please use Stripe test keys for testing.' 
          });
        }
        
        // First, create a payment method with test card
        console.log('💳 Creating payment method with test card...');
        const paymentMethod = await stripe.paymentMethods.create({
          type: 'card',
          card: {
            number: '4242424242424242',
            exp_month: 12,
            exp_year: new Date().getFullYear() + 1,
            cvc: '123'
          }
        });
        
        console.log('✅ Payment method created:', paymentMethod.id);
        
        // Attach the payment method to the payment intent and confirm
        console.log('💳 Confirming payment intent with payment method...');
        paymentIntent = await stripe.paymentIntents.confirm(paymentIntentId, {
          payment_method: paymentMethod.id
        });
        
        console.log('💳 Payment intent confirmed, new status:', paymentIntent.status);
        if (paymentIntent.last_payment_error) {
          console.error('❌ Payment error:', paymentIntent.last_payment_error);
        }
        
        if (paymentIntent.status !== 'succeeded') {
          console.error('❌ Payment intent confirmation failed. Status:', paymentIntent.status);
          console.error('❌ Payment intent details:', {
            status: paymentIntent.status,
            last_payment_error: paymentIntent.last_payment_error,
            next_action: paymentIntent.next_action,
            charges: paymentIntent.charges?.data
          });
          const errorMessage = paymentIntent.last_payment_error 
            ? paymentIntent.last_payment_error.message 
            : `Payment not completed. Status: ${paymentIntent.status}`;
          console.error('❌❌❌ RETURNING 400 ERROR ❌❌❌');
          console.error('❌ Error message:', errorMessage);
          console.error('❌ Payment intent status:', paymentIntent.status);
          console.error('❌ Last payment error:', JSON.stringify(paymentIntent.last_payment_error, null, 2));
          return res.status(400).json({ 
            message: errorMessage,
            status: paymentIntent.status,
            error: paymentIntent.last_payment_error,
            paymentIntentId: paymentIntentId
          });
        }
      } catch (confirmError) {
        console.error('❌ Error confirming payment intent:', confirmError);
        console.error('❌ Error details:', {
          message: confirmError.message,
          type: confirmError.type,
          code: confirmError.code,
          decline_code: confirmError.decline_code,
          stack: confirmError.stack
        });
        return res.status(400).json({ 
          message: `Payment confirmation failed: ${confirmError.message}` 
        });
      }
    }

    // Update booking payment status
    booking.paymentStatus = 'paid';
    booking.stripeChargeId = paymentIntent.latest_charge;
    booking.status = 'confirmed';
    await booking.save();

    console.log('✅ Payment confirmed successfully for booking:', booking.bookingNumber);

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
router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
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

// Schedule funds release after 3 days
function scheduleFundsRelease(bookingId, releaseDate) {
  const delay = releaseDate.getTime() - Date.now();
  
  if (delay > 0) {
    setTimeout(async () => {
      await releaseFundsToProvider(bookingId);
    }, delay);
  } else {
    // If release date has already passed, release immediately
    releaseFundsToProvider(bookingId);
  }
}

// Release funds to provider after 3-day holding period
async function releaseFundsToProvider(bookingId) {
  try {
    const booking = await Booking.findById(bookingId)
      .populate('class')
      .populate('class.provider');
    
    if (!booking) {
      console.error(`Booking not found for funds release: ${bookingId}`);
      return;
    }
    
    if (booking.fundsReleased) {
      console.log(`Funds already released for booking: ${booking.bookingNumber}`);
      return;
    }
    
    // Update booking to mark funds as released
    booking.fundsReleased = true;
    booking.fundsReleasedAt = new Date();
    booking.paymentStatus = 'paid'; // Change from 'held' to 'paid'
    await booking.save();
    
    console.log(`Funds released to provider for booking: ${booking.bookingNumber}`);
    console.log(`Provider: ${booking.class.provider.businessName || booking.class.provider.fullName}`);
    console.log(`Amount: £${booking.totalAmount}`);
    
    // Here you would typically:
    // 1. Transfer funds to provider's Stripe account
    // 2. Send notification to provider
    // 3. Update provider's earnings dashboard
    
    // For now, we'll just log the transfer
    console.log(`Transferring £${booking.totalAmount} to provider's account...`);
    
  } catch (error) {
    console.error('Error releasing funds to provider:', error);
  }
}

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
    
    // Mark class as completed
    const classCompletedAt = new Date();
    booking.classCompletedAt = classCompletedAt;
    
    // Calculate funds release date (3 working days after class completion)
    const fundsReleaseDate = calculateWorkingDaysAfter(classCompletedAt, 3);
    booking.fundsReleaseDate = fundsReleaseDate;
    
    await booking.save();
    
    console.log(`Class completed for booking: ${booking.bookingNumber}`);
    console.log(`Funds will be released on: ${fundsReleaseDate.toISOString()}`);
    
    // Schedule the funds release
    scheduleFundsRelease(booking._id, fundsReleaseDate);
    
  } catch (error) {
    console.error('Error marking class as completed:', error);
  }
}

// Calculate working days after a given date
function calculateWorkingDaysAfter(startDate, workingDays) {
  let currentDate = new Date(startDate);
  let daysAdded = 0;
  
  while (daysAdded < workingDays) {
    currentDate.setDate(currentDate.getDate() + 1);
    const dayOfWeek = currentDate.getDay();
    
    // Skip weekends (0 = Sunday, 6 = Saturday)
    if (dayOfWeek !== 0 && dayOfWeek !== 6) {
      daysAdded++;
    }
  }
  
  return currentDate;
}

// @route   POST /api/payments/refund
// @desc    Process refund for a booking
// @access  Private
router.post('/refund', [
  protect,
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

    // Check authorization
    const isOwner = booking.parent.toString() === req.user.id;
    const isProvider = req.user.userType === 'provider' && 
                      booking.class.provider.toString() === req.user.id;

    if (!isOwner && !isProvider) {
      return res.status(403).json({ message: 'Not authorized to process refund' });
    }

    // Check if payment was made
    if (booking.paymentStatus !== 'paid') {
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