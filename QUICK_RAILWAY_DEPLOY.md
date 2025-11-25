# 🚀 Quick Railway Deployment

## You're Ready to Deploy! Here's How:

### Option 1: Deploy via Web Dashboard (Recommended - Easiest!)

1. **Go to Railway**: https://railway.app
2. **Sign up** with your GitHub account
3. **Click "New Project"** → **"Deploy from GitHub repo"**
4. **Select your YUGI repository**
5. **Set root directory** to: `backend/`
6. **Configure environment variables** (see below)
7. **Generate a public domain** → Railway will give you a URL
8. **Update your iOS app** with the Railway URL

### Option 2: Use Railway CLI (If you want terminal control)

If you want to install Railway CLI without permissions issues:
```bash
# Create a local directory for global npm packages
mkdir ~/.npm-global

# Configure npm to use it
npm config set prefix '~/.npm-global'

# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Deploy from backend directory
cd backend
railway init
railway up
```

---

## ⚙️ Environment Variables to Set in Railway

Copy these into Railway's "Variables" tab:

```bash
# Basic Config
NODE_ENV=production
PORT=3001

# Database - YOU NEED TO UPDATE THIS!
# Get a free MongoDB Atlas cluster at: https://www.mongodb.com/cloud/atlas
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/yugi

# JWT Secret - Generate a random string
JWT_SECRET=your-super-secret-jwt-key-min-32-chars-change-this

# Email (Gmail) - Get app password from Google
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-16-char-app-password

# APIs - Add your actual keys
GOOGLE_PLACES_API_KEY=your_key_here
FOURSQUARE_API_KEY=your_key_here

# Firebase - Download service account from Firebase Console
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_PRIVATE_KEY_ID=your_key_id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@...
FIREBASE_CLIENT_ID=your_client_id
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=your_cert_url

# Stripe (if using payments)
STRIPE_SECRET_KEY=sk_live_your_key
STRIPE_WEBHOOK_SECRET=whsec_your_secret
```

---

## 📋 Quick Checklist

**Before Deployment:**
- [ ] Set up MongoDB Atlas (free)
- [ ] Get Gmail app password (if using email)
- [ ] Gather all API keys

**During Deployment:**
- [ ] Create Railway account
- [ ] Deploy from GitHub
- [ ] Set root to `backend/`
- [ ] Copy environment variables
- [ ] Generate public domain

**After Deployment:**
- [ ] Test: `https://your-app.railway.app/api/health`
- [ ] Update iOS app with Railway URL
- [ ] Test iOS app with production backend

---

## 🎯 Where to Update iOS App

**File**: `YUGI/Services/APIService.swift`  
**Line**: 32  
**Change to**: 
```swift
case .production:
    return "https://your-app-name.railway.app/api"
```

---

## 💰 Cost

- **Free**: $5 credit per month
- **Small apps**: Usually stay within free tier
- **Charges**: Only after free credit is used

---

## ⚡ Quick Test After Deploy

Once Railway gives you a URL, test it:

```bash
# Should return: {"message":"Server is running"}
curl https://your-app-name.railway.app/api/health
```

---

## 🆘 Need More Help?

See detailed guides:
- `RAILWAY_DEPLOYMENT_CHECKLIST.md` - Full step-by-step guide
- `PRODUCTION_DEPLOYMENT_GUIDE.md` - Original deployment guide
- Railway Docs: https://docs.railway.app

**Ready to deploy? Head to https://railway.app! 🚂**

