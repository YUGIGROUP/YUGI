const apn = require('apn');

let provider = null;

function getProvider() {
  if (provider) return provider;

  const { APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_PATH } = process.env;
  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_KEY_PATH) {
    return null;
  }

  provider = new apn.Provider({
    token: {
      key:    APNS_KEY_PATH,
      keyId:  APNS_KEY_ID,
      teamId: APNS_TEAM_ID,
    },
    production: process.env.NODE_ENV === 'production',
  });

  return provider;
}

/**
 * Send a post-visit feedback push notification via APNs.
 * @param {object} opts
 * @param {string} opts.deviceToken
 * @param {string} opts.bookingId   - MongoDB ObjectId string
 * @param {string} opts.className
 * @returns {Promise<{ success: boolean, reason?: string }>}
 */
async function sendPostVisitFeedbackNotification({ deviceToken, bookingId, className }) {
  const p = getProvider();
  if (!p) {
    console.warn('⚠️  APNs not configured — skipping push notification');
    return { success: false, reason: 'not_configured' };
  }

  const notification = new apn.Notification();
  notification.expiry  = Math.floor(Date.now() / 1000) + 24 * 3600; // 24-hour TTL
  notification.badge   = 1;
  notification.sound   = 'default';
  notification.alert   = {
    title: 'How was your class?',
    body:  `Tap to share your experience at ${className}`,
  };
  notification.payload = {
    bookingId,
    type: 'post_visit_feedback',
  };
  notification.topic = process.env.APNS_BUNDLE_ID || 'uk.yugi.YUGI';

  try {
    const result = await p.send(notification, deviceToken);
    if (result.failed && result.failed.length > 0) {
      const failure = result.failed[0];
      const reason  = failure.response?.reason || failure.error?.message || 'unknown';
      console.error(`APNs send failed for booking ${bookingId}:`, reason);
      return { success: false, reason };
    }
    return { success: true };
  } catch (err) {
    console.error('APNs provider error:', err.message);
    return { success: false, reason: err.message };
  }
}

module.exports = { sendPostVisitFeedbackNotification };
