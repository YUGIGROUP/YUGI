# 📧 AWS SES Setup Guide for YUGI

This guide will help you set up AWS SES (Simple Email Service) to send booking confirmation emails.

## ✅ Why AWS SES?

- **Free Tier**: 62,000 emails/month for the first year (then ~$0.10 per 1,000 emails)
- **Reliable**: Enterprise-grade email delivery
- **Already have AWS**: No need for another account
- **Scalable**: Handles high volume easily

---

## 🚀 Step-by-Step Setup

### Step 1: Verify Your Email Domain (or Single Email)

**Option A: Verify Your Domain (Recommended for Production)**
1. Go to [AWS SES Console](https://console.aws.amazon.com/ses/)
2. Click **"Verified identities"** in the left sidebar
3. Click **"Create identity"**
4. Select **"Domain"**
5. Enter your domain (e.g., `yugiapp.ai`)
6. Follow DNS verification steps (add TXT/CNAME records to your domain)

**Option B: Verify Single Email (Quick for Testing)**
1. Go to [AWS SES Console](https://console.aws.amazon.com/ses/)
2. Click **"Verified identities"** → **"Create identity"**
3. Select **"Email address"**
4. Enter the email you want to send FROM (e.g., `info@yugiapp.ai`)
5. Check your email and click the verification link

⚠️ **Important**: AWS SES starts in "Sandbox Mode" - you can only send to verified emails. To send to any email, you need to request production access (usually approved within 24 hours).

---

### Step 2: Request Production Access (Optional but Recommended)

If you want to send emails to any recipient (not just verified ones):

1. In AWS SES Console, click **"Account dashboard"**
2. Click **"Request production access"**
3. Fill out the form:
   - **Mail Type**: Transactional
   - **Website URL**: Your app URL
   - **Use Case**: Booking confirmations for a children's class booking platform
   - **Expected Volume**: Estimate your monthly emails
4. Submit and wait for approval (usually 24-48 hours)

---

### Step 3: Create IAM User for SES

1. Go to [IAM Console](https://console.aws.amazon.com/iam/)
2. Click **"Users"** → **"Create user"**
3. Name: `yugi-ses-user` (or similar)
4. Click **"Next"**
5. Under **"Set permissions"**, click **"Attach policies directly"**
6. Search for `AmazonSESFullAccess` and select it
7. Click **"Next"** → **"Create user"**
8. Click on the new user → **"Security credentials"** tab
9. Click **"Create access key"**
10. Select **"Application running outside AWS"**
11. Click **"Next"** → **"Create access key"**
12. **IMPORTANT**: Copy both:
    - **Access key ID** (e.g., `AKIAIOSFODNN7EXAMPLE`)
    - **Secret access key** (e.g., `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)
    - ⚠️ You won't be able to see the secret key again!

---

### Step 4: Choose Your AWS Region

AWS SES is region-specific. Choose a region close to your users:

**Recommended Regions:**
- `us-east-1` (N. Virginia) - Most common, best support
- `eu-west-1` (Ireland) - Good for UK/Europe users
- `eu-west-2` (London) - Best for UK users

**To find your region:**
1. Go to AWS SES Console
2. Look at the top-right corner
3. Note the region (e.g., "EU (Ireland) eu-west-1")

---

### Step 5: Add Environment Variables to Railway

Go to your Railway project → **Variables** tab and add:

```bash
EMAIL_PROVIDER=ses
AWS_REGION=eu-west-1                    # Your chosen region
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE   # From Step 3
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI...   # From Step 3
FROM_EMAIL=info@yugiapp.ai               # Your verified email/domain
```

**Important Notes:**
- Replace `eu-west-1` with your actual region
- Replace the AWS keys with your actual keys from Step 3
- Replace `info@yugiapp.ai` with your verified email address

---

### Step 6: Test the Setup

1. Make a test booking in your app
2. Check Railway logs for:
   ```
   ✅ AWS SES email sent successfully. MessageId: 010001...
   ```
3. Check the recipient's inbox (and spam folder)

---

## 🔍 Troubleshooting

### "Email address is not verified"
- **Cause**: You're trying to send FROM an unverified email
- **Fix**: Verify the email in AWS SES Console (Step 1)

### "Email address is not verified" (for recipient)
- **Cause**: You're in Sandbox Mode and trying to send to an unverified email
- **Fix**: Either verify the recipient email OR request production access (Step 2)

### "Access Denied"
- **Cause**: IAM user doesn't have SES permissions
- **Fix**: Make sure the IAM user has `AmazonSESFullAccess` policy attached

### "Invalid region"
- **Cause**: Wrong AWS_REGION value
- **Fix**: Check your SES region in AWS Console and update Railway variable

### Emails going to spam
- **Cause**: Domain reputation or SPF/DKIM not set up
- **Fix**: 
  1. Set up SPF/DKIM records (AWS provides these when you verify domain)
  2. Use a verified domain (not just email)
  3. Wait for domain reputation to build

---

## 📊 Monitoring

**Check email sending stats:**
1. Go to AWS SES Console
2. Click **"Sending statistics"**
3. View:
   - Emails sent
   - Bounce rate
   - Complaint rate
   - Delivery rate

**Set up CloudWatch alarms:**
- Monitor bounce/complaint rates
- Get alerts if issues occur

---

## 💰 Cost Estimate

**Free Tier (First Year):**
- 62,000 emails/month FREE
- Perfect for testing and early production

**After Free Tier:**
- $0.10 per 1,000 emails
- Example: 10,000 emails/month = $1/month
- Very affordable!

---

## ✅ Quick Checklist

- [ ] Verified email/domain in AWS SES
- [ ] Created IAM user with SES permissions
- [ ] Copied Access Key ID and Secret Access Key
- [ ] Chosen AWS region
- [ ] Added all environment variables to Railway
- [ ] Tested with a booking
- [ ] (Optional) Requested production access

---

## 🎉 You're Done!

Once set up, booking confirmation emails will be sent automatically whenever a payment is confirmed. No code changes needed - just the environment variables!

---

## 📞 Need Help?

If you run into issues:
1. Check Railway logs for error messages
2. Verify all environment variables are set correctly
3. Check AWS SES Console for verification status
4. Review AWS SES documentation: https://docs.aws.amazon.com/ses/

