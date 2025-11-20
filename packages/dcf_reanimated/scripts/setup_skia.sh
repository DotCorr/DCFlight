#!/bin/bash

# Main Skia setup script
# Runs platform-specific setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🎨 Skia Setup for DCF Reanimated"
echo "================================"

# Check platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Detected macOS - checking iOS Skia..."
    bash "$SCRIPT_DIR/setup_skia_ios.sh"
    
    if [ -f "$PACKAGE_DIR/ios/Skia/lib/libskia.a" ]; then
        echo ""
        echo "✅ Skia ready! Using pre-built library (2GB)"
        echo "📦 Developers don't need to build - library is committed to repo"
    fi
else
    echo "🤖 Android Skia is built-in - no setup needed!"
    echo "✅ Android uses Skia via android.graphics.Canvas"
fi

echo ""
echo "Next steps:"
echo "1. Run 'pod install' in your iOS project"
echo "2. Build and run your app"

