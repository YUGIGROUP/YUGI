# 🎨 How to Change Your App Icon

Step-by-step guide to change the YUGI app icon before TestFlight.

---

## 📋 What You Need

- **Icon Image**: 1024x1024 pixels (PNG format, no transparency)
- **Design**: Square image (iOS will round the corners automatically)
- **File Format**: PNG or JPEG

---

## 🎯 Step-by-Step Instructions

### Step 1: Prepare Your Icon Image

1. **Create or find your icon image**
   - Size: **1024x1024 pixels** (required!)
   - Format: PNG (recommended) or JPEG
   - **No transparency** (solid background)
   - Square shape (iOS will add rounded corners automatically)

2. **Design Tips**:
   - Keep important content in the center (corners get rounded)
   - Use high contrast colors
   - Make it recognizable at small sizes
   - Test how it looks at different sizes

### Step 2: Open Assets.xcassets in Xcode

1. Open your project in Xcode
2. In the Project Navigator (left sidebar), find:
   ```
   YUGI
     └── Assets.xcassets
         └── AppIcon
   ```
3. Click on **"AppIcon"**

### Step 3: Replace the Icon Images

You'll see slots for different icon sizes. For modern iOS, you mainly need:

**Required:**
- **1024x1024** (Universal) - This is the main one!

**Optional (for different appearances):**
- **1024x1024** (Dark appearance) - For dark mode
- **1024x1024** (Tinted) - For iOS 18+ tinted icons

**To add your icon:**

1. **Method 1: Drag & Drop** (Easiest)
   - Drag your 1024x1024 PNG file onto the **1024x1024** slot
   - Xcode will automatically generate all other sizes

2. **Method 2: Click to Select**
   - Click on the **1024x1024** slot
   - Click the **"+"** button or right-click → "Import"
   - Select your icon file

### Step 4: Verify Icon Appears

1. After adding, you should see your icon in the AppIcon set
2. Xcode will show a preview of how it looks

### Step 5: Test Your Icon

1. **Build and run** your app on a device or simulator
2. Check the home screen to see your new icon
3. Make sure it looks good at different sizes

---

## 🎨 Icon Requirements

### Technical Requirements

- **Size**: 1024x1024 pixels (exactly!)
- **Format**: PNG (recommended) or JPEG
- **Color Space**: RGB
- **No Alpha Channel**: No transparency (solid background)
- **File Size**: Keep under 500KB if possible

### Design Guidelines

- **Square**: Design as square, iOS adds rounded corners
- **Safe Area**: Keep important content in center 80% (corners get cut)
- **Contrast**: High contrast works best
- **Simple**: Works well at small sizes (appears as 60x60 on home screen)
- **Brand**: Should represent your app/brand

---

## 🌙 Dark Mode & Tinted Icons (Optional)

### Dark Mode Icon

iOS can show a different icon in dark mode:

1. Add a **1024x1024** image to the **Dark appearance** slot
2. This will show when user has dark mode enabled

### Tinted Icon (iOS 18+)

For iOS 18+, you can provide a tinted version:

1. Add a **1024x1024** image to the **Tinted** slot
2. This allows iOS to apply system tints

**Note**: These are optional - if you don't add them, iOS will use your main icon.

---

## 🔍 Troubleshooting

### Icon Not Showing Up

**Problem**: Icon doesn't appear after adding
- **Solution**: Clean build folder (Product → Clean Build Folder)
- **Solution**: Delete app from device/simulator and reinstall

### Icon Looks Blurry

**Problem**: Icon appears pixelated
- **Solution**: Make sure you're using exactly 1024x1024 pixels
- **Solution**: Use PNG format (better quality than JPEG)

### Icon Has Wrong Shape

**Problem**: Icon looks stretched or distorted
- **Solution**: Make sure your source image is square (1:1 ratio)
- **Solution**: Don't add rounded corners yourself (iOS does this)

### Icon Too Large/Too Small

**Problem**: Icon doesn't fill the space properly
- **Solution**: Make sure image is exactly 1024x1024 pixels
- **Solution**: Check that you're using the correct slot

---

## ✅ Quick Checklist

Before uploading to TestFlight:
- [ ] Icon is 1024x1024 pixels
- [ ] Icon is PNG format (or JPEG)
- [ ] Icon has no transparency (solid background)
- [ ] Icon is square (1:1 ratio)
- [ ] Icon added to AppIcon asset catalog
- [ ] Tested on device/simulator
- [ ] Icon looks good at small sizes

---

## 🎨 Icon Design Tips

### Best Practices

1. **Keep it Simple**: Works well at 60x60 pixels
2. **High Contrast**: Light icon on dark background (or vice versa)
3. **Center Content**: Important elements in center 80%
4. **No Text**: Usually too small to read
5. **Recognizable**: Users should know what app it is

### What Works Well

- ✅ Simple geometric shapes
- ✅ Single letter or symbol
- ✅ Recognizable logo
- ✅ High contrast colors
- ✅ Clean, minimal design

### What to Avoid

- ❌ Too much detail
- ❌ Small text
- ❌ Low contrast
- ❌ Important content in corners
- ❌ Complex illustrations

---

## 📱 Testing Your Icon

### On Simulator

1. Build and run your app
2. Check home screen
3. Check app switcher (swipe up)
4. Check Settings → Your App

### On Device

1. Install on physical device
2. Check home screen
3. Check different home screen layouts
4. Check dark mode (if you added dark icon)

---

## 🚀 After Changing Icon

Once you've updated your icon:

1. **Test locally** first
2. **Clean build** (Product → Clean Build Folder)
3. **Archive** for TestFlight (as normal)
4. Your new icon will appear in TestFlight!

---

## 💡 Pro Tips

1. **Use Design Tools**: 
   - Figma, Sketch, or Canva can help create perfect 1024x1024 icons
   - Many online icon generators available

2. **Preview Before Upload**:
   - Test on device first
   - Make sure it looks good at small sizes

3. **Keep Original**:
   - Save your icon source file
   - Easy to make changes later

4. **A/B Testing**:
   - You can change icon between TestFlight builds
   - Get feedback from testers

---

## 🎉 You're Done!

Your app icon is now updated! When you archive and upload to TestFlight, your new icon will appear.

**Remember**: You can always change it again later - just update the icon and upload a new build!

