# 🔄 How to Switch to Release Mode in Xcode

## Why Release Mode?
- **Debug Mode**: Uses local development backend (`http://192.168.1.72:3001/api`)
- **Release Mode**: Uses production Railway backend (`https://yugi-production.up.railway.app/api`)
- Release mode is what real users will use!

---

## Step-by-Step Instructions

### Step 1: Open Scheme Editor
1. At the top of Xcode, find the scheme selector
   - It shows: **"YUGI > My Mac"** or **"YUGI > iPhone 15 Pro"** (or your device)
2. Click on it to open the dropdown
3. Select **"Edit Scheme..."** at the bottom

### Step 2: Change Build Configuration
1. In the left sidebar, click **"Run"** (under "Debug")
2. Click the **"Info"** tab at the top
3. Find **"Build Configuration"** dropdown
4. Change from **"Debug"** to **"Release"**
5. Click **"Close"** button

### Step 3: Build & Run
1. Click the **Play** button (▶️) or press **⌘+R**
2. Xcode will now build in Release mode
3. Your app will connect to Railway automatically! 🚀

---

## Verify It's Working

When the app launches, check the Xcode console. You should see:
```
🔗 APIConfig: Using base URL: https://yugi-production.up.railway.app/api
🔗 APIConfig: Environment: production
```

If you see this, you're in Release mode! ✅

---

## Quick Tips

**To Switch Back to Debug:**
- Same steps, but change **"Release"** back to **"Debug"**

**For App Store Submission:**
- Always use Release mode for TestFlight and App Store builds

**For Local Development:**
- Use Debug mode and make sure your local backend is running

---

## What's the Difference?

| Mode | Backend URL | When to Use |
|------|-------------|-------------|
| **Debug** | `http://192.168.1.72:3001/api` | Local development & testing |
| **Release** | `https://yugi-production.up.railway.app/api` | Testing production, App Store builds |

---

**Ready? Go switch to Release mode and test! 🎉**
