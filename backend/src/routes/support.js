const express = require('express');
const router  = express.Router();
const { protect } = require('../middleware/auth');
const emailService = require('../services/emailService');

// POST /api/support
// Auth-protected: the user's name + email come from the JWT, not the request body.
router.post('/', protect, async (req, res) => {
  try {
    const { message } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ success: false, message: 'Message is required' });
    }

    const userName  = req.user.fullName || 'Unknown';
    const userEmail = req.user.email    || 'Unknown';
    const timestamp = new Date().toLocaleString('en-GB', {
      timeZone: 'Europe/London',
      dateStyle: 'full',
      timeStyle: 'short',
    });

    const to      = process.env.SUPPORT_EMAIL || 'eva@yugiapp.ai';
    const subject = `[YUGI Support] Message from ${userName}`;

    const html = `
      <div style="font-family:sans-serif;max-width:600px;margin:0 auto">
        <h2 style="color:#A3867A">New Support Message</h2>
        <table style="border-collapse:collapse;width:100%">
          <tr><td style="padding:8px;font-weight:bold;width:120px">From</td>
              <td style="padding:8px">${userName}</td></tr>
          <tr style="background:#f9f6f3">
              <td style="padding:8px;font-weight:bold">Email</td>
              <td style="padding:8px">${userEmail}</td></tr>
          <tr><td style="padding:8px;font-weight:bold">Received</td>
              <td style="padding:8px">${timestamp}</td></tr>
        </table>
        <hr style="border:none;border-top:1px solid #e0dbd7;margin:20px 0"/>
        <div style="white-space:pre-wrap;line-height:1.6">${message
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/\n/g, '<br/>')}</div>
      </div>`;

    const text = `From: ${userName} <${userEmail}>\nReceived: ${timestamp}\n\n${message}`;

    await emailService.sendEmail(to, subject, html, text);

    console.log(`📬 Support message from ${userName} (${userEmail}) forwarded to ${to}`);
    res.json({ success: true, message: 'Your message has been sent.' });
  } catch (err) {
    console.error('❌ Support route error:', err);
    res.status(500).json({ success: false, message: 'Failed to send message — please try again.' });
  }
});

module.exports = router;
