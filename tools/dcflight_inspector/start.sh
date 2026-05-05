#!/usr/bin/env bash
# DCFlight Inspector — launcher
# Usage: ./start.sh [--port 7070]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/server"
PORT="${PORT:-7070}"

echo ""
echo "  DCFlight Inspector"
echo "  ──────────────────"
echo ""

# Install deps if needed
if [ ! -d "$SERVER_DIR/node_modules" ]; then
  echo "  Installing dependencies…"
  cd "$SERVER_DIR" && npm install
fi

# Build TypeScript
echo "  Building server…"
cd "$SERVER_DIR" && npm run build

echo "  Starting server on http://localhost:$PORT"
echo "  MCP server: node $SERVER_DIR/dist/mcp.js"
echo ""

PORT=$PORT node "$SERVER_DIR/dist/index.js"
