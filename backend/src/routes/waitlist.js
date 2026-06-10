// routes/waitlist.js — adds signups into Resend (contacts are global, no audience ID needed)
const express = require('express');
const rateLimit = require('express-rate-limit');
const { Resend } = require('resend');

const router = express.Router();
const resend = new Resend(process.env.RESEND_API_KEY); // already set on Railway

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

// Cap abuse: 5 submissions per IP per 10 minutes.
const waitlistLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
});

// The "you're on the list" confirmation email (warm, on-brand, no em dashes).
function welcomeEmail() {
  return `
  <div style="margin:0;padding:0;background:#FAF7F4;">
    <div style="max-width:520px;margin:0 auto;padding:40px 28px;font-family:'Helvetica Neue',Arial,sans-serif;color:#3A3836;">
      <div style="font-size:22px;font-weight:800;letter-spacing:4px;color:#3A3836;">YUGI</div>
      <h1 style="font-size:24px;margin:28px 0 14px;color:#3A3836;">You're on the list.</h1>
      <p style="font-size:16px;line-height:1.6;color:#6B6461;margin:0 0 16px;">
        Thanks for joining the YUGI waitlist. You're officially in, and you'll be one of the first to know the moment we're live in your area.
      </p>
      <p style="font-size:16px;line-height:1.6;color:#6B6461;margin:0 0 16px;">
        YUGI is built on a simple idea: this generation of mums, helping the next. We're putting the finishing touches on the app now, and we can't wait to show you what we've made.
      </p>
      <p style="font-size:16px;line-height:1.6;color:#6B6461;margin:24px 0 4px;">Talk soon,</p>
      <p style="font-size:16px;line-height:1.6;color:#3A3836;margin:0;font-weight:600;">Eva<br><span style="color:#6B6461;font-weight:400;">Founder, YUGI</span></p>
      <div style="margin-top:32px;padding-top:18px;border-top:1px solid #D4D0CC;font-size:12px;color:#6B6461;">
        YUGI Group Limited · Poole, UK · <a href="https://yugiapp.ai" style="color:#A3867A;text-decoration:none;">yugiapp.ai</a>
      </div>
    </div>
  </div>`;
}

// POST /api/waitlist
router.post('/', waitlistLimiter, async (req, res) => {
  try {
    const { email, website } = req.body || {};

    // Honeypot: bots fill hidden fields, humans don't. Silently accept and drop.
    if (website) return res.json({ ok: true });

    const clean = String(email || '').trim().toLowerCase();
    if (!EMAIL_RE.test(clean) || clean.length > 254) {
      return res.status(400).json({ ok: false, error: 'Please enter a valid email address.' });
    }

    // Add them to Resend (contacts are global now — no audience ID needed).
    // Resend upserts silently, so there's no reliable "already signed up" signal.
    // The SDK returns { data, error } rather than throwing, so check error explicitly.
    const { error: contactError } = await resend.contacts.create({ email: clean });
    if (contactError) {
      console.error('Waitlist contact create failed:', contactError);
      return res.status(502).json({ ok: false, error: 'Something went wrong. Please try again.' });
    }

    // Send the "you're on the list" email. Best-effort: a send failure shouldn't
    // fail the signup, since the contact is already saved.
    const { error: emailError } = await resend.emails.send({
      from: 'YUGI <support@yugiapp.ai>',
      to: clean,
      subject: "You're on the list 💛",
      html: welcomeEmail(),
    });
    if (emailError) {
      console.error('Waitlist confirmation email failed:', emailError);
    }

    return res.status(201).json({ ok: true });
  } catch (err) {
    console.error('Waitlist signup error:', err);
    return res.status(500).json({ ok: false, error: 'Something went wrong. Please try again.' });
  }
});

module.exports = router;
