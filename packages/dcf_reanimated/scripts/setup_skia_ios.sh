#!/bin/bash

# Skia iOS Setup Script
# This script automatically builds and integrates Skia for iOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IOS_DIR="$PACKAGE_DIR/ios"
SKIA_DIR="$IOS_DIR/Skia"
BUILD_DIR="$SKIA_DIR/build"

echo "🎨 Setting up Skia for iOS..."

# Check if Skia is already built with simulator support
if [ -f "$SKIA_DIR/lib/libskia.a" ] && [ -d "$SKIA_DIR/include" ]; then
    # Check architectures in the library
    LIPO_INFO=$(lipo -info "$SKIA_DIR/lib/libskia.a" 2>&1)
    ARCH_COUNT=$(echo "$LIPO_INFO" | grep -o "arm64\|x86_64\|x64" | sort -u | wc -l | tr -d ' ')
    
    # On Apple Silicon, we need at least 2 arm64 slices (device + simulator) or device + x64
    # On Intel, we need device arm64 + x64 simulator
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        # Need device arm64 + simulator arm64 (or x64 for compatibility)
        if [ "$ARCH_COUNT" -ge 2 ]; then
            echo "✅ Skia already built with simulator support!"
            echo "📦 Using pre-built Skia (no building needed)"
            exit 0
        else
            echo "⚠️  Skia library found but missing simulator architecture"
            echo "🔨 Rebuilding with simulator support..."
            rm -f "$SKIA_DIR/lib/libskia.a"
        fi
    else
        # Intel Mac - need arm64 device + x64 simulator
        if echo "$LIPO_INFO" | grep -q "arm64" && echo "$LIPO_INFO" | grep -q "x86_64\|x64"; then
            echo "✅ Skia already built with simulator support!"
            echo "📦 Using pre-built Skia (no building needed)"
            exit 0
        else
            echo "⚠️  Skia library found but missing simulator architecture"
            echo "🔨 Rebuilding with simulator support..."
            rm -f "$SKIA_DIR/lib/libskia.a"
        fi
    fi
fi

echo "📦 Skia not found - building from source..."
echo "⚠️  This will take 30-60 minutes and requires ~15GB disk space"

# Create Skia directory structure
mkdir -p "$SKIA_DIR/include"
mkdir -p "$SKIA_DIR/lib"
mkdir -p "$BUILD_DIR"

# Check if Skia is already cloned
if [ ! -d "$BUILD_DIR/skia" ]; then
    echo "📦 Cloning Skia repository..."
    cd "$BUILD_DIR"
    git clone https://skia.googlesource.com/skia.git
fi

cd "$BUILD_DIR/skia"

# Update Skia
echo "🔄 Updating Skia..."
git pull

# Install dependencies
echo "📚 Installing Skia dependencies..."
# Handle SSL certificate issues on macOS
export PYTHONHTTPSVERIFY=0
python3 tools/git-sync-deps || {
    echo "⚠️  SSL certificate issue detected. Trying with certifi..."
    python3 -m pip install --upgrade certifi || true
    python3 tools/git-sync-deps
}
unset PYTHONHTTPSVERIFY

# Build for iOS (arm64 - devices)
echo "🔨 Building Skia for iOS (arm64)..."
bin/gn gen out/ios-arm64 --args='
  target_os="ios"
  target_cpu="arm64"
  skia_use_metal=true
  skia_use_gl=false
  extra_cflags=["-fembed-bitcode"]
  is_debug=false
'

# Build only the library, skip example apps that require code signing
ninja -C out/ios-arm64 libskia.a

# Build for iOS Simulator
# On Apple Silicon: use arm64 for simulator (but with simulator SDK)
# On Intel: use x64 for simulator
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  echo "🔨 Building Skia for iOS Simulator (arm64)..."
  bin/gn gen out/ios-simulator-arm64 --args='
    target_os="ios"
    target_cpu="arm64"
    skia_use_metal=true
    skia_use_gl=false
    extra_cflags=["-fembed-bitcode", "-mios-simulator-version-min=13.5"]
    is_debug=false
  '
  # Build only the library, skip example apps that require code signing
  ninja -C out/ios-simulator-arm64 libskia.a
  SIMULATOR_LIB="out/ios-simulator-arm64/libskia.a"
else
  echo "🔨 Building Skia for iOS Simulator (x64)..."
  bin/gn gen out/ios-x64 --args='
    target_os="ios"
    target_cpu="x64"
    skia_use_metal=true
    skia_use_gl=false
    extra_cflags=["-fembed-bitcode", "-mios-simulator-version-min=13.5"]
    is_debug=false
  '
  # Build only the library, skip example apps that require code signing
  ninja -C out/ios-x64 libskia.a
  SIMULATOR_LIB="out/ios-x64/libskia.a"
fi

# Copy headers
echo "📋 Copying Skia headers..."
cp -r out/ios-arm64/gen/include/* "$SKIA_DIR/include/" 2>/dev/null || true
cp -r include/* "$SKIA_DIR/include/" 2>/dev/null || true

# Create universal library
echo "🔗 Creating universal library..."
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  # On Apple Silicon: simulator uses same arm64 as device, so just copy device library
  # The simulator can run device binaries directly
  echo "📦 On Apple Silicon: Using device library for both device and simulator"
  cp out/ios-arm64/libskia.a "$SKIA_DIR/lib/libskia.a"
else
  # On Intel: combine device arm64 + simulator x64
  lipo -create \
    out/ios-arm64/libskia.a \
    "$SIMULATOR_LIB" \
    -output "$SKIA_DIR/lib/libskia.a"
fi

echo "✅ Skia setup complete!"
echo "📁 Skia installed at: $SKIA_DIR"
echo "📚 Headers: $SKIA_DIR/include"
echo "📦 Library: $SKIA_DIR/lib/libskia.a"

