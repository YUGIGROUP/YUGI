# 🔄 How to Update Your App on TestFlight

Quick guide for pushing updates to your TestFlight app after making changes.

---

## 📋 Quick Steps

1. **Make your changes** in Xcode
2. **Increment Build Number** (required!)
3. **Archive** your app
4. **Upload** to App Store Connect
5. **Wait** for processing
6. **Update TestFlight** groups with new build

---

## Step-by-Step Update Process

### Step 1: Make Your Code Changes

1. Open your project in Xcode
2. Make your code changes, bug fixes, etc.
3. Test locally to make sure everything works

### Step 2: Increment Build Number ⚠️ IMPORTANT

**You MUST increase the build number for each upload!**

1. In Xcode, select your project (top item in navigator)
2. Select your **YUGI** target
3. Go to **"General"** tab
4. Find **"Build"** number
5. **Increase it**:
   - If current is `1` → change to `2`
   - If current is `2` → change to `3`
   - And so on...

**Version Number:**
- Can stay the same for bug fixes (e.g., `1.0.0` → `1.0.0`)
- Should increase for new features (e.g., `1.0.0` → `1.1.0`)

### Step 3: Archive Your App

1. Select **"Any iOS Device"** (not a simulator!)
2. Go to **Product** → **Clean Build Folder** (`Shift + Cmd + K`)
3. Go to **Product** → **Archive**
4. Wait for archive to complete

### Step 4: Upload New Build

1. **Organizer** window opens automatically
2. Select your new archive
3. Click **"Distribute App"**
4. Choose **"App Store Connect"** → **Next**
5. Choose **"Upload"** → **Next**
6. Review options → **Next**
7. Click **"Upload"**
8. Wait for upload to complete

### Step 5: Wait for Processing

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app → **TestFlight** tab
3. You'll see new build with status **"Processing"**
4. Wait 10-30 minutes for it to become **"Ready to Submit"**

### Step 6: Update TestFlight Groups

1. In TestFlight tab, go to your test group (Internal or External)
2. Click on the group name
3. Click **"Add Build"** or **"+"** button
4. Select your new build
5. Click **"Done"** or **"Start Testing"**

**That's it!** Testers will automatically see the update in TestFlight app.

---

## 🔍 Understanding Version vs Build

### Version Number (`1.0.0`)
- **What users see** in App Store/TestFlight
- Format: `MAJOR.MINOR.PATCH` (e.g., `1.0.0`, `1.1.0`, `2.0.0`)
- **Can stay the same** for bug fixes
- **Should increase** for new features:
  - Bug fix: `1.0.0` → `1.0.0` ✅
  - New feature: `1.0.0` → `1.1.0` ✅
  - Major update: `1.0.0` → `2.0.0` ✅

### Build Number (`1`, `2`, `3`...)
- **Internal tracking number**
- **MUST increase** for every upload
- Can be any number (doesn't have to be sequential)
- Examples:
  - First upload: Build `1`
  - Second upload: Build `2` ✅
  - Third upload: Build `3` ✅
  - **Cannot reuse**: Build `1` again ❌

---

## 📱 What Testers See

### Automatic Updates

- Testers will see **"Update Available"** in TestFlight app
- They can tap to update
- Old version is replaced automatically
- No need to re-invite testers

### Update Notification

TestFlight app will show:
- "YUGI has an update available"
- Version number (e.g., "Version 1.0.0")
- Build number (e.g., "Build 2")

---

## ⚠️ Common Mistakes to Avoid

### ❌ Don't Reuse Build Numbers
- **Wrong**: Upload Build `1`, then upload Build `1` again
- **Right**: Upload Build `1`, then upload Build `2`

### ❌ Don't Forget to Increment
- Always increase build number before uploading
- Xcode won't stop you, but App Store Connect will reject it

### ❌ Don't Upload from Simulator
- Must select "Any iOS Device" before archiving
- Simulator builds won't work

---

## 🔄 Update Frequency

### How Often Can You Update?

- **As often as you want!** No limit
- Each update needs new build number
- Processing takes 10-30 minutes each time
- Testers get updates automatically

### Recommended Workflow

1. **Make changes** → Test locally
2. **Fix bugs** → Test again
3. **Batch updates** → Upload once per day (or as needed)
4. **Don't upload** every tiny change (wait for meaningful updates)

---

## 🐛 If Something Goes Wrong

### Build Rejected

**Error: "Build number already exists"**
- Solution: Increase build number and try again

**Error: "Invalid bundle"**
- Solution: Check Bundle ID matches App Store Connect

### Testers Not Seeing Update

- Make sure build is "Ready to Submit"
- Check that you added new build to test group
- Testers may need to refresh TestFlight app
- Can take a few minutes to propagate

### Need to Rollback

- Old builds remain available in TestFlight
- Go to test group → Remove new build → Add old build back
- Testers will see previous version

---

## ✅ Quick Checklist

Before each update:
- [ ] Made code changes
- [ ] Tested locally
- [ ] **Incremented Build Number** ⚠️
- [ ] Selected "Any iOS Device"
- [ ] Cleaned build folder
- [ ] Archived successfully
- [ ] Uploaded to App Store Connect
- [ ] Waited for processing
- [ ] Added new build to test groups

---

## 💡 Pro Tips

1. **Use meaningful build numbers**: `1`, `2`, `3` is fine, or use dates like `20241115`
2. **Keep a changelog**: Note what changed in each build
3. **Test before uploading**: Don't upload broken builds
4. **Batch updates**: Group multiple fixes into one update
5. **Communicate with testers**: Let them know what's new

---

## 🎉 That's It!

Updating TestFlight is straightforward:
1. Change code
2. Increase build number
3. Archive & upload
4. Add to test groups

Testers get updates automatically! 🚀

