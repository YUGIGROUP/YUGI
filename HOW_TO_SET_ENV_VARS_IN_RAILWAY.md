# 🔐 How to Set Environment Variables in Railway

## Simple Explanation

Environment variables are like configuration settings for your app. Instead of putting them in a file that gets deleted, you add them in Railway's dashboard so they stay secure and available to your app.

---

## Step-by-Step Guide

### 1. Go to Your Railway Dashboard
- Visit: https://railway.app
- Log in to your account
- Click on your **YUGI** project

### 2. Open the Variables Tab
- In your project dashboard, look for **"Variables"** tab
- Click on it
- You'll see a list of environment variables (probably empty at first)

### 3. Add Each Variable
Click **"New Variable"** or **"Add"** button and add these one by one:

**Variable Name:** `NODE_ENV`  
**Variable Value:** `production`

**Variable Name:** `PORT`  
**Variable Value:** `3001`

**Variable Name:** `MONGODB_URI`  
**Variable Value:** `mongodb+srv://yugiapp:2JHlycfUaThFOayP@yugiapp.ncak7q4.mongodb.net/yugi?retryWrites=true&w=majority&appName=YUGIAPP`

**Variable Name:** `JWT_SECRET`  
**Variable Value:** `your-super-secret-jwt-key-change-this-in-production`

**Variable Name:** `JWT_EXPIRE`  
**Variable Value:** `30d`

**Variable Name:** `EMAIL_HOST`  
**Variable Value:** `smtp.gmail.com`

**Variable Name:** `EMAIL_PORT`  
**Variable Value:** `587`

**Variable Name:** `EMAIL_USER`  
**Variable Value:** `your-email@gmail.com`

**Variable Name:** `EMAIL_PASS`  
**Variable Value:** `your-app-password` *(get from Google)*

**Variable Name:** `GOOGLE_PLACES_API_KEY`  
**Variable Value:** `AIzaSyDtB5YmjkJjZd_ubxLRhsW3LIspTfkFA1Y`

**Variable Name:** `FOURSQUARE_API_KEY`  
**Variable Value:** `FMZARCV3GVLVCJG05MNYRUEYCVFDMX1QNRPDR3GXUI4ZCQML`

---

## Important Things to Update

### 🔴 Change These:

1. **JWT_SECRET** - Generate a random secret:
   ```bash
   # Run this in terminal to generate a random secret:
   openssl rand -base64 32
   ```

2. **EMAIL_PASS** - Get from Google:
   - Enable 2FA on your Gmail account
   - Go to: https://myaccount.google.com/apppasswords
   - Generate a new app password
   - Use that 16-character password

3. **EMAIL_USER** - Your actual Gmail address

---

## Visual Layout

When you're done, your Variables tab should look like this:

```
Variables
├── NODE_ENV = production
├── PORT = 3001
├── MONGODB_URI = mongodb+srv://...
├── JWT_SECRET = your-random-secret
├── JWT_EXPIRE = 30d
├── EMAIL_HOST = smtp.gmail.com
├── EMAIL_PORT = 587
├── EMAIL_USER = your-email@gmail.com
├── EMAIL_PASS = your-app-password
├── GOOGLE_PLACES_API_KEY = AIzaS...
└── FOURSQUARE_API_KEY = FMZARC...
```

---

## Why This Matters

Without environment variables:
- ❌ Server won't know how to connect to MongoDB
- ❌ Can't send emails
- ❌ API keys won't work
- ❌ App will crash on startup

With environment variables:
- ✅ Server connects to database
- ✅ Emails work
- ✅ All APIs function
- ✅ App runs smoothly

---

## Quick Reference

**Copy this to a text file, then copy-paste into Railway:**

```
NODE_ENV=production
PORT=3001
MONGODB_URI=mongodb+srv://yugiapp:2JHlycfUaThFOayP@yugiapp.ncak7q4.mongodb.net/yugi?retryWrites=true&w=majority&appName=YUGIAPP
JWT_SECRET=CHANGE-THIS-TO-A-RANDOM-STRING
JWT_EXPIRE=30d
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=CHANGE-THIS-TO-GMAIL-APP-PASSWORD
GOOGLE_PLACES_API_KEY=AIzaSyDtB5YmjkJjZd_ubxLRhsW3LIspTfkFA1Y
FOURSQUARE_API_KEY=FMZARCV3GVLVCJG05MNYRUEYCVFDMX1QNRPDR3GXUI4ZCQML
```

---

## After Setting Variables

1. ✅ Save all variables
2. ✅ Railway will automatically redeploy
3. ✅ Watch the deployment logs
4. ✅ Test your API!

---

**That's it! Your app will now have access to all the configuration it needs! 🎉**

