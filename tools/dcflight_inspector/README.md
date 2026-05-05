# DCFlight Inspector

Live UI automation and iterative development tool for DCFlight apps. Connects to iOS simulators and Android devices to capture screenshots, send interactions, and stream logs — all from a browser UI or AI agent via MCP.

**Status: ALPHA**

---

## Quick Start

```bash
cd tools/dcflight_inspector
chmod +x start.sh
./start.sh
```

Open **http://localhost:7070** in your browser.

---

## Features

- **Screenshot capture** — live screenshots from any connected simulator or physical device
- **Click-to-tap** — click the screenshot image to tap at that exact position
- **Auto-refresh** — 3-second interval auto-screenshot for live iteration
- **Swipe & scroll** — send swipe gestures with configurable coordinates
- **Type text** — type into the focused input field
- **Live log streaming** — WebSocket log stream filtered to DCFlight/Flutter output
- **App launcher** — launch any installed app by bundle ID / package name

---

## MCP Server (for AI agents)

The MCP server runs as a stdio process and exposes all device actions as tools.

### Add to VS Code Copilot / Claude Desktop

```json
{
  "mcpServers": {
    "dcflight-inspector": {
      "command": "node",
      "args": ["/path/to/DCFlight/tools/dcflight_inspector/server/dist/mcp.js"]
    }
  }
}
```

Build first: `cd server && npm install && npm run build`

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `list_devices` | List connected simulators and devices |
| `take_screenshot` | Capture screenshot, returns base64 PNG |
| `tap` | Tap at (x, y) |
| `swipe` | Swipe from (x1,y1) to (x2,y2) |
| `type_text` | Type text into focused input |
| `get_logs` | Get recent DCFlight/Flutter logs |
| `press_back` | Android back button |
| `press_home` | Home button |
| `launch_app` | Launch by bundle ID / package |

---

## Requirements

- **macOS** (for iOS simulator support)
- **Xcode** (for `xcrun simctl`)
- **ADB** at `/opt/homebrew/bin/adb` (for Android; adjust path in `devices.ts` if different)
- **Node.js** ≥ 18

---

## Architecture

```
web/              ← Vanilla JS single-page UI (served by the server)
server/
  src/
    index.ts      ← Express HTTP server + WebSocket log streaming
    devices.ts    ← Device discovery, screenshot, interact, log helpers
    mcp.ts        ← MCP stdio server
```

---

## Iterative Development Workflow

1. Start the inspector: `./start.sh`
2. Boot your simulator or connect your device
3. Run your DCFlight app: `flutter run -d <device>`
4. Open http://localhost:7070 — select the device, click Screenshot
5. Enable "Click image to tap" for interactive exploration
6. Watch the log panel for DCFlight bridge output
7. Edit code → hot-reload → auto-screenshot picks up changes

With the MCP server, your AI agent can:
- Take a screenshot after every code change
- Identify layout issues (overflows, font sizes, colour contrast)
- Make targeted taps to test interactions
- Read logs to understand what the bridge is doing
- Propose and apply fixes iteratively
