# 🧪 How to Test Production Backend

## Step 1: Build in Release Mode

### In Xcode:
1. Open your `YUGI.xcodeproj`
2. At the top, change from **Debug** to **Release**:
   - Look for dropdown: "YUGI > My Mac" or similar
   - Click it
   - Select **"Edit Scheme..."**
   - Under "Run" → "Info" tab
   - Change "Build Configuration" from **Debug** to **Release**
   - Click "Close"

---

## Step 2: Build & Run on Device

### Option A: Physical Device (Recommended)
1. Connect your iPhone/iPad to Mac
2. Select your device in Xcode
3. Click **Run** button (or ⌘+R)
4. App will install on your device

### Option B: Simulator (Quick Test)
1. Select any iPhone simulator
2. Click **Run** button
3. App will open in simulator

---

## Step 3: Test Features

### Basic Tests:
- [ ] **Sign Up** - Create new account
- [ ] **Login** - Sign in with email/password
- [ ] **View Classes** - Browse available classes
- [ ] **Search** - Search for classes
- [ ] **Profile** - View/edit profile

### If you're logged in as PARENT:
- [ ] **Add Children** - Add child profiles
- [ ] **Book Class** - Complete booking flow
- [ ] **View Bookings** - See your bookings
- [ ] **Dashboard** - Parent dashboard loads

### If you're logged in as PROVIDER:
- [ ] **Create Class** - Create new class
- [ ] **View My Classes** - See your classes
- [ ] **View Bookings** - See incoming bookings
- [ ] **Dashboard** - Provider dashboard loads

---

## Step 4: Check What's Working

### Success Signs ✅
- App loads without errors
- API calls succeed
- Data appears correctly
- No "connection failed" errors

### Issues to Watch For ❌
- "Connection failed" messages
- Empty screens where data should be
- Crash on certain actions
- Authentication issues

---

## Step 5: Monitor Railway Logs

While testing, watch Railway logs:

1. Go to Railway Dashboard
2. Click on your YUGI project
3. Click **"Logs"** tab
4. You'll see all API requests in real-time!

---

## Quick Test Checklist

**Must Work:**
- [ ] Sign up new user
- [ ] Login
- [ ] Browse classes
- [ ] View profile
- [ ] Basic navigation

**Nice to Have:**
- [ ] Search classes
- [ ] Book class (if parent)
- [ ] Create class (if provider)
- [ ] Email notifications

---

## If Something Breaks

**Check:**
1. Railway logs for errors
2. Xcode console for errors
3. Network connectivity
4. API endpoints are correct

**Common Issues:**
- Wrong environment (Debug vs Release)
- API URL mismatch
- Missing environment variables
- Database connection issues

---

**Ready to start? Go build in Release mode! 🚀**

