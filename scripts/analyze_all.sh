#!/bin/bash
# Run dart analyze on all Dart packages in the monorepo.
# Use: ./scripts/analyze_all.sh
# Optional: ./scripts/analyze_all.sh --fix  to run dart fix where applicable

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DO_FIX=false
if [ "${1:-}" = "--fix" ]; then
  DO_FIX=true
fi

echo "🔍 Analyzing all packages in $WORKSPACE_ROOT"
echo ""

# Resolve path dependencies so "package:dcflight" etc. resolve when analyzing
if [ -f "$SCRIPT_DIR/pub_get_all.sh" ]; then
  echo "📦 Resolving dependencies (pub get)..."
  "$SCRIPT_DIR/pub_get_all.sh" >/dev/null 2>&1 || true
  echo ""
fi

FAILED=0

# Run analyze and set FAILED=1 only if output contains analysis *errors* (not warnings/info)
_analyze() {
  local out
  out=$(dart analyze lib 2>&1) || true
  echo "$out"
  if echo "$out" | grep -q "  error -"; then
    return 1
  fi
  return 0
}

# Root (if it has lib/)
if [ -d "$WORKSPACE_ROOT/lib" ] && [ -f "$WORKSPACE_ROOT/pubspec.yaml" ]; then
  echo "📦 Root package..."
  cd "$WORKSPACE_ROOT"
  if $DO_FIX; then dart fix --apply 2>/dev/null || true; fi
  _analyze || FAILED=1
  echo ""
fi

# packages/
for pubspec in "$WORKSPACE_ROOT/packages"/*/pubspec.yaml "$WORKSPACE_ROOT/packages"/*/*/pubspec.yaml; do
  [ -f "$pubspec" ] || continue
  package_dir=$(dirname "$pubspec")
  package_name=$(basename "$package_dir")
  if [ ! -d "$package_dir/lib" ]; then continue; fi
  echo "📦 $package_name..."
  cd "$package_dir"
  if $DO_FIX; then dart fix --apply 2>/dev/null || true; fi
  _analyze || FAILED=1
  echo ""
done

# cli
if [ -f "$WORKSPACE_ROOT/cli/pubspec.yaml" ] && [ -d "$WORKSPACE_ROOT/cli/lib" ]; then
  echo "📦 cli..."
  cd "$WORKSPACE_ROOT/cli"
  if $DO_FIX; then dart fix --apply 2>/dev/null || true; fi
  _analyze || FAILED=1
  echo ""
fi

if [ $FAILED -eq 1 ]; then
  echo "❌ Some packages had analysis errors."
  exit 1
fi

echo "✅ All packages analyzed (no errors)."
