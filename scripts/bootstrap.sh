#!/bin/bash
# Bootstrap workspace - sync dependencies and install everything
# Run this once at root: ./scripts/bootstrap.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$WORKSPACE_ROOT"

echo "🚀 Bootstrapping DCFlight workspace..."
echo ""

# Step 1: Sync workspace dependencies
echo "🔄 Syncing workspace dependencies..."
dart run scripts/sync_workspace_deps.dart

echo ""
echo "✅ Workspace ready! All packages have dependencies synced and installed."
echo ""
echo "💡 Tip: Run 'dart run scripts/sync_workspace_deps.dart' whenever you add new packages"



