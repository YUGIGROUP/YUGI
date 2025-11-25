# ✅ Next Steps: Add Variables to Railway

## Step 1: Done ✅
Your code is now pushed to GitHub!

---

## Step 2: Go to Railway Now!

### 1. Open Railway Dashboard
- Go to: https://railway.app
- Log in
- Click on your YUGI project

### 2. Click on "Variables" Tab
- You'll see the Variables tab at the top
- Click it

### 3. Add Environment Variables
You need to add 11 variables. Here they are:

---

## The 11 Variables to Add

Click **"+ New"** for each variable and copy-paste exactly:

### #1:
**Name:** `NODE_ENV`  
**Value:** `production`

### #2:
**Name:** `PORT`  
**Value:** `3001`

### #3:
**Name:** `MONGODB_URI`  
**Value:** `mongodb+srv://yugiapp:2JHlycfUaThFOayP@yugiapp.ncak7q4.mongodb.net/yugi?retryWrites=true&w=majority&appName=YUGIAPP`

### #4:
**Name:** `JWT_SECRET`  
**Value:** `TjYzUkhYLj2aCQ73gneaYoCGwWMg+vdvAM5kzKI+RRQ=`

### #5:
**Name:** `JWT_EXPIRE`  
**Value:** `30d`

### #6:
**Name:** `EMAIL_HOST`  
**Value:** `smtp.gmail.com`

### #7:
**Name:** `EMAIL_PORT`  
**Value:** `587`

### #8:
**Name:** `EMAIL_USER`  
**Value:** `your-email@gmail.com` ← **PUT YOUR GMAIL HERE**

### #9:
**Name:** `EMAIL_PASS`  
**Value:** `your-app-password` ← **PUT YOUR GMAIL APP PASSWORD HERE**

### #10:
**Name:** `GOOGLE_PLACES_API_KEY`  
**Value:** `AIzaSyDtB5YmjkJjZd_ubxLRhsW3LIspTfkFA1Y`

### #11:
**Name:** `FOURSQUARE_API_KEY`  
**Value:** `FMZARCV3GVLVCJG05MNYRUEYCVFDMX1QNRPDR3GXUI4ZCQML`

---

## For Variables #8 and #9

**EMAIL_USER:** Put your Gmail address  
Example: `jane@gmail.com`

**EMAIL_PASS:** Get Gmail App Password
1. Go to: https://myaccount.google.com/apppasswords
2. Generate new password
3. Copy the 16 characters
4. Paste it here

---

## After Adding Variables

Railway will automatically:
- ✅ Redeploy your app
- ✅ Use the new variables
- ✅ Start the server

Watch the logs to see it deploy!

---

## Then Test!

Once deployed, test with:
```bash
curl https://your-app.railway.app/api/health
```

Should return: `{"status":"OK","message":"YUGI API is running"}`

---

**Go ahead and add those variables now! 🚀**

