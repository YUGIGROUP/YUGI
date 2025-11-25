# 🚂 Railway Deployment Checklist

## Current Status
Your YUGI backend is ready for Railway deployment with all necessary configuration files:
- ✅ `railway.json` - Deployment configuration
- ✅ `nixpacks.toml` - Build configuration  
- ✅ `Dockerfile` - Alternative deployment method
- ✅ `package.json` - Correct start script
- ✅ `backend/src/server.js` - Server configured for port 3001

## Step-by-Step Deployment

### 1. Create Railway Account & Project
- [ ] Go to [railway.app](https://railway.app)
- [ ] Sign up with GitHub
- [ ] Click "New Project"
- [ ] Select "Deploy from GitHub repo"
- [ ] Select your YUGI repository
- [ ] Set root directory to: `backend/`
- [ ] Railway will auto-detect Node.js

### 2. Configure Environment Variables
Go to the "Variables" tab in Railway dashboard and add:

```bash
NODE_ENV=production
PORT=3001

# Database (UPDATE THIS!)
MONGODB_URI=your_mongodb_atlas_connection_string

# JWT
JWT_SECRET=your-super-secret-jwt-key-min-32-chars

# Email (Gmail)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-specific-password

# Google APIs
GOOGLE_PLACES_API_KEY=your_google_places_key

# Foursquare API
FOURSQUARE_API_KEY=your_foursquare_key

# Firebase Admin SDK
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_PRIVATE_KEY_ID=your_key_id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...your key...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@...
FIREBASE_CLIENT_ID=your_client_id
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=your_cert_url

# Stripe (if using payments)
STRIPE_SECRET_KEY=sk_live_your_stripe_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
```

### 3. Important Setup Notes

#### MongoDB Atlas Setup
- [ ] Create free cluster at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)
- [ ] Whitelist Railway IP: `0.0.0.0/0` (allow all)
- [ ] Create database user
- [ ] Get connection string
- [ ] Update `MONGODB_URI` in Railway variables

#### Gmail App Password
- [ ] Enable 2FA on your Gmail account
- [ ] Generate app-specific password: [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
- [ ] Use the 16-character password for `EMAIL_PASS`

#### Firebase Private Key
- [ ] Download service account JSON from Firebase Console
- [ ] Copy the entire private key including `-----BEGIN/END-----`
- [ ] Paste in Railway (it will handle the newlines)

### 4. Deploy
- [ ] Railway will automatically start deployment
- [ ] Watch deployment logs for errors
- [ ] Wait for "Deployed successfully" message

### 5. Get Your Production URL
- [ ] Go to "Settings" tab
- [ ] Find "Public Domain" section
- [ ] Railway will generate: `https://your-app-name.railway.app`
- [ ] Click "Generate Domain" if needed

### 6. Test Production API
- [ ] Open: `https://your-app-name.railway.app/api/health`
- [ ] Should see: `{"message":"Server is running"}`
- [ ] Test a real endpoint if needed

### 7. Update iOS App
Edit `YUGI/Services/APIService.swift` line 32:

```swift
case .production:
    return "https://your-app-name.railway.app/api" // Your actual Railway URL
```

### 8. Test Production Build
- [ ] Build iOS app in Release mode
- [ ] Test sign-up/login
- [ ] Test API calls
- [ ] Verify all features work

## Troubleshooting

### Common Issues

#### Build Fails
- Check deployment logs in Railway
- Ensure `npm start` works locally
- Verify Node.js version (18 recommended)

#### Database Connection Error
- Verify MongoDB Atlas connection string
- Check IP whitelist allows all (0.0.0.0/0)
- Ensure database user has correct permissions

#### Email Not Sending
- Verify Gmail app password is correct
- Check 2FA is enabled on Gmail
- Test credentials locally first

#### CORS Errors
- Update CORS settings in `backend/src/server.js`
- Add your production domain to allowed origins

### Railway Console Commands
```bash
# View logs
railway logs

# Open shell
railway shell

# Run commands
railway run npm install
railway run node src/server.js
```

## Cost Estimate

**Free Tier (Railway)**
- $5 free credit per month
- Enough for small apps with low traffic
- No payment required to start

**After Free Credit**
- ~$5-20/month for small production apps
- Charges based on usage (CPU, memory, bandwidth)

## Next Steps After Deployment

1. ✅ Update iOS app with production URL
2. ✅ Test all features thoroughly
3. ✅ Monitor Railway logs for errors
4. ✅ Set up monitoring/alerts
5. ✅ Submit to App Store/TestFlight

## Need Help?

- Railway Docs: [docs.railway.app](https://docs.railway.app)
- Support: [railway.app/discord](https://discord.gg/railway)
- Your guide: See `PRODUCTION_DEPLOYMENT_GUIDE.md` for more details

---

**You're almost ready to go live! 🚀**

