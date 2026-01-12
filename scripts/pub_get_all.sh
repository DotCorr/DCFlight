#!/bin/bash
# Run flutter pub get in root and all packages
# Like large Flutter projects - one command installs everything

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📦 Installing dependencies for entire workspace..."
echo ""

# Run pub get at root first
echo "🔧 Root workspace..."
cd "$WORKSPACE_ROOT"
flutter pub get
echo ""

# Find all packages and run pub get
echo "📦 Installing dependencies in all packages..."
find "$WORKSPACE_ROOT/packages" -name "pubspec.yaml" -type f | while read pubspec; do
    package_dir=$(dirname "$pubspec")
    package_name=$(basename "$package_dir")
    
    # Skip if this is the root
    if [ "$package_dir" = "$WORKSPACE_ROOT" ]; then
        continue
    fi
    
    echo "  📦 $package_name..."
    cd "$package_dir"
    flutter pub get > /dev/null 2>&1 || flutter pub get
done

# Also check cli
if [ -f "$WORKSPACE_ROOT/cli/pubspec.yaml" ]; then
    echo "  📦 cli..."
    cd "$WORKSPACE_ROOT/cli"
    flutter pub get > /dev/null 2>&1 || dart pub get
fi

echo ""
echo "✅ All dependencies installed!"



