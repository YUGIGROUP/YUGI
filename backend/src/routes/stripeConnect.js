// NOTE: APP_URL must be set as a Railway environment variable
// e.g. APP_URL=https://yugi-production.up.railway.app
// Used for Stripe account link redirect URLs (refresh_url and return_url)

const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const User = require('../models/User');
const { protect, requireUserType } = require('../middleware/auth');

const router = express.Router();

// Returns the appropriate return_url and refresh_url based on the client platform.
// Stripe requires HTTPS URLs. iOS clients pass platform: 'ios' so we append
// ?platform=ios to the URLs — the /stripe/return and /stripe/refresh HTML pages
// detect this and redirect via JavaScript to yugi://stripe/return (or refresh),
// which ASWebAuthenticationSession on iOS intercepts to close the web view.
function getStripeReturnUrls(platform) {
  const suffix = platform === 'ios' ? '?platform=ios' : '';
  return {
    refresh_url: `${process.env.APP_URL}/stripe/refresh${suffix}`,
    return_url: `${process.env.APP_URL}/stripe/return${suffix}`,
  };
}

// POST /api/stripe/connect/onboard
// Starts (or resumes) Stripe Express onboarding for a provider.
// If the provider already has a connected account, skips creation and
// generates a fresh account link so they can continue where they left off.
router.post('/onboard', [protect, requireUserType(['provider'])], async (req, res) => {
  const userId = req.user._id;
  try {
    const { platform } = req.body || {};
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (!user.stripeConnectedAccountId) {
      let account;
      try {
        account = await stripe.accounts.create({
          type: 'express',
          country: 'GB',
          email: user.email,
          capabilities: {
            card_payments: { requested: true },
            transfers: { requested: true },
          },
          business_type: 'individual',
          metadata: {
            yugi_user_id: user._id.toString(),
          },
        });
      } catch (stripeErr) {
        console.error(`[stripeConnect/onboard] Account creation failed for user ${userId}:`, stripeErr.message);
        return res.status(500).json({ error: 'Stripe error', message: stripeErr.message });
      }

      user.stripeConnectedAccountId = account.id;
      user.stripeOnboardingStartedAt = new Date();
      await user.save();
    }

    const { refresh_url, return_url } = getStripeReturnUrls(platform);
    let accountLink;
    try {
      accountLink = await stripe.accountLinks.create({
        account: user.stripeConnectedAccountId,
        refresh_url,
        return_url,
        type: 'account_onboarding',
      });
    } catch (stripeErr) {
      console.error(`[stripeConnect/onboard] Account link creation failed for user ${userId}:`, stripeErr.message);
      return res.status(500).json({ error: 'Stripe error', message: stripeErr.message });
    }

    return res.json({ url: accountLink.url });
  } catch (err) {
    console.error(`[stripeConnect/onboard] Unexpected error for user ${userId}:`, err.message);
    return res.status(500).json({ error: 'Server error', message: err.message });
  }
});

// GET /api/stripe/connect/status
// Returns the provider's current Stripe Connect onboarding status.
// Syncs stripeOnboardingComplete and stripePayoutsEnabled from Stripe if they changed.
router.get('/status', [protect, requireUserType(['provider'])], async (req, res) => {
  const userId = req.user._id;
  try {
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (!user.stripeConnectedAccountId) {
      return res.json({ onboarded: false, hasAccount: false });
    }

    let account;
    try {
      account = await stripe.accounts.retrieve(user.stripeConnectedAccountId);
    } catch (stripeErr) {
      console.error(`[stripeConnect/status] Account retrieval failed for user ${userId}:`, stripeErr.message);
      return res.status(500).json({ error: 'Stripe error', message: stripeErr.message });
    }

    let changed = false;
    if (account.details_submitted && !user.stripeOnboardingComplete) {
      user.stripeOnboardingComplete = true;
      changed = true;
    }
    if (account.payouts_enabled && !user.stripePayoutsEnabled) {
      user.stripePayoutsEnabled = true;
      changed = true;
    }
    if (changed) await user.save();

    return res.json({
      hasAccount: true,
      onboardingComplete: account.details_submitted,
      chargesEnabled: account.charges_enabled,
      payoutsEnabled: account.payouts_enabled,
      requirementsCurrentlyDue: account.requirements?.currently_due || [],
    });
  } catch (err) {
    console.error(`[stripeConnect/status] Unexpected error for user ${userId}:`, err.message);
    return res.status(500).json({ error: 'Server error', message: err.message });
  }
});

// POST /api/stripe/connect/refresh-link
// Generates a fresh onboarding link for providers who abandoned the flow.
// Requires an existing stripeConnectedAccountId — call /onboard first if none exists.
router.post('/refresh-link', [protect, requireUserType(['provider'])], async (req, res) => {
  const userId = req.user._id;
  try {
    const { platform } = req.body || {};
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (!user.stripeConnectedAccountId) {
      return res.status(400).json({ message: 'No Stripe account found. Call /onboard first.' });
    }

    const { refresh_url, return_url } = getStripeReturnUrls(platform);
    let accountLink;
    try {
      accountLink = await stripe.accountLinks.create({
        account: user.stripeConnectedAccountId,
        refresh_url,
        return_url,
        type: 'account_onboarding',
      });
    } catch (stripeErr) {
      console.error(`[stripeConnect/refresh-link] Account link creation failed for user ${userId}:`, stripeErr.message);
      return res.status(500).json({ error: 'Stripe error', message: stripeErr.message });
    }

    return res.json({ url: accountLink.url });
  } catch (err) {
    console.error(`[stripeConnect/refresh-link] Unexpected error for user ${userId}:`, err.message);
    return res.status(500).json({ error: 'Server error', message: err.message });
  }
});

module.exports = router;
