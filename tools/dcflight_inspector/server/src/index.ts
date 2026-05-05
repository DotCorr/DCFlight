import express, { Request, Response } from 'express';
import { WebSocketServer, WebSocket } from 'ws';
import { createServer } from 'http';
import cors from 'cors';
import {
  listDevices, takeScreenshot, tap, swipe, typeText,
  getLogs, pressBack, pressHome, launchApp, startLogStream, Device
} from './devices.js';

const app = express();
app.use(cors());
app.use(express.json());

// Serve web UI from ../web/
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEB_DIR = path.join(__dirname, '..', '..', 'web');
app.use(express.static(WEB_DIR));

// --- REST API ---

app.get('/api/devices', async (_req: Request, res: Response) => {
  try {
    const devices = await listDevices();
    res.json({ devices });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.post('/api/screenshot', async (req: Request, res: Response) => {
  const { deviceId, platform, quality } = req.body as { deviceId: string; platform: 'ios' | 'android'; quality?: number };
  try {
    const base64 = await takeScreenshot(deviceId, platform, quality ?? 80);
    res.json({ screenshot: base64, mimeType: 'image/jpeg' });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.post('/api/tap', async (req: Request, res: Response) => {
  const { deviceId, platform, x, y } = req.body as { deviceId: string; platform: 'ios' | 'android'; x: number; y: number };
  try {
    await tap(deviceId, platform, x, y);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.post('/api/swipe', async (req: Request, res: Response) => {
  const { deviceId, platform, x1, y1, x2, y2, duration } = req.body as {
    deviceId: string; platform: 'ios' | 'android';
    x1: number; y1: number; x2: number; y2: number; duration?: number;
  };
  try {
    await swipe(deviceId, platform, x1, y1, x2, y2, duration);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.post('/api/type', async (req: Request, res: Response) => {
  const { deviceId, platform, text } = req.body as { deviceId: string; platform: 'ios' | 'android'; text: string };
  try {
    await typeText(deviceId, platform, text);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.post('/api/back', async (req: Request, res: Response) => {
  const { deviceId } = req.body as { deviceId: string };
  try {
    await pressBack(deviceId);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.post('/api/home', async (req: Request, res: Response) => {
  const { deviceId, platform } = req.body as { deviceId: string; platform: 'ios' | 'android' };
  try {
    await pressHome(deviceId, platform);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.post('/api/launch', async (req: Request, res: Response) => {
  const { deviceId, platform, bundleId } = req.body as {
    deviceId: string; platform: 'ios' | 'android'; bundleId: string;
  };
  try {
    await launchApp(deviceId, platform, bundleId);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.get('/api/logs', async (req: Request, res: Response) => {
  const { deviceId, platform, lines } = req.query as { deviceId: string; platform: 'ios' | 'android'; lines?: string };
  try {
    const logs = await getLogs(deviceId, platform, lines ? parseInt(lines) : 100);
    res.json({ logs });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

// --- HTTP + WebSocket Server ---

const server = createServer(app);
const wss = new WebSocketServer({ server });

// Track active log streams per client
const activeStreams = new Map<WebSocket, () => void>();

wss.on('connection', (ws: WebSocket) => {
  console.log('[Inspector] WebSocket client connected');

  ws.on('message', (raw: Buffer) => {
    let msg: { type: string; deviceId?: string; platform?: string };
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }

    if (msg.type === 'start_logs' && msg.deviceId && msg.platform) {
      // Stop any existing stream for this client
      const existing = activeStreams.get(ws);
      if (existing) existing();

      const stop = startLogStream(
        msg.deviceId,
        msg.platform as 'ios' | 'android',
        (line) => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'log', line }));
          }
        },
        (err) => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'log_error', error: err }));
          }
        }
      );
      activeStreams.set(ws, stop);
    }

    if (msg.type === 'stop_logs') {
      const stop = activeStreams.get(ws);
      if (stop) { stop(); activeStreams.delete(ws); }
    }
  });

  ws.on('close', () => {
    const stop = activeStreams.get(ws);
    if (stop) { stop(); activeStreams.delete(ws); }
    console.log('[Inspector] WebSocket client disconnected');
  });
});

const PORT = process.env.PORT ? parseInt(process.env.PORT) : 7070;
server.listen(PORT, () => {
  console.log(`\n  DCFlight Inspector running at http://localhost:${PORT}\n`);
  console.log(`  Web UI:  http://localhost:${PORT}`);
  console.log(`  MCP:     stdio (run: node dist/mcp.js)\n`);
});
