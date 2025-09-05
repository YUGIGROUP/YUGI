# 🚀 YUGI Backend Setup Guide - Free Tier Edition

## 📋 Overview
This guide will help you set up all the free tier accounts needed to build the YUGI backend. We'll start with $0/month and scale up as you grow!

## 🎯 What We're Setting Up
1. **AWS Account** - Cloud infrastructure
2. **MongoDB Atlas** - Database
3. **Firebase Project** - Authentication
4. **Stripe Account** - Payment processing
5. **GitHub Account** - Code repository (if needed)

---

## 🔥 Step 1: AWS Account Setup

### 1.1 Create AWS Account
1. Go to [aws.amazon.com](https://aws.amazon.com)
2. Click **"Create an AWS Account"**
3. Enter your email address
4. Choose **"Personal Account"** (free tier eligible)

### 1.2 Account Details
- **Account name**: `YUGI-Development`
- **Email**: Your business email
- **Password**: Strong password (save it!)

### 1.3 Contact Information
- **Full name**: Your name
- **Phone number**: Your mobile
- **Country**: Your country
- **Address**: Your business address

### 1.4 Payment Information
- **Credit card**: Required (won't be charged during free tier)
- **Billing address**: Same as above

### 1.5 Identity Verification
- **Phone verification**: Enter code sent to your phone
- **Support plan**: Choose **"Free"** plan

### 1.6 Free Tier Activation
- AWS will automatically activate your free tier
- You'll get 12 months of free services
- Set up billing alerts to avoid charges

### 1.7 Important: Set Up Billing Alerts
1. Go to **AWS Billing Dashboard**
2. Click **"Billing Preferences"**
3. Set up **"Billing Alerts"**:
   - Alert 1: $5
   - Alert 2: $10
   - Alert 3: $25

---

## 🗄️ Step 2: MongoDB Atlas Setup

### 2.1 Create MongoDB Atlas Account
1. Go to [mongodb.com/cloud/atlas](https://mongodb.com/cloud/atlas)
2. Click **"Try Free"**
3. Choose **"Create a cluster"**

### 2.2 Choose Cloud Provider
- **Cloud Provider**: AWS
- **Region**: Choose closest to your users (e.g., US East for US users)
- **Cluster Tier**: **FREE** (M0 Sandbox)

### 2.3 Security Settings
- **Username**: `yugi-admin`
- **Password**: Strong password (save it!)
- **Database Access**: **"Read and write to any database"**

### 2.4 Network Access
- **IP Address**: **"Allow access from anywhere"** (0.0.0.0/0)
- **Note**: We'll restrict this later for security

### 2.5 Cluster Setup
- **Cluster Name**: `yugi-cluster`
- Click **"Create Cluster"**
- Wait 5-10 minutes for setup

### 2.6 Get Connection String
1. Click **"Connect"** on your cluster
2. Choose **"Connect your application"**
3. Copy the connection string
4. Save it securely - you'll need it for your app

---

## 🔐 Step 3: Firebase Project Setup

### 3.1 Create Firebase Project
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **"Create a project"**
3. **Project name**: `yugi-app`
4. **Project ID**: `yugi-app-[random]` (auto-generated)
5. Click **"Continue"**

### 3.2 Google Analytics (Optional)
- **Enable Google Analytics**: Yes
- **Analytics account**: Create new account
- Click **"Create project"**

### 3.3 Add iOS App
1. Click **"Add app"** → iOS icon
2. **iOS bundle ID**: `com.yourcompany.yugi`
3. **App nickname**: `YUGI iOS`
4. **App Store ID**: Leave blank for now
5. Click **"Register app"**

### 3.4 Download Config File
1. Download `GoogleService-Info.plist`
2. Add it to your Xcode project
3. Click **"Next"** → **"Continue to console"**

### 3.5 Enable Authentication
1. Go to **"Authentication"** in sidebar
2. Click **"Get started"**
3. Choose **"Email/Password"**
4. Enable **"Email/Password"**
5. Click **"Save"**

### 3.6 Get API Keys
1. Go to **"Project settings"** (gear icon)
2. Scroll to **"Your apps"**
3. Copy the **API Key** and **Project ID**
4. Save these securely

---

## 💳 Step 4: Stripe Account Setup

### 4.1 Create Stripe Account
1. Go to [stripe.com](https://stripe.com)
2. Click **"Start now"**
3. Enter your email address
4. Choose **"Business"** account

### 4.2 Business Information
- **Business type**: Individual or Company
- **Business name**: Your business name
- **Website**: Your website (or placeholder)
- **Business description**: "Children's activity booking platform"

### 4.3 Personal Information
- **Full name**: Your name
- **Date of birth**: Your DOB
- **Phone number**: Your mobile
- **Address**: Your business address

### 4.4 Bank Account
- **Bank account**: Your business bank account
- **Routing number**: Your bank's routing number
- **Account number**: Your account number

### 4.5 Verification
- **Identity verification**: Upload ID or passport
- **Business verification**: Upload business documents
- Wait for approval (usually 1-2 business days)

### 4.6 Get API Keys
1. Go to **"Developers"** → **"API keys"**
2. Copy your **Publishable key** and **Secret key**
3. Save these securely
4. **Important**: Keep secret key private!

---

## 📱 Step 5: GitHub Account (Optional)

### 5.1 Create GitHub Account
1. Go to [github.com](https://github.com)
2. Click **"Sign up"**
3. Enter your email and password
4. Choose **"Free"** plan

### 5.2 Create Repository
1. Click **"New repository"**
2. **Repository name**: `yugi-backend`
3. **Description**: "YUGI app backend API"
4. Choose **"Private"**
5. Click **"Create repository"**

---

## 🔧 Step 6: Environment Setup

### 6.1 Create Environment File
Create a file called `.env` in your backend project:

```bash
# AWS Configuration
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1

# MongoDB Configuration
MONGODB_URI=your_mongodb_connection_string

# Firebase Configuration
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_PROJECT_ID=your_firebase_project_id

# Stripe Configuration
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_SECRET_KEY=your_stripe_secret_key

# JWT Secret
JWT_SECRET=your_jwt_secret_key
```

### 6.2 Security Notes
- **Never commit** `.env` file to version control
- Add `.env` to your `.gitignore` file
- Use strong, unique passwords for each service
- Enable 2FA on all accounts

---

## 📊 Step 7: Free Tier Limits & Monitoring

### 7.1 AWS Free Tier Limits
- **EC2**: 750 hours/month (1 instance)
- **S3**: 5GB storage, 20K GET requests
- **Lambda**: 1M requests/month
- **API Gateway**: 1M API calls/month
- **CloudWatch**: Basic monitoring free

### 7.2 MongoDB Atlas Free Tier
- **Storage**: 512MB
- **RAM**: Shared (up to 512MB)
- **Connections**: Up to 500

### 7.3 Firebase Free Tier
- **Authentication**: 10K users/month
- **Firestore**: 1GB storage, 50K reads/day
- **Hosting**: 10GB storage, 360MB/day

### 7.4 Stripe Free Tier
- **No monthly fees**
- **Transaction fees**: 2.9% + 30¢ per transaction
- **Test mode**: Unlimited free testing

---

## 🚨 Important Security Steps

### 8.1 Enable 2FA
- **AWS**: Enable MFA for root account
- **MongoDB**: Enable 2FA in account settings
- **Firebase**: Enable 2FA in Google account
- **Stripe**: Enable 2FA in account settings

### 8.2 Set Up Alerts
- **AWS Billing Alerts**: $5, $10, $25
- **MongoDB**: Monitor storage usage
- **Firebase**: Monitor usage in console

### 8.3 Backup Strategy
- **Database**: MongoDB Atlas provides backups
- **Code**: Use GitHub for version control
- **Environment**: Document all configurations

---

## ✅ Step 8: Verification Checklist

Before proceeding to development:

- [ ] AWS account created and verified
- [ ] MongoDB Atlas cluster running
- [ ] Firebase project configured
- [ ] Stripe account approved
- [ ] All API keys saved securely
- [ ] Environment file created
- [ ] 2FA enabled on all accounts
- [ ] Billing alerts set up
- [ ] GitHub repository created (optional)

---

## 🎯 Next Steps

Once you've completed this setup:

1. **Test all connections** to ensure everything works
2. **Start building your API** using these services
3. **Monitor usage** to stay within free tier limits
4. **Plan your upgrade path** for when you exceed limits

---

## 💡 Pro Tips

- **Start with test data** to avoid hitting limits
- **Monitor usage daily** during development
- **Keep all credentials secure** and backed up
- **Document everything** for your team
- **Test in production-like environment** before going live

---

## 🆘 Need Help?

If you get stuck on any step:
1. Check the official documentation for each service
2. Use the support forums (all free)
3. Contact me for specific issues

**Remember**: You're building for 1M users, but starting smart with free tiers! 🚀
