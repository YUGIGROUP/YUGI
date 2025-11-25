# ✅ Railway Deployment - Step by Step Checklist

## Pre-Deployment Steps

### Step 1: Commit & Push Code ✅
```bash
# Run these in terminal:
cd /Users/evaparmar/Desktop/YUGI
git add backend/.dockerignore backend/Dockerfile backend/railway.json backend/src/server.js
git commit -m "Switch to Docker deployment"
git push
```

### Step 2: Go to Railway
1. Open: https://railway.app
2. Log in
3. Click on your YUGI project
4. Click on "Variables" tab

### Step 3: Add Environment Variables
Click "+ New" and add all 11 variables (see EXACT_VARIABLES_TO_ADD.md)

**Required Variables:**
- [ ] NODE_ENV = production
- [ ] PORT = 3001
- [ ] MONGODB_URI = mongodb+srv://...
- [ ] JWT_SECRET = TjYzUkhYLj2aCQ73gneaYoCGwWMg+vdvAM5kzKI+RRQ=
- [ ] JWT_EXPIRE = 30d
- [ ] EMAIL_HOST = smtp.gmail.com
- [ ] EMAIL_PORT = 587
- [ ] EMAIL_USER = your-email@gmail.com
- [ ] EMAIL_PASS = your-app-password
- [ ] GOOGLE_PLACES_API_KEY = AIzaS...
- [ ] FOURSQUARE_API_KEY = FMZARC...

### Step 4: Redeploy
- Railway should auto-redeploy
- OR click "Redeploy" button
- Watch the logs

---

## What to Look For

### ✅ Success Signs:
- Build completes without errors
- Server starts
- Logs show: "🚀 YUGI Server running on port 3001"
- No error messages

### ❌ Failure Signs:
- Build fails
- "Error" in logs
- Server crashes
- Missing environment variables

---

## After Deployment

### Test Your API:
```bash
# Replace with your Railway URL
curl https://your-app.railway.app/api/health
```

Should return:
```json
{"status":"OK","message":"YUGI API is running"}
```

---

## Quick Reference

**Files changed:**
- backend/Dockerfile (NEW)
- backend/.dockerignore (NEW)
- backend/railway.json (MODIFIED)
- backend/src/server.js (MODIFIED)

**Files removed:**
- backend/nixpacks.toml (DELETED)

**Variables needed:**
- 11 total
- 2 need your info (EMAIL_USER, EMAIL_PASS)

---

**Ready to go! Start with Step 1! 🚀**

