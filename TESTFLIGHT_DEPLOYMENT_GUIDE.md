# 🚀 TestFlight Deployment Guide - Step by Step

Complete guide to get your YUGI app on TestFlight for beta testing.

---

## 📋 Prerequisites Checklist

Before starting, make sure you have:
- [ ] Apple Developer Account ($99/year) - [Sign up here](https://developer.apple.com/programs/)
- [ ] Xcode installed (latest version)
- [ ] App Store Connect access
- [ ] Your app configured with production backend URL
- [ ] Stripe test keys configured (for testing payments)

---

## Step 1: Prepare Your App for Release

### 1.1 Update App Version & Build Number

1. Open your project in Xcode
2. Select your project in the navigator (top item)
3. Select your **YUGI** target
4. Go to **"General"** tab
5. Update:
   - **Version**: `1.0.0` (or your version number)
   - **Build**: `1` (increment this for each upload)

### 1.2 Configure Signing & Capabilities

1. Still in **"General"** tab, scroll to **"Signing & Capabilities"**
2. Check **"Automatically manage signing"**
3. Select your **Team** (your Apple Developer account)
4. Xcode will automatically create/select provisioning profiles

### 1.3 Verify Bundle Identifier

1. In **"General"** tab, check **Bundle Identifier**
2. Should be something like: `com.yourcompany.YUGI`
3. Make sure it matches your App Store Connect app

---

## Step 2: Create App in App Store Connect

### 2.1 Log into App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Sign in with your Apple Developer account
3. Click **"My Apps"**

### 2.2 Create New App

1. Click the **"+"** button (top left)
2. Select **"New App"**
3. Fill out the form:
   - **Platform**: iOS
   - **Name**: YUGI (or your app name)
   - **Primary Language**: English
   - **Bundle ID**: Select your bundle identifier (or create new one)
   - **SKU**: `YUGI-001` (or any unique identifier)
4. Click **"Create"**

### 2.3 Complete App Information (Optional for TestFlight)

You can skip most of this for now, but you'll need:
- App name
- Bundle ID
- That's it for TestFlight!

---

## Step 3: Build & Archive Your App

### 3.1 Select Release Scheme

1. In Xcode, click the scheme selector (next to the play/stop buttons)
2. Select **"Any iOS Device"** or **"Generic iOS Device"**
   - ⚠️ **Don't select a simulator!**

### 3.2 Clean Build Folder

1. Go to **Product** → **Clean Build Folder** (or press `Shift + Cmd + K`)
2. Wait for it to complete

### 3.3 Archive Your App

1. Go to **Product** → **Archive**
2. Wait for the build to complete (this may take a few minutes)
3. The **Organizer** window will open automatically

---

## Step 4: Upload to App Store Connect

### 4.1 In Organizer Window

1. You should see your archive listed
2. Select your archive
3. Click **"Distribute App"**

### 4.2 Choose Distribution Method

1. Select **"App Store Connect"**
2. Click **"Next"**

### 4.3 Choose Distribution Options

1. Select **"Upload"**
2. Click **"Next"**

### 4.4 Select Options

1. **Distribution options**: Usually leave defaults
2. **Include bitcode**: Usually not needed (leave unchecked)
3. Click **"Next"**

### 4.5 Review & Upload

1. Review the summary
2. Click **"Upload"**
3. Wait for upload to complete (this may take 5-10 minutes)
4. You'll see a success message when done

---

## Step 5: Process Build in App Store Connect

### 5.1 Wait for Processing

1. Go back to [App Store Connect](https://appstoreconnect.apple.com/)
2. Click on your app
3. Go to **"TestFlight"** tab
4. You'll see your build with status **"Processing"**
5. Wait 10-30 minutes for Apple to process your build

### 5.2 Check Build Status

- **Processing**: Apple is still processing (wait)
- **Ready to Submit**: Build is ready! ✅
- **Missing Compliance**: You may need to answer export compliance questions

### 5.3 Export Compliance (If Required)

1. If you see "Missing Compliance", click on your build
2. Answer the export compliance questions:
   - **Does your app use encryption?** → Usually **"No"** (unless you're doing custom encryption)
   - Click **"Save"**

---

## Step 6: Set Up TestFlight

### 6.1 Add Test Information (Optional)

1. In TestFlight tab, you can add:
   - **What to Test**: Brief description of what testers should focus on
   - **Feedback Email**: Your email for tester feedback

### 6.2 Add Internal Testers (Immediate Testing)

**Internal Testers** (up to 100):
- Must be part of your App Store Connect team
- Can test immediately (no review)
- Great for your team

**To add:**
1. Go to **"Users and Access"** in App Store Connect
2. Add team members
3. Go back to TestFlight → **"Internal Testing"**
4. Click **"+"** to create a group
5. Name it: "Internal Testers"
6. Add your team members
7. Select your build
8. Click **"Start Testing"**

### 6.3 Add External Testers (Beta Testing)

**External Testers** (up to 10,000):
- Anyone with an email
- Requires Apple review (usually 24-48 hours)
- Great for beta testers

**To add:**
1. Go to TestFlight → **"External Testing"**
2. Click **"+"** to create a group
3. Name it: "Beta Testers"
4. Add tester emails (or share a public link)
5. Select your build
6. Click **"Submit for Review"**
7. Wait for Apple's approval (24-48 hours)

---

## Step 7: Testers Install Your App

### 7.1 Testers Receive Email

- Testers will get an email from Apple
- Or you can share the public TestFlight link

### 7.2 Testers Install TestFlight App

1. Testers need to install **TestFlight** app from App Store (free)
2. Open TestFlight app
3. Accept the invitation
4. Install your app

### 7.3 Testers Can Now Test

- App works like normal App Store app
- They can provide feedback
- You'll see crash reports and feedback in App Store Connect

---

## 🔧 Troubleshooting

### Build Fails to Upload

**Error: "Invalid Bundle"**
- Check Bundle Identifier matches App Store Connect
- Verify signing certificates are valid

**Error: "Missing Compliance"**
- Answer export compliance questions in App Store Connect

**Error: "Invalid Provisioning Profile"**
- Go to Xcode → Preferences → Accounts
- Download manual profiles
- Or let Xcode automatically manage signing

### Build Stuck in "Processing"

- Usually takes 10-30 minutes
- Can take up to 2 hours sometimes
- Just wait, Apple will process it

### Can't See Build in TestFlight

- Make sure you're looking at the right app
- Check that upload completed successfully
- Wait a few more minutes if just uploaded

### Testers Can't Install

- Make sure build is "Ready to Submit"
- Check that testers accepted invitation
- Verify they have TestFlight app installed

---

## ✅ Quick Checklist

- [ ] Apple Developer Account active
- [ ] App created in App Store Connect
- [ ] Version & Build number set in Xcode
- [ ] Signed with your developer account
- [ ] Built and archived successfully
- [ ] Uploaded to App Store Connect
- [ ] Build processed (Ready to Submit)
- [ ] Export compliance answered (if needed)
- [ ] Internal testers added (for immediate testing)
- [ ] External testers added (for beta testing)

---

## 📱 After TestFlight

Once testing is complete:
1. Fix any bugs found
2. Update version/build number
3. Upload new build
4. When ready, submit for App Store review

---

## 🎉 You're Done!

Your app is now on TestFlight! Testers can install and test your app.

**Next Steps:**
- Monitor feedback and crash reports
- Fix any issues found
- Iterate based on feedback
- When ready, submit to App Store

---

## 📞 Need Help?

Common issues:
- **Signing errors**: Check your Apple Developer account membership
- **Upload fails**: Check internet connection, try again
- **Build not appearing**: Wait longer, check App Store Connect

For more help:
- [Apple's TestFlight Guide](https://developer.apple.com/testflight/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

