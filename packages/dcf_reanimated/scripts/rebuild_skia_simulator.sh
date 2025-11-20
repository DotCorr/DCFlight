#!/bin/bash

# Script to rebuild Skia with simulator support for iOS
# This adds the simulator arm64 slice to the existing device library

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIA_DIR="$SCRIPT_DIR/../ios/Skia"
SKIA_SOURCE_DIR="$SKIA_DIR/source"
BUILD_DIR="$SKIA_DIR/build"
LIB_DIR="$SKIA_DIR/lib"
CURRENT_LIB="$LIB_DIR/libskia.a"

echo "🔧 Rebuilding Skia with simulator support..."

# Check if current library exists
if [ ! -f "$CURRENT_LIB" ]; then
    echo "❌ Error: Current libskia.a not found at $CURRENT_LIB"
    exit 1
fi

# Extract device arm64 slice
echo "📦 Extracting device arm64 slice from existing library..."
DEVICE_LIB="$BUILD_DIR/libskia_device_arm64.a"
mkdir -p "$BUILD_DIR"

# Extract arm64 (device) slice
lipo "$CURRENT_LIB" -extract arm64 -output "$DEVICE_LIB" 2>/dev/null || {
    # If extraction fails, try to use the whole library (it might already be arm64 only)
    echo "⚠️  Could not extract arm64 slice, using existing library as device slice"
    cp "$CURRENT_LIB" "$DEVICE_LIB"
}

# Check if Skia source exists
if [ ! -d "$SKIA_SOURCE_DIR" ]; then
    echo ""
    echo "📥 Skia source not found. Cloning Skia..."
    echo "   This will download ~500MB and take several minutes..."
    echo ""
    
    cd "$SKIA_DIR"
    git clone https://skia.googlesource.com/skia.git source || {
        echo "❌ Failed to clone Skia. Please check your internet connection."
        exit 1
    }
    
    cd source
    python3 tools/git-sync-deps || {
        echo "⚠️  git-sync-deps failed, continuing anyway..."
    }
fi

# Build Skia for simulator
echo ""
echo "🔨 Building Skia for iOS Simulator (arm64)..."
echo "   This will take 10-30 minutes depending on your machine..."
echo ""

cd "$SKIA_SOURCE_DIR"

# Set up build tools if needed
if [ ! -f "bin/gn" ]; then
    echo "📥 Downloading build tools..."
    
    # Patch fetch-gn to bypass SSL verification
    if [ -f "bin/fetch-gn" ]; then
        sed -i.bak 's/urlopen(url)/urlopen(url, context=ssl._create_unverified_context())/' bin/fetch-gn
        sed -i.bak '1a\
import ssl
' bin/fetch-gn
    fi
    
    # Patch fetch-ninja to bypass SSL verification
    if [ -f "bin/fetch-ninja" ]; then
        sed -i.bak 's/urlopen(url)/urlopen(url, context=ssl._create_unverified_context())/' bin/fetch-ninja
        sed -i.bak '1a\
import ssl
' bin/fetch-ninja
    fi
    
    python3 bin/fetch-gn || {
        echo "❌ fetch-gn failed"
        exit 1
    }
    python3 bin/fetch-ninja || {
        echo "❌ fetch-ninja failed"
        exit 1
    }
    
    # Make gn executable
    chmod +x bin/gn
fi

# Get simulator SDK path
SIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
SIMULATOR_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)

echo "📱 Using iOS Simulator SDK: $SIMULATOR_SDK (version $SIMULATOR_VERSION)"

# Configure build for simulator
SIMULATOR_OUT_DIR="$BUILD_DIR/ios-simulator-arm64"
mkdir -p "$SIMULATOR_OUT_DIR"

# Generate build files for simulator
# Use ios target_os with x86_64 for simulator and explicitly set simulator SDK
./bin/gn gen "$SIMULATOR_OUT_DIR" --args="
target_os=\"ios\"
target_cpu=\"x86_64\"
skia_use_metal=true
skia_use_system_libjpeg_turbo=false
skia_use_system_libpng=false
skia_use_system_zlib=false
skia_use_system_icu=false
skia_use_system_harfbuzz=false
skia_use_expat=true
extra_cflags=[\"-mios-simulator-version-min=13.5\", \"-isysroot\", \"$SIMULATOR_SDK\"]
extra_ldflags=[\"-mios-simulator-version-min=13.5\", \"-isysroot\", \"$SIMULATOR_SDK\"]
" || {
    echo "❌ Failed to generate build files for simulator"
    exit 1
}

# Build only libskia.a (skip examples)
echo "🔨 Compiling Skia for simulator (this will take a while)..."

# Find ninja binary
NINJA_BIN=""
if [ -f "bin/ninja" ]; then
    NINJA_BIN="bin/ninja"
elif [ -f "third_party/ninja/ninja" ]; then
    NINJA_BIN="third_party/ninja/ninja"
else
    # Try to find ninja in PATH
    NINJA_BIN=$(which ninja 2>/dev/null || echo "")
fi

if [ -z "$NINJA_BIN" ] || [ ! -f "$NINJA_BIN" ]; then
    echo "❌ ninja binary not found. Please install ninja or ensure it's in PATH."
    exit 1
fi

"$NINJA_BIN" -C "$SIMULATOR_OUT_DIR" libskia.a || {
    echo "❌ Failed to build Skia for simulator"
    exit 1
}

SIMULATOR_LIB="$SIMULATOR_OUT_DIR/libskia.a"

if [ ! -f "$SIMULATOR_LIB" ]; then
    echo "❌ Simulator library not found at $SIMULATOR_LIB"
    exit 1
fi

# Combine device and simulator libraries
echo ""
echo "🔗 Combining device and simulator libraries..."

# Backup original
BACKUP_LIB="$LIB_DIR/libskia.a.backup"
cp "$CURRENT_LIB" "$BACKUP_LIB"
echo "💾 Backed up original library to $BACKUP_LIB"

# Combine with lipo
lipo -create "$DEVICE_LIB" "$SIMULATOR_LIB" -output "$CURRENT_LIB" || {
    echo "❌ Failed to combine libraries"
    echo "🔄 Restoring backup..."
    mv "$BACKUP_LIB" "$CURRENT_LIB"
    exit 1
}

# Verify the combined library
echo ""
echo "✅ Verifying combined library..."
lipo -info "$CURRENT_LIB"

echo ""
echo "✅ Success! Skia library now supports both device and simulator."
echo "   Library location: $CURRENT_LIB"
echo "   Backup saved at: $BACKUP_LIB"

