# 📋 Copy-Paste Variables for Railway Dashboard

## Step 1: Open Railway Variables Tab
Go to: Railway → Your Project → **"Variables"** tab

## Step 2: Add These Variables One by One

Click **"New Variable"** and add each of these:

---

### Variable 1:
**Name:** `NODE_ENV`  
**Value:** `production`

---

### Variable 2:
**Name:** `PORT`  
**Value:** `3001`

---

### Variable 3:
**Name:** `MONGODB_URI`  
**Value:** `mongodb+srv://yugiapp:2JHlycfUaThFOayP@yugiapp.ncak7q4.mongodb.net/yugi?retryWrites=true&w=majority&appName=YUGIAPP`

---

### Variable 4:
**Name:** `JWT_SECRET`  
**Value:** `TjYzUkhYLj2aCQ73gneaYoCGwWMg+vdvAM5kzKI+RRQ=`

---

### Variable 5:
**Name:** `JWT_EXPIRE`  
**Value:** `30d`

---

### Variable 6:
**Name:** `EMAIL_HOST`  
**Value:** `smtp.gmail.com`

---

### Variable 7:
**Name:** `EMAIL_PORT`  
**Value:** `587`

---

### Variable 8:
**Name:** `EMAIL_USER`  
**Value:** `your-email@gmail.com`  ⚠️ **CHANGE THIS TO YOUR EMAIL**

---

### Variable 9:
**Name:** `EMAIL_PASS`  
**Value:** `your-app-password`  ⚠️ **GET THIS FROM GOOGLE**  
**How:** https://myaccount.google.com/apppasswords

---

### Variable 10:
**Name:** `GOOGLE_PLACES_API_KEY`  
**Value:** `AIzaSyDtB5YmjkJjZd_ubxLRhsW3LIspTfkFA1Y`

---

### Variable 11:
**Name:** `FOURSQUARE_API_KEY`  
**Value:** `FMZARCV3GVLVCJG05MNYRUEYCVFDMX1QNRPDR3GXUI4ZCQML`

---

### Variable 12 (Optional):
**Name:** `STRIPE_SECRET_KEY`  
**Value:** `sk_test_your_stripe_secret_key`

---

### Variable 13 (Optional):
**Name:** `STRIPE_WEBHOOK_SECRET`  
**Value:** `whsec_your_webhook_secret`

---

## ⚠️ IMPORTANT: You Need to Update These

### 1. EMAIL_USER
Change `your-email@gmail.com` to your actual Gmail address

### 2. EMAIL_PASS  
You need to:
1. Enable 2FA on your Gmail account
2. Go to: https://myaccount.google.com/apppasswords
3. Generate a new app password
4. Copy the 16-character password
5. Paste it as the value for `EMAIL_PASS`

---

## Quick Checklist

After adding all variables, you should have:
- [ ] NODE_ENV = production
- [ ] PORT = 3001
- [ ] MONGODB_URI = mongodb+srv://...
- [ ] JWT_SECRET = TjYzUkhYLj2aCQ73gneaYoCGwWMg+vdvAM5kzKI+RRQ=
- [ ] JWT_EXPIRE = 30d
- [ ] EMAIL_HOST = smtp.gmail.com
- [ ] EMAIL_PORT = 587
- [ ] EMAIL_USER = your actual email
- [ ] EMAIL_PASS = your Gmail app password
- [ ] GOOGLE_PLACES_API_KEY = AIzaS...
- [ ] FOURSQUARE_API_KEY = FMZAR...

---

## After Adding All Variables

1. ✅ Click "Save" or "Deploy"
2. ✅ Railway will automatically redeploy
3. ✅ Watch the deployment logs
4. ✅ It should work now!

---

**Total time: ~5 minutes to add all variables! 🚀**

