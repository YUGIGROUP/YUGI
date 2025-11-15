# 📧 SendGrid Setup Guide for YUGI

This guide will help you set up SendGrid to send booking confirmation emails.

## ✅ Why SendGrid?

- **Free Tier**: 100 emails/day forever (perfect for testing and small scale)
- **Easy Setup**: Simple API key setup
- **Great Documentation**: Excellent developer resources
- **Reliable**: Enterprise-grade email delivery
- **No Credit Card Required**: For free tier

---

## 🚀 Step-by-Step Setup

### Step 1: Create SendGrid Account

1. Go to [SendGrid Sign Up](https://signup.sendgrid.com/)
2. Fill out the form:
   - **Email**: Your email address
   - **Password**: Create a secure password
   - **Company**: YUGI (or your company name)
3. Click **"Create Account"**
4. Verify your email address (check your inbox)

---

### Step 2: Verify Your Sender Identity

**Option A: Single Sender Verification (Quick for Testing)**
1. In SendGrid Dashboard, go to **"Settings"** → **"Sender Authentication"**
2. Click **"Verify a Single Sender"**
3. Fill out the form:
   - **From Email Address**: `info@yugiapp.ai` (or your email)
   - **From Name**: `YUGI`
   - **Reply To**: Same as from email
   - **Company Address**: Your business address
4. Click **"Create"**
5. Check your email and click the verification link

**Option B: Domain Authentication (Recommended for Production)**
1. Go to **"Settings"** → **"Sender Authentication"**
2. Click **"Authenticate Your Domain"**
3. Select your DNS provider
4. Follow the instructions to add DNS records (CNAME records)
5. Wait for verification (usually a few minutes)

⚠️ **Important**: You can only send FROM verified email addresses/domains.

---

### Step 3: Create API Key

1. In SendGrid Dashboard, go to **"Settings"** → **"API Keys"**
2. Click **"Create API Key"**
3. Name it: `YUGI Production` (or similar)
4. Select **"Full Access"** (or "Restricted Access" with Mail Send permissions)
5. Click **"Create & View"**
6. **IMPORTANT**: Copy the API key immediately - you won't be able to see it again!
   - It will look like: `SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

---

### Step 4: Add Environment Variables to Railway

Go to your Railway project → **Variables** tab and add:

```bash
EMAIL_PROVIDER=sendgrid
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FROM_EMAIL=info@yugiapp.ai
```

**Important Notes:**
- Replace the `SENDGRID_API_KEY` with your actual API key from Step 3
- Replace `info@yugiapp.ai` with your verified sender email from Step 2

---

### Step 5: Test the Setup

1. Make a test booking in your app
2. Check Railway logs for:
   ```
   ✅ SendGrid email sent successfully. Status: 202
   ```
3. Check the recipient's inbox (and spam folder)

---

## 🔍 Troubleshooting

### "The from address does not match a verified Sender Identity"
- **Cause**: You're trying to send FROM an unverified email
- **Fix**: Verify the sender email/domain in SendGrid (Step 2)

### "Invalid API key"
- **Cause**: Wrong API key or key was deleted
- **Fix**: Create a new API key in SendGrid and update Railway variable

### "Forbidden" (403 error)
- **Cause**: API key doesn't have proper permissions
- **Fix**: Make sure API key has "Mail Send" permissions

### Emails going to spam
- **Cause**: Domain reputation or SPF/DKIM not set up
- **Fix**: 
  1. Use Domain Authentication instead of Single Sender (Step 2, Option B)
  2. Wait for domain reputation to build
  3. SendGrid provides SPF/DKIM records automatically with domain auth

### "Rate limit exceeded"
- **Cause**: Exceeded 100 emails/day free tier limit
- **Fix**: 
  - Wait until next day, OR
  - Upgrade to a paid plan

---

## 📊 Monitoring

**Check email sending stats:**
1. Go to SendGrid Dashboard
2. Click **"Activity"** in the left sidebar
3. View:
   - Emails sent
   - Delivered
   - Opened
   - Clicked
   - Bounced
   - Spam reports

**Set up email alerts:**
- Go to **"Settings"** → **"Mail Settings"** → **"Event Webhook"**
- Set up webhooks to get notifications about bounces/complaints

---

## 💰 Cost Estimate

**Free Tier:**
- 100 emails/day FREE forever
- Perfect for testing and small production use

**Paid Plans (if you need more):**
- Essentials: $19.95/month for 50,000 emails
- Pro: $89.95/month for 100,000 emails
- Very affordable scaling!

---

## ✅ Quick Checklist

- [ ] Created SendGrid account
- [ ] Verified sender email/domain
- [ ] Created API key
- [ ] Copied API key (saved securely)
- [ ] Added environment variables to Railway:
  - [ ] `EMAIL_PROVIDER=sendgrid`
  - [ ] `SENDGRID_API_KEY=your_key`
  - [ ] `FROM_EMAIL=your_verified_email`
- [ ] Tested with a booking
- [ ] Checked Railway logs for success message

---

## 🎉 You're Done!

Once set up, booking confirmation emails will be sent automatically whenever a payment is confirmed. No code changes needed - just the environment variables!

---

## 📞 Need Help?

If you run into issues:
1. Check Railway logs for error messages
2. Verify all environment variables are set correctly
3. Check SendGrid Dashboard → Activity for delivery status
4. Review SendGrid documentation: https://docs.sendgrid.com/

---

## 🔄 Switching from AWS SES?

If you were using AWS SES before:
1. Remove these Railway variables:
   - `AWS_REGION`
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
2. Add SendGrid variables (see Step 4)
3. Change `EMAIL_PROVIDER` from `ses` to `sendgrid`
4. Redeploy (or Railway will auto-deploy)

That's it! The code automatically uses SendGrid when `EMAIL_PROVIDER=sendgrid`.

