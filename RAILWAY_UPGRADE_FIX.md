# 🔧 Railway Upgrade Troubleshooting Guide

## Issue: Deployment Failed After Upgrading to Hobby Plan

When upgrading from free trial to hobby plan, Railway sometimes:
- Resets environment variables
- Changes deployment settings
- Requires manual redeployment

---

## Step 1: Check Deployment Logs

1. Go to Railway Dashboard: https://railway.app
2. Click on your **YUGI** project
3. Click on the **service** (usually shows "Deploying" or "Failed")
4. Click on **"Deployments"** tab
5. Click on the **latest deployment** (should show "Failed" or error)
6. Check the **logs** - look for error messages

**Common errors:**
- `Cannot find module` → Missing dependencies
- `Environment variable not set` → Missing env vars
- `Port already in use` → Port conflict
- `MongoDB connection failed` → Database issue

---

## Step 2: Verify Root Directory

1. In Railway Dashboard → Your Project
2. Click on **"Settings"** tab
3. Scroll to **"Root Directory"**
4. Make sure it's set to: `backend`
5. If it's wrong, change it and click **"Save"**
6. Railway will auto-redeploy

---

## Step 3: Check Environment Variables

1. In Railway Dashboard → Your Project
2. Click on **"Variables"** tab
3. Verify these **critical variables** are present:

### Required Variables:
- ✅ `NODE_ENV` = `production`
- ✅ `PORT` = `3001`
- ✅ `MONGODB_URI` = `mongodb+srv://yugiapp:2JHlycfUaThFOayP@yugiapp.ncak7q4.mongodb.net/yugi?retryWrites=true&w=majority&appName=YUGIAPP`
- ✅ `JWT_SECRET` = (your secret key)
- ✅ `JWT_EXPIRE` = `30d`
- ✅ `STRIPE_SECRET_KEY` = (your Stripe test key)
- ✅ `FOURSQUARE_API_KEY` = `OWJRIKXWGCPIGM55OK5K33RCAR0Y2N1A0LQ4DB05OG2CSZBL`

### If Variables Are Missing:
1. Click **"+ New Variable"**
2. Add each missing variable
3. Railway will auto-redeploy when you save

---

## Step 4: Manual Redeploy

If variables are correct but deployment still fails:

1. In Railway Dashboard → Your Project
2. Click on **"Deployments"** tab
3. Click **"Redeploy"** button (top right)
4. Or click **"..."** menu → **"Redeploy"**

---

## Step 5: Check Build Logs

1. In Railway Dashboard → Your Project
2. Click on **"Deployments"** tab
3. Click on the **latest deployment**
4. Scroll through the logs and look for:
   - `npm ci` errors
   - `npm start` errors
   - Port binding errors
   - Database connection errors

---

## Step 6: Verify Service is Running

After redeploy, check if service is healthy:

1. In Railway Dashboard → Your Project
2. Click on **"Settings"** tab
3. Scroll to **"Public Domain"**
4. Copy the URL (e.g., `https://yugi-production.up.railway.app`)
5. Test in browser: `https://your-url.railway.app/api/health`
6. Should return: `{"status":"OK","message":"YUGI API is running"}`

---

## Step 7: Fix "Resource Not Found" in App

If Railway is working but app shows "resource not found":

1. Check your app's API base URL
2. Make sure it matches your Railway domain
3. The URL should be: `https://your-app.railway.app` (no trailing slash)

---

## Common Fixes

### Fix 1: Missing Environment Variables
**Symptom:** Deployment fails with "undefined" errors  
**Fix:** Add all required environment variables (see Step 3)

### Fix 2: Wrong Root Directory
**Symptom:** "Cannot find module" or "package.json not found"  
**Fix:** Set root directory to `backend` (see Step 2)

### Fix 3: Port Conflict
**Symptom:** "Port already in use" or "EADDRINUSE"  
**Fix:** Railway handles this automatically, but check PORT variable is `3001`

### Fix 4: MongoDB Connection Failed
**Symptom:** "MongoServerError" or "connection timeout"  
**Fix:** 
- Verify `MONGODB_URI` is correct
- Check MongoDB Atlas allows Railway IPs (should be 0.0.0.0/0)

### Fix 5: Build Failed
**Symptom:** "npm ci" fails or "npm start" fails  
**Fix:**
- Check `package.json` is valid
- Verify Node.js version (should be 18)
- Check for syntax errors in code

---

## Quick Checklist

- [ ] Root directory set to `backend`
- [ ] All environment variables present
- [ ] Latest code pushed to GitHub
- [ ] Deployment shows "Active" (green)
- [ ] Health check endpoint works: `/api/health`
- [ ] App API URL matches Railway domain

---

## Still Not Working?

1. **Check Railway Status:** https://status.railway.app
2. **View Full Logs:** Railway Dashboard → Deployments → Latest → View Logs
3. **Contact Railway Support:** They're usually very responsive

---

## After Fixing

Once deployment is successful:
1. Test login in your app
2. Test booking flow
3. Check Railway logs for any errors
4. Monitor for a few minutes to ensure stability

