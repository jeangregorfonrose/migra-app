# Migra App - Production Release Guide

## 📋 Table of Contents

1. [Production Readiness Checklist](#production-readiness-checklist)
2. [Pre-Production Setup](#pre-production-setup)
3. [Build Configuration](#build-configuration)
4. [Privacy & Compliance](#privacy--compliance)
5. [Google Play Store Requirements](#google-play-store-requirements)
6. [Testing Checklist](#testing-checklist)
7. [Release Steps](#release-steps)
8. [Post-Launch Recommendations](#post-launch-recommendations)

---

## ✅ Production Readiness Checklist

### **Completed Features**

- ✅ **Core Functionality**
  - Map display with Mapbox integration
  - Report submission with location and address
  - Report viewing with detailed information
  - Heatmap visualization for report density
  - User location tracking and display

- ✅ **Authentication & Security**
  - Firebase anonymous authentication
  - Token caching and automatic refresh
  - Secure Bearer token API communication
  - 401 error handling with auto-retry

- ✅ **Localization**
  - English (en)
  - Spanish (es)
  - Haitian Creole (ht)
  - All UI strings fully translated

- ✅ **User Experience**
  - Onboarding flow for first-time users
  - Splash screen with authentication
  - Settings screen (theme, language)
  - Anonymous submission notice
  - Dark/light theme support
  - Language selection on onboarding

- ✅ **Privacy & Security**
  - Anonymous reporting (no personal data)
  - Location permissions properly requested
  - Privacy-focused design

---

## 🔧 Pre-Production Setup

### **1. Update Version Numbers**

Edit `pubspec.yaml`:

```yaml
version: 1.0.0+1  # Format: version+buildNumber
# Example for updates:
# 1.0.1+2 (minor update)
# 1.1.0+3 (feature update)
# 2.0.0+4 (major update)
```

### **2. App Naming (Already Configured)**

- ✅ **iOS**: `ios/Runner/Info.plist` - CFBundleDisplayName: "Migra"
- ✅ **Android**: `android/app/src/main/AndroidManifest.xml` - android:label: "Migra"

### **3. App Icons**

Icons are ready in `assets/icons/`:
- `migra_icon.png` - Main app icon
- `migra_adaptive_foreground.png` - Android adaptive foreground
- `migra_adaptive_background.png` - Android adaptive background

**Generate icons:**
```bash
flutter pub run flutter_launcher_icons
```

---

## 📦 Build Configuration

### **Android Release Build Setup**

#### **Step 1: Create Signing Key**

```bash
keytool -genkey -v -keystore ~/migra-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias migra
```

**Important:** Save the passwords securely! You'll need them for every release.

#### **Step 2: Create `android/key.properties`**

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=migra
storeFile=/Users/yourusername/migra-keystore.jks
```

**⚠️ Add to `.gitignore`:**
```
android/key.properties
*.jks
```

#### **Step 3: Update `android/app/build.gradle`**

Add before the `android` block:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Update the `android` block:

```gradle
android {
    // ... existing configuration ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

---

## 🔒 Privacy & Compliance

### **1. Privacy Policy (REQUIRED)**

Create a privacy policy that covers:

**What Data You Collect:**
- Location data (when app is open)
- Anonymous user ID (Firebase)
- Report content (description, location, timestamp)

**How You Use It:**
- Display reports on map
- Show heatmap of activity
- Prevent spam/abuse

**Data Retention:**
- Reports stored indefinitely
- User location not stored on server
- Anonymous ID persists per device

**User Rights:**
- Right to request data deletion
- Right to know what data is collected
- Contact information for privacy concerns

**Sample Privacy Policy Template:**

```
Privacy Policy for Migra

Last Updated: [Date]

1. Information We Collect
   - Location data when you use the app
   - Anonymous device identifier
   - Report content you submit

2. How We Use Your Information
   - Display community reports on the map
   - Show activity heatmaps
   - Prevent spam and abuse

3. Data Sharing
   - We do not sell your data
   - Reports are shared publicly on the map
   - No personal information is collected or shared

4. Your Rights
   - Request data deletion: contact@migraapp.com
   - Opt-out of location tracking: deny permissions

5. Contact Us
   Email: contact@migraapp.com
```

**Host your privacy policy online** (GitHub Pages, your website, etc.) and get the URL.

### **2. Location Permissions**

**iOS - `ios/Runner/Info.plist` (Already Configured):**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location when open.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location in the background to notify you of nearby reports.</string>
```

**Android - `android/app/src/main/AndroidManifest.xml` (Already Configured):**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## 📱 Google Play Store Requirements

### **1. Build Release Bundle**

**App Bundle (Recommended):**
```bash
flutter build appbundle --release \
  --dart-define=ACCESS_TOKEN=pk.eyJ1IjoiZm9ucm9zZWplYW5ncmVnb3IiLCJhIjoiY21mdWJzbmt4MHEwZjJxbjRlODlscmI3OSJ9.rkVi3xCt5uOSnuogUpYNvQ
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**APK (Alternative):**
```bash
flutter build apk --release \
  --dart-define=ACCESS_TOKEN=pk.eyJ1IjoiZm9ucm9zZWplYW5ncmVnb3IiLCJhIjoiY21mdWJzbmt4MHEwZjJxbjRlODlscmI3OSJ9.rkVi3xCt5uOSnuogUpYNvQ
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### **2. Store Listing Assets**

#### **Required Assets:**

1. **App Icon** - 512x512 PNG
   - Already created: `migra_icon.png`

2. **Feature Graphic** - 1024x500 PNG
   - Create a banner showcasing the app

3. **Screenshots** - Minimum 2, maximum 8
   - Phone screenshots (at least 2)
   - 7-inch tablet (optional)
   - 10-inch tablet (optional)
   - Recommended: 4-6 screenshots showing key features

4. **Short Description** - Max 80 characters
   ```
   Community safety app for reporting immigration enforcement activities
   ```

5. **Full Description** - Max 4000 characters
   ```
   Migra - Community Safety & Awareness

   Stay informed and help your community by reporting immigration 
   enforcement activities in your area.

   KEY FEATURES:
   • View real-time reports from your community on an interactive map
   • Submit anonymous reports of immigration enforcement activity
   • See heatmap visualization of activity density
   • Available in English, Spanish, and Haitian Creole
   • Privacy-focused: All reports are submitted anonymously
   • Dark mode support

   HOW IT WORKS:
   1. Open the app and view reports on the map
   2. Tap the + button to report activity you witness
   3. Add location and brief description
   4. Submit anonymously to help your community

   PRIVACY & SAFETY:
   • No personal information required
   • Anonymous reporting
   • Your location is only used to place reports on the map
   • We do not track or store your personal data

   COMMUNITY GUIDELINES:
   • Only report what you directly witness
   • Provide accurate information
   • Be respectful of others' safety and privacy
   • Do not submit false or misleading reports

   Your safety comes first. Never put yourself at risk to make a report.

   Available in: English, Español, Kreyòl Ayisyen
   ```

6. **Privacy Policy URL**
   - Your hosted privacy policy link

7. **Content Rating**
   - Complete the questionnaire in Play Console
   - Likely rating: Everyone or Teen

### **3. App Categories**

- **Primary Category:** Social
- **Secondary Category:** Maps & Navigation (optional)
- **Tags:** community, safety, immigration, alerts, map

---

## ✅ Testing Checklist

### **Pre-Release Testing**

Test the following scenarios:

#### **Installation & Onboarding**
- [ ] Fresh install shows onboarding
- [ ] Can skip onboarding
- [ ] Language selection works on first screen
- [ ] Onboarding only shows once
- [ ] Splash screen displays correctly

#### **Core Functionality**
- [ ] Map loads with user location
- [ ] User location puck is visible
- [ ] Can view existing reports
- [ ] Can tap reports to see details
- [ ] Can submit new reports
- [ ] Reports appear on map after submission
- [ ] Heatmap displays correctly

#### **Localization**
- [ ] English translation complete
- [ ] Spanish translation complete
- [ ] Haitian Creole translation complete
- [ ] Language switching works in settings
- [ ] All screens update when language changes

#### **Permissions**
- [ ] Location permission requested properly
- [ ] App works when location denied (shows default location)
- [ ] App works when location granted
- [ ] Permission can be changed in settings

#### **Network Conditions**
- [ ] App handles no internet gracefully
- [ ] Shows error message when API fails
- [ ] Retry mechanism works
- [ ] Cached data displays when offline

#### **Edge Cases**
- [ ] App doesn't crash on background/foreground
- [ ] App doesn't crash on rotation
- [ ] Works on different screen sizes
- [ ] Dark mode works correctly
- [ ] Light mode works correctly

#### **Performance**
- [ ] App launches quickly
- [ ] Map scrolling is smooth
- [ ] No memory leaks
- [ ] Battery usage is reasonable

---

## 🚀 Release Steps

### **Step 1: Prepare Release Build**

```bash
# Clean previous builds
flutter clean
flutter pub get

# Run tests (if you have them)
flutter test

# Build release bundle
flutter build appbundle --release \
  --dart-define=ACCESS_TOKEN=your_mapbox_token
```

### **Step 2: Google Play Console Setup**

1. **Create App**
   - Go to [Google Play Console](https://play.google.com/console)
   - Click "Create app"
   - Fill in app details

2. **Upload App Bundle**
   - Go to "Release" → "Production"
   - Click "Create new release"
   - Upload `app-release.aab`
   - Add release notes

3. **Store Listing**
   - Upload all required assets
   - Fill in descriptions
   - Add privacy policy URL
   - Set app category

4. **Content Rating**
   - Complete questionnaire
   - Submit for rating

5. **Pricing & Distribution**
   - Set as "Free"
   - Select countries (start with Dominican Republic, Haiti, USA)
   - Accept terms

6. **App Content**
   - Privacy policy
   - Ads declaration (No ads)
   - Target audience
   - Data safety section

### **Step 3: Internal Testing (Recommended)**

Before going to production:

1. Create internal testing track
2. Upload app bundle to internal track
3. Add test users (email addresses)
4. Test for 1-2 days
5. Fix any critical issues
6. Promote to production when ready

### **Step 4: Submit for Review**

1. Review all sections (green checkmarks)
2. Click "Submit for review"
3. Wait for Google review (typically 1-3 days)
4. Monitor email for approval or feedback

### **Step 5: Post-Launch**

1. Monitor crash reports in Play Console
2. Respond to user reviews
3. Track analytics
4. Plan updates based on feedback

---

## 📊 Post-Launch Recommendations

### **High Priority (Add Soon)**

1. **Firebase Crashlytics**
   - Track crashes in production
   - Get detailed crash reports
   - Monitor app stability

2. **Firebase Analytics**
   - Understand user behavior
   - Track feature usage
   - Measure engagement

3. **Better Error Handling**
   - User-friendly error messages
   - Retry mechanisms for all API calls
   - Offline mode improvements

4. **Loading States**
   - Show loading indicators
   - Skeleton screens
   - Better UX during data fetching

### **Medium Priority**

5. **Rate Limiting**
   - Prevent spam reports
   - Implement cooldown period
   - Backend validation

6. **Report Moderation**
   - Flag inappropriate reports
   - Admin review system
   - Report removal capability

7. **Notification System**
   - Implement FCM notifications
   - Alert users of nearby reports
   - See `docs/notification_system_design.md`

8. **Offline Support**
   - Cache reports locally
   - Queue submissions when offline
   - Sync when online

### **Nice to Have**

9. **User Profiles**
   - View your submitted reports
   - Edit/delete your reports
   - Report history

10. **Report Categories**
    - Different types of activities
    - Filter by category
    - Category-specific icons

11. **Search & Filter**
    - Search by location
    - Filter by date range
    - Filter by category

12. **Social Features**
    - Share reports
    - Export data
    - Community statistics

---

## 🔐 Security Checklist

- [ ] API keys not hardcoded in source
- [ ] Signing keys stored securely
- [ ] `key.properties` in `.gitignore`
- [ ] HTTPS only for API calls
- [ ] Input validation on backend
- [ ] Rate limiting on backend
- [ ] Firebase security rules configured
- [ ] ProGuard/R8 enabled for release

---

## 📞 Support & Maintenance

### **Monitoring**

- **Play Console:** Check daily for crashes
- **Firebase Console:** Monitor analytics
- **User Reviews:** Respond within 24-48 hours
- **Backend Logs:** Monitor API errors

### **Update Schedule**

- **Critical bugs:** Hotfix within 24 hours
- **Minor bugs:** Include in next update (1-2 weeks)
- **Features:** Monthly or quarterly releases
- **Security updates:** Immediate

### **Version Numbering**

- **Major (X.0.0):** Breaking changes, major features
- **Minor (1.X.0):** New features, improvements
- **Patch (1.0.X):** Bug fixes, minor tweaks
- **Build (+X):** Increment for each upload

---

## 📝 Pre-Launch Checklist Summary

### **Must Complete Before Launch:**
- [ ] Create signing key
- [ ] Configure `key.properties`
- [ ] Update `build.gradle` for signing
- [ ] Create and host privacy policy
- [ ] Build release bundle
- [ ] Test on real device
- [ ] Create Play Store listing
- [ ] Upload all required assets
- [ ] Complete content rating
- [ ] Set pricing and distribution
- [ ] Submit for review

### **Strongly Recommended:**
- [ ] Internal testing with real users
- [ ] Add Firebase Crashlytics
- [ ] Add basic analytics
- [ ] Test all three languages
- [ ] Test on multiple devices
- [ ] Prepare customer support email

### **Can Do After Launch:**
- [ ] Notification system
- [ ] Advanced features
- [ ] UI improvements
- [ ] Community feedback implementation

---

## 🎯 Quick Commands Reference

```bash
# Clean and get dependencies
flutter clean && flutter pub get

# Generate localization
flutter gen-l10n

# Generate app icons
flutter pub run flutter_launcher_icons

# Build release bundle
flutter build appbundle --release --dart-define=ACCESS_TOKEN=your_token

# Build release APK
flutter build apk --release --dart-define=ACCESS_TOKEN=your_token

# Run on device
flutter run --dart-define=ACCESS_TOKEN=your_token
```

---

## 📚 Additional Resources

- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Signing Best Practices](https://developer.android.com/studio/publish/app-signing)
- [Privacy Policy Generator](https://www.privacypolicygenerator.info/)
- [Firebase Documentation](https://firebase.google.com/docs)

---

**Good luck with your launch! 🚀**

For questions or issues, refer to this guide or consult the Flutter and Google Play documentation.
