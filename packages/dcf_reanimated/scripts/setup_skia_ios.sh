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

# Check if Skia is already built
if [ -f "$SKIA_DIR/lib/libskia.a" ] && [ -d "$SKIA_DIR/include" ]; then
    echo "✅ Skia already built! Library found at $SKIA_DIR/lib/libskia.a"
    echo "📦 Using pre-built Skia (no building needed)"
    exit 0
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
  skia_enable_gpu=true
  extra_cflags=["-fembed-bitcode"]
  is_debug=false
'

ninja -C out/ios-arm64

# Build for iOS Simulator (x64)
echo "🔨 Building Skia for iOS Simulator (x64)..."
bin/gn gen out/ios-x64 --args='
  target_os="ios"
  target_cpu="x64"
  skia_use_metal=true
  skia_use_gl=false
  skia_enable_gpu=true
  extra_cflags=["-fembed-bitcode"]
  is_debug=false
'

ninja -C out/ios-x64

# Copy headers
echo "📋 Copying Skia headers..."
cp -r out/ios-arm64/gen/include/* "$SKIA_DIR/include/" 2>/dev/null || true
cp -r include/* "$SKIA_DIR/include/" 2>/dev/null || true

# Create universal library (arm64 + x64)
echo "🔗 Creating universal library..."
lipo -create \
  out/ios-arm64/libskia.a \
  out/ios-x64/libskia.a \
  -output "$SKIA_DIR/lib/libskia.a"

echo "✅ Skia setup complete!"
echo "📁 Skia installed at: $SKIA_DIR"
echo "📚 Headers: $SKIA_DIR/include"
echo "📦 Library: $SKIA_DIR/lib/libskia.a"

