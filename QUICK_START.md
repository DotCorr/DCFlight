# DCFlight Development Quick Start

## ✅ Status Report - May 5, 2026

### iOS Development ✅ READY
```
Project: todo_app
Target: iPhone 17 Pro Simulator
Status: ✅ RUNNING
Build Time: 58.3 seconds
Dart Compilation: Complete
Xcode Build: Complete
Components: dcflight, dcf_primitives, dcf_reanimated, dcf_screens
```

**Available iOS Devices:**
- ✅ iPhone 17 Pro (simulator) - **ACTIVE**
- 📱 iPad van Tahiru (wireless) - iOS 26.2.1
- 📱 iPhone van Tahiru (wireless) - iOS 26.3.1

---

## Android Development Setup (Physical Device)

### Quick Reference
```bash
# Check connected devices
adb devices

# Run on Android device
cd /Users/ghostportal/Desktop/Dotcorr/DCFlight/packages/examples/todo_app
flutter run -d <device-id>
```

### Prerequisites
1. ✅ ADB installed at `/opt/homebrew/bin/adb`
2. ⏳ Connect physical Android device via USB
3. ⏳ Enable USB Debugging on device
4. ⏳ Install Android SDK components (optional if using SDK manager)

### Device Setup Instructions

**On your Android phone:**
1. Open **Settings**
2. Tap **About phone** → scroll to **Build number** → tap 7 times
3. Go back to **Settings** → **Developer options** → **USB Debugging** → Enable
4. Connect to Mac via USB cable
5. Tap **Allow** on the USB debugging permission dialog

**Verify on Mac:**
```bash
adb devices
# Should show:
# ABC123DEF456	device
```

---

## 🔄 Development Commands

### Start Developing

```bash
# Preferred: monitored stream with prefixed Flutter + platform logs
cd /Users/ghostportal/Desktop/Dotcorr/DCFlight
./scripts/dev_stream.sh --platform ios

# Terminal 1: Start Flutter (hot reload enabled)
cd /Users/ghostportal/Desktop/Dotcorr/DCFlight/packages/examples/todo_app
flutter run -d "iPhone 17 Pro"

# Terminal 2 (optional): Start DevTools
flutter pub global activate devtools
devtools
```

### During Development
- Press `r` → Hot reload (fast code changes)
- Press `R` → Full app restart
- Press `q` → Quit
- Press `d` → Detach (keep app running)

### Switch Platforms
```bash
# Android with monitored logs
cd /Users/ghostportal/Desktop/Dotcorr/DCFlight
./scripts/dev_stream.sh --platform android --device <android-device-id>

# Switch from iOS to Android
flutter run -d <android-device-id>

# List available devices
flutter devices
```

### Monitored Iteration

Use the stream wrapper when you want one terminal to keep the iterative loop visible while building:

```bash
cd /Users/ghostportal/Desktop/Dotcorr/DCFlight

# Auto-pick the iPhone 17 Pro simulator when available
./scripts/dev_stream.sh --platform ios

# Explicit Android device
./scripts/dev_stream.sh --platform android --device R5CW41XAS7L
```

What it does:
- runs `flutter analyze` once before launch
- keeps `flutter run` interactive for `r`, `R`, `q`, and `d`
- streams prefixed Flutter output to stdout
- streams iOS simulator logs or `adb logcat` in parallel when available
- writes session logs to `.logs/dev-stream/<timestamp>/`

---

## 📊 Build Statistics

| Metric | Value |
|--------|-------|
| Flutter Version | 3.41.1 (stable) |
| Dart Version | 3.11.0 |
| Build Type | Debug |
| iOS Build Time | 58.3s |
| Pod Install Time | 1.3s |
| Dart Compilation | ~55s |

---

## 🛠️ Troubleshooting

### iOS Issues

**"UIScene lifecycle support" warning**
- Status: Safe to ignore (just a warning)
- App builds and runs normally

**Slow hot reload**
- Solution: Restart flutter: `flutter run -d "iPhone 17 Pro"`

**Build fails with pod errors**
```bash
cd ios
pod repo update
pod install --repo-update
cd ..
flutter clean && flutter pub get
```

### Android Issues

**"adb: command not found"**
- Add to `~/.zshrc`:
  ```bash
  export PATH=$PATH:/opt/homebrew/bin
  ```
- Reload: `source ~/.zshrc`

**Device not showing**
- Kill adb: `adb kill-server`
- Restart: `adb start-server`
- Verify USB cable and debugging permissions

**"No devices found"**
- Run: `flutter doctor -v` to diagnose

---

## 📚 Useful Resources

- [Flutter Dev Docs](https://flutter.dev/docs)
- [DCFlight Framework Docs](/Users/ghostportal/Desktop/Dotcorr/DCFlight/README.md)
- [Full Setup Guide](DEVELOPMENT_SETUP.md)

---

## Next Steps

1. ✅ iOS development ready - continue with hot reload development
2. ⏳ **Connect Android device via USB** and enable USB Debugging
3. 🧪 Test both platforms side-by-side
4. 📖 Review `DEVELOPMENT_SETUP.md` for advanced setup

---

**Keep the `flutter run` command running in a terminal for hot reload development!**

Need to switch between iOS and Android? Simply restart with the appropriate device ID.
