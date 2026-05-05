/**
 * DCFlight Inspector — MCP Server
 *
 * Exposes device control and screenshot tools to AI agents via the
 * Model Context Protocol (stdio transport). Run with:
 *   node dist/mcp.js
 *
 * The Inspector HTTP server must be running on localhost:7070.
 * MCP tools call it over HTTP so they can be used independently
 * of whether the web UI is open.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import {
  listDevices, takeScreenshot, tap, swipe, typeText,
  getLogs, pressBack, pressHome, launchApp,
} from './devices.js';

const server = new Server(
  { name: 'dcflight-inspector', version: '0.1.0' },
  { capabilities: { tools: {} } }
);

const TOOLS: Tool[] = [
  {
    name: 'list_devices',
    description: 'List all connected iOS simulators and Android devices',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'take_screenshot',
    description: 'Capture a screenshot from a device. Returns base64 PNG.',
    inputSchema: {
      type: 'object',
      required: ['deviceId', 'platform'],
      properties: {
        deviceId: { type: 'string', description: 'Device ID from list_devices' },
        platform: { type: 'string', enum: ['ios', 'android'] },
      },
    },
  },
  {
    name: 'tap',
    description: 'Tap at (x, y) screen coordinates on a device',
    inputSchema: {
      type: 'object',
      required: ['deviceId', 'platform', 'x', 'y'],
      properties: {
        deviceId: { type: 'string' },
        platform: { type: 'string', enum: ['ios', 'android'] },
        x: { type: 'number', description: 'X coordinate in points/pixels' },
        y: { type: 'number', description: 'Y coordinate in points/pixels' },
      },
    },
  },
  {
    name: 'swipe',
    description: 'Perform a swipe gesture from (x1,y1) to (x2,y2)',
    inputSchema: {
      type: 'object',
      required: ['deviceId', 'platform', 'x1', 'y1', 'x2', 'y2'],
      properties: {
        deviceId: { type: 'string' },
        platform: { type: 'string', enum: ['ios', 'android'] },
        x1: { type: 'number' }, y1: { type: 'number' },
        x2: { type: 'number' }, y2: { type: 'number' },
        duration: { type: 'number', description: 'Duration in milliseconds (default: 300)' },
      },
    },
  },
  {
    name: 'type_text',
    description: 'Type text into the currently focused input on a device',
    inputSchema: {
      type: 'object',
      required: ['deviceId', 'platform', 'text'],
      properties: {
        deviceId: { type: 'string' },
        platform: { type: 'string', enum: ['ios', 'android'] },
        text: { type: 'string' },
      },
    },
  },
  {
    name: 'get_logs',
    description: 'Get recent DCFlight/Flutter logs from a device',
    inputSchema: {
      type: 'object',
      required: ['deviceId', 'platform'],
      properties: {
        deviceId: { type: 'string' },
        platform: { type: 'string', enum: ['ios', 'android'] },
        lines: { type: 'number', description: 'Number of log lines to return (default: 100)' },
      },
    },
  },
  {
    name: 'press_back',
    description: 'Press the back button (Android only)',
    inputSchema: {
      type: 'object',
      required: ['deviceId'],
      properties: { deviceId: { type: 'string' } },
    },
  },
  {
    name: 'press_home',
    description: 'Press the home button',
    inputSchema: {
      type: 'object',
      required: ['deviceId', 'platform'],
      properties: {
        deviceId: { type: 'string' },
        platform: { type: 'string', enum: ['ios', 'android'] },
      },
    },
  },
  {
    name: 'launch_app',
    description: 'Launch an app by bundle ID / package name',
    inputSchema: {
      type: 'object',
      required: ['deviceId', 'platform', 'bundleId'],
      properties: {
        deviceId: { type: 'string' },
        platform: { type: 'string', enum: ['ios', 'android'] },
        bundleId: { type: 'string', description: 'iOS bundle ID or Android package name' },
      },
    },
  },
];

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const a = (args ?? {}) as Record<string, unknown>;

  try {
    switch (name) {
      case 'list_devices': {
        const devices = await listDevices();
        return { content: [{ type: 'text', text: JSON.stringify(devices, null, 2) }] };
      }

      case 'take_screenshot': {
        const base64 = await takeScreenshot(a.deviceId as string, a.platform as 'ios' | 'android');
        return {
          content: [
            { type: 'text', text: `Screenshot captured (${base64.length} bytes base64)` },
            { type: 'image', data: base64, mimeType: 'image/png' },
          ],
        };
      }

      case 'tap': {
        await tap(a.deviceId as string, a.platform as 'ios' | 'android', a.x as number, a.y as number);
        return { content: [{ type: 'text', text: `Tapped at (${a.x}, ${a.y})` }] };
      }

      case 'swipe': {
        await swipe(
          a.deviceId as string, a.platform as 'ios' | 'android',
          a.x1 as number, a.y1 as number, a.x2 as number, a.y2 as number,
          a.duration as number | undefined
        );
        return { content: [{ type: 'text', text: `Swiped from (${a.x1},${a.y1}) to (${a.x2},${a.y2})` }] };
      }

      case 'type_text': {
        await typeText(a.deviceId as string, a.platform as 'ios' | 'android', a.text as string);
        return { content: [{ type: 'text', text: `Typed: "${a.text}"` }] };
      }

      case 'get_logs': {
        const logs = await getLogs(a.deviceId as string, a.platform as 'ios' | 'android', a.lines as number | undefined);
        return { content: [{ type: 'text', text: logs }] };
      }

      case 'press_back': {
        await pressBack(a.deviceId as string);
        return { content: [{ type: 'text', text: 'Back pressed' }] };
      }

      case 'press_home': {
        await pressHome(a.deviceId as string, a.platform as 'ios' | 'android');
        return { content: [{ type: 'text', text: 'Home pressed' }] };
      }

      case 'launch_app': {
        await launchApp(a.deviceId as string, a.platform as 'ios' | 'android', a.bundleId as string);
        return { content: [{ type: 'text', text: `Launched ${a.bundleId}` }] };
      }

      default:
        return { content: [{ type: 'text', text: `Unknown tool: ${name}` }], isError: true };
    }
  } catch (err) {
    return { content: [{ type: 'text', text: `Error: ${String(err)}` }], isError: true };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
