const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const User = require('../models/User');
const { protect } = require('../middleware/auth');

const router = express.Router();

// Helper: ensures the parent has a Stripe Customer record.
// Creates one if missing, stores the ID on the User document, and returns it.
async function getOrCreateStripeCustomer(user) {
  if (user.stripeCustomerId) {
    return user.stripeCustomerId;
  }

  const customer = await stripe.customers.create({
    email: user.email,
    name: user.fullName || user.email,
    metadata: {
      yugi_user_id: user._id.toString(),
    },
  });

  user.stripeCustomerId = customer.id;
  await user.save();
  return customer.id;
}

// POST /api/parent-payments/setup-intent
// Creates a Stripe SetupIntent so the parent can save a card via Stripe's
// iOS PaymentSheet. The card is collected and tokenized entirely by Stripe;
// YUGI's backend only receives the saved payment method's ID afterwards
// (via the next call to GET /payment-methods).
router.post('/setup-intent', [protect], async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const customerId = await getOrCreateStripeCustomer(user);

    const setupIntent = await stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ['card'],
      usage: 'off_session',
    });

    res.json({
      clientSecret: setupIntent.client_secret,
      customerId,
    });
  } catch (error) {
    console.error('[stripePayments/setup-intent] failed:', error.message);
    res.status(500).json({ message: 'Failed to create setup intent', error: error.message });
  }
});

// GET /api/parent-payments/payment-methods
// Lists the parent's saved cards on Stripe. Returns only display data
// (brand, last4, expiry) plus each payment method's Stripe ID. No card
// numbers, CVVs, or any sensitive data ever pass through this endpoint —
// Stripe holds all of that.
router.get('/payment-methods', [protect], async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (!user.stripeCustomerId) {
      return res.json({ paymentMethods: [] });
    }

    const result = await stripe.paymentMethods.list({
      customer: user.stripeCustomerId,
      type: 'card',
    });

    const paymentMethods = result.data.map((pm) => ({
      id: pm.id,
      brand: pm.card.brand,
      last4: pm.card.last4,
      expMonth: pm.card.exp_month,
      expYear: pm.card.exp_year,
    }));

    res.json({ paymentMethods });
  } catch (error) {
    console.error('[stripePayments/payment-methods] failed:', error.message);
    res.status(500).json({ message: 'Failed to fetch payment methods', error: error.message });
  }
});

// DELETE /api/parent-payments/payment-methods/:id
// Detaches a payment method from the parent's Stripe customer.
// Verifies ownership before detaching to prevent one user removing
// another user's card.
router.delete('/payment-methods/:id', [protect], async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (!user.stripeCustomerId) {
      return res.status(404).json({ message: 'No Stripe customer on file' });
    }

    const paymentMethodId = req.params.id;

    // Verify the payment method belongs to this user's Stripe customer
    const paymentMethod = await stripe.paymentMethods.retrieve(paymentMethodId);
    if (paymentMethod.customer !== user.stripeCustomerId) {
      return res.status(403).json({ message: 'Not authorised to remove this payment method' });
    }

    await stripe.paymentMethods.detach(paymentMethodId);

    res.json({ success: true, id: paymentMethodId });
  } catch (error) {
    console.error('[stripePayments/payment-methods/delete] failed:', error.message);
    res.status(500).json({ message: 'Failed to detach payment method', error: error.message });
  }
});

module.exports = router;
