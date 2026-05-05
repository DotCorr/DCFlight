# DCFlight Development Setup Guide

## Environment Status (May 5, 2026)

### Current System
- **Flutter**: 3.41.1 (stable)
- **Dart**: 3.11.0
- **Xcode**: 2416 (macOS)
- **ADB**: Available at `/opt/homebrew/bin/adb`

---

## 🍎 iOS Development Setup

### Prerequisites ✅ VERIFIED
- Xcode installed and configured
- iOS Simulator (iPhone 17 Pro) available
- CocoaPods for dependency management
- Flutter iOS development tools installed

### Quick Start - iOS

```bash
cd /Users/ghostportal/Desktop/Dotcorr/DCFlight/packages/examples/todo_app

# Clean and prepare
flutter clean
flutter pub get

# Run on iPhone 17 Pro simulator
flutter run -d "iPhone 17 Pro"
```

### iOS Devices Available
- **iPhone 17 Pro** - Simulator (RECOMMENDED for testing)
- **iPad van Tahiru** - Physical device (iOS 26.2.1) - Wireless
- **iPhone van Tahiru** - Physical device (iOS 26.3.1) - Wireless (requires Developer Mode)

### Running on Physical iOS Device

**If connecting wirelessly:**
1. Ensure device is on same WiFi network
2. Device must be unlocked
3. Enable Developer Mode on the device
4. Run: `flutter devices` to verify connection
5. Run: `flutter run -d "iPhone van Tahiru"`

**If connecting via USB cable:**
1. Connect device with USB cable
2. Trust the Mac on the device
3. Run: `flutter devices` to verify
4. Run: `flutter run -d <device-id>`

---

## 🤖 Android Development Setup

### Prerequisites - CONFIGURATION REQUIRED

You mentioned **NO Android Studio**, using **physical device instead**. Follow these steps:

#### Step 1: Install Android SDK Tools (without Studio)

```bash
# Using Homebrew (recommended)
brew install android-commandlinetools

# Or download from: https://developer.android.com/studio#command-tools
```

#### Step 2: Set Up Android SDK Path

Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
```

Reload: `source ~/.zshrc`

#### Step 3: Install Required Android SDK Components

```bash
# Accept licenses
yes | sdkmanager --licenses

# Install required packages
sdkmanager "platform-tools"
sdkmanager "build-tools;34.0.0"
sdkmanager "platforms;android-34"
sdkmanager "extras;google;usb_driver"  # For USB debugging on Windows, not needed for macOS
```

#### Step 4: Verify Flutter Android Setup

```bash
flutter doctor -v
```

Check for ✅ marks on:
- Flutter
- Android toolchain
- Flutter plugin

Fix any ❌ issues before proceeding.

### Step 5: Connect Physical Android Device

**Enable USB Debugging:**
1. Open **Settings** on Android device
2. Go to **About phone** → tap **Build number** 7 times (enables Developer Options)
3. Go back to Settings → **Developer options** → enable **USB Debugging**
4. Connect device via USB to Mac
5. On device, tap **Allow** when prompted about USB debugging

**Verify connection:**
```bash
adb devices
```

Should show:
```
List of devices attached
ABC123DEF456	device
```

### Step 6: Run on Android Device

```bash
cd /Users/ghostportal/Desktop/Dotcorr/DCFlight/packages/examples/todo_app

# List connected devices
flutter devices

# Run on your Android device (replace DEVICE_ID if needed)
flutter run -d <DEVICE_ID>
```

---

## 🔧 Common Issues & Solutions

### iOS Issues

**Issue:** "UIScene lifecycle support will soon be required"
- **Status**: Warning only, app still builds
- **Solution**: Update iOS deployment target when ready (see https://flutter.dev/to/uiscene-migration)

**Issue:** CocoaPods dependency errors
```bash
cd ios
pod repo update
pod install --repo-update
cd ..
flutter clean
flutter pub get
flutter run -d "iPhone 17 Pro"
```

### Android Issues

**Issue:** `adb: command not found`
- **Solution**: Ensure `ANDROID_HOME/platform-tools` is in your `$PATH`

**Issue:** Device not showing in `flutter devices`
- Try: `adb kill-server && adb start-server`
- Check USB cable connection
- Verify USB debugging is enabled

**Issue:** Build fails with "SDK not found"
- Run: `flutter doctor -v` and follow suggestions
- Reinstall SDK components: `sdkmanager --update`

---

## 📋 Project Structure

### Working Directory
```
/Users/ghostportal/Desktop/Dotcorr/DCFlight/
├── packages/
│   ├── dcflight/          # Core framework
│   ├── dcf_primitives/    # UI components
│   ├── dcf_reanimated/    # Animation system
│   ├── dcf_screens/       # Navigation
│   └── examples/
│       └── todo_app/      # ← Current test project
├── cli/                   # Command-line tools
└── docs/                  # Documentation
```

### Core Packages Status
- ✅ **dcflight** v0.0.2 - Core framework (production ready)
- ✅ **dcf_primitives** v0.0.2 - UI components
- ✅ **dcf_reanimated** v0.0.1 - Animations
- ✅ **dcf_screens** v0.1.0 - Navigation (production ready)

---

## 🚀 Development Workflow

### Start Development Session

```bash
# iOS development
cd DCFlight/packages/examples/todo_app
flutter run -d "iPhone 17 Pro"

# Android development (after device setup)
flutter run -d <ANDROID_DEVICE_ID>
```

### Hot Reload During Development
- **iOS/Android**: Press `r` in terminal to hot reload
- Press `R` for full app restart
- Press `q` to quit

### Build for Release

```bash
# iOS
flutter build ios --release

# Android (requires release keystore)
flutter build apk --release
```

---

## 📞 Next Steps

1. **Immediate**: Wait for iOS build to complete (check `jobs` in terminal)
2. **Android Setup**: Connect physical device and run SDK manager commands
3. **Testing**: Run todo_app example on both platforms
4. **Debugging**: Use DevTools: `flutter pub global activate devtools` then `devtools`

---

## Useful Commands

```bash
# Check devices
flutter devices

# List all available emulators
flutter emulators

# Show detailed Flutter setup
flutter doctor -v

# Clean everything
flutter clean

# Get dependencies
flutter pub get

# Run with verbose output
flutter run -v

# Kill all flutter daemon processes
killall -9 dart
```

---

**Last Updated**: May 5, 2026
**Status**: iOS building, Android setup pending
