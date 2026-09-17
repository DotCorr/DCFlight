# Open Snap

Double-click **Run Snap iOS.command** or **Run Snap Android.command**. The launcher starts or reuses the local backend, regenerates the selected native project from `app.dart`, builds it and opens Snap in the simulator. The first build can take several minutes. Leave the terminal open until it says Snap is running.

Create an account on one simulator, then create another on the other simulator. Find the other username, send a friend request and accept it. You can then exchange messages/photos, post a story, and explicitly enable location sharing. Simulator cameras may be unavailable; use the photo picker with an image added to the simulator. Map tiles require internet. Stories expire after 24 hours; shared locations expire after one hour without updates.

This package uses a local development server, not a public deployment. An existing verified Snap server can be reused with its saved local test accounts/data. No credentials are supplied or written into source. The backend continues running after the launcher exits so both apps can communicate. The launcher never kills another process. A busy or unexpected port produces an explanation instead.

`app.dart` is the editable app composition. `logic.dart` contains shared DC Dart business rules. Changes are compiled when a launcher runs. `ios` and `android` are ordinary editable native projects; regeneration protects conflicting manual edits rather than silently overwriting them. Launchers explicitly evaluate the trusted local Dart file: review it before running a project received from someone else.

## Setup on another Mac

The included `toolchain.json` contains machine-specific paths. Install Python 3.12+, Xcode with an iOS simulator, Dart, released DC Dart 0.1.1+, Android SDK/NDK, JDK17 and compatible Gradle. Set each path and the iOS simulator UDID in that file. Create a Python environment and install `backend/requirements.txt`, then set `python` to its executable. Set `compiler` to the dcflight compiler source/package directory. Recreate the `.command` files with `tools/package_snap.py` if the Python path changes; or run `<python> launch.py ios` / `android` directly.

Android's helper uses the isolated `DCFlight_API35_ARM64` AVD and emulator port5580. Set its installation/data/evidence paths in `toolchain.json`; this package does not copy large SDKs, emulators or caches. Native module artifacts already in this app are content-locked dependencies. No SDK download or dependency publication occurs during packaging.

The local backend listens on `127.0.0.1:8765`; Android accesses it through emulator host routing. Its bundled source and full self-hosting instructions are in `backend/README.md`. New launcher-managed backend data/logs live under `.local` unless `backendDatabase` points at existing local data. For a separate deployment, configure HTTPS, server operation and native service URLs before use. This local package is not a claim of completed production deployment/security review.
