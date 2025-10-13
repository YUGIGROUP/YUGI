# 🚀 YUGI Backend Production Deployment Guide

## The Problem
Your iOS app currently connects to `http://192.168.1.72:3001/api` (your local network), which won't work for real users who download your app.

## ✅ Solution: Deploy to Railway (Free & Easy)

### Step 1: Prepare Your Backend
1. Your `backend/` folder is already ready with:
   - ✅ `package.json` with correct start script
   - ✅ `railway.json` configuration file
   - ✅ Proper server setup

### Step 2: Set Up Railway Account
1. Go to [railway.app](https://railway.app)
2. Sign up with GitHub
3. Create a new project

### Step 3: Deploy Your Backend
1. In Railway dashboard, click "New Project"
2. Choose "Deploy from GitHub repo"
3. Select your YUGI repository
4. Choose the `backend/` folder as the root
5. Railway will automatically detect it's a Node.js app

### Step 4: Configure Environment Variables
In Railway dashboard, go to Variables tab and add:

```
NODE_ENV=production
PORT=3001

# Copy all your existing .env values here:
MONGODB_URI=your_mongodb_connection_string
JWT_SECRET=your_jwt_secret
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your_email@gmail.com
EMAIL_PASS=your_email_password
GOOGLE_PLACES_API_KEY=your_google_places_key
FOURSQUARE_API_KEY=your_foursquare_key
FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_PRIVATE_KEY_ID=your_firebase_private_key_id
FIREBASE_PRIVATE_KEY=your_firebase_private_key
FIREBASE_CLIENT_EMAIL=your_firebase_client_email
FIREBASE_CLIENT_ID=your_firebase_client_id
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=your_firebase_client_x509_cert_url
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret
```

### Step 5: Get Your Production URL
After deployment, Railway will give you a URL like:
`https://your-app-name.railway.app`

### Step 6: Update iOS App
Update `YUGI/Services/APIService.swift` line 32:
```swift
case .production:
    return "https://your-app-name.railway.app/api"
```

### Step 7: Test Production Connection
1. Build your iOS app in Release mode
2. Test all API calls to ensure they work
3. Deploy to TestFlight/App Store

## 🎯 Result
- ✅ Real users can connect to your app
- ✅ No more "connecting to server" errors
- ✅ Professional production setup
- ✅ Automatic deployments when you push code changes

## 🔧 Alternative Hosting Options
- **Vercel**: Good for serverless functions
- **Heroku**: More expensive but very reliable
- **DigitalOcean**: Full control but more complex setup

## 📱 Next Steps
1. Deploy to Railway
2. Update iOS app with production URL
3. Test thoroughly
4. Submit to App Store

Your users will never need to manually connect to the server again! 🎉
