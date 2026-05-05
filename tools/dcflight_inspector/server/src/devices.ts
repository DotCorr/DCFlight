import { exec, spawn } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export interface Device {
  id: string;
  name: string;
  platform: 'ios' | 'android';
  type: 'simulator' | 'physical';
  state?: string;
  osVersion?: string;
}

export async function listDevices(): Promise<Device[]> {
  const devices: Device[] = [];

  // iOS Simulators
  try {
    const { stdout } = await execAsync('xcrun simctl list devices --json');
    const data = JSON.parse(stdout) as {
      devices: Record<string, Array<{ udid: string; name: string; state: string }>>;
    };
    for (const [runtime, sims] of Object.entries(data.devices)) {
      const osVersion = runtime.replace(/.*iOS-(\d+)-(\d+).*/, '$1.$2');
      for (const sim of sims) {
        if (sim.state === 'Booted') {
          devices.push({
            id: sim.udid,
            name: `${sim.name} (iOS ${osVersion})`,
            platform: 'ios',
            type: 'simulator',
            state: sim.state,
            osVersion,
          });
        }
      }
    }
  } catch {
    // xcrun not available or no simulators
  }

  // Android devices/emulators via adb
  const adbPath = '/opt/homebrew/bin/adb';
  try {
    const { stdout } = await execAsync(`${adbPath} devices -l`);
    const lines = stdout.trim().split('\n').slice(1); // skip "List of devices attached"
    for (const line of lines) {
      if (!line.trim() || line.includes('offline')) continue;
      const parts = line.trim().split(/\s+/);
      const id = parts[0];
      const state = parts[1];
      if (state !== 'device') continue;

      // Extract model from device info
      const modelMatch = line.match(/model:(\S+)/);
      const productMatch = line.match(/product:(\S+)/);
      const name = modelMatch ? modelMatch[1].replace(/_/g, ' ') : (productMatch ? productMatch[1] : id);
      const isEmulator = id.startsWith('emulator-');

      devices.push({
        id,
        name: `${name} (Android)`,
        platform: 'android',
        type: isEmulator ? 'simulator' : 'physical',
        state,
      });
    }
  } catch {
    // adb not available
  }

  return devices;
}

export async function takeScreenshot(deviceId: string, platform: 'ios' | 'android', quality: number = 80): Promise<string> {
  const tmpPng = `/tmp/dcfinspector_screenshot_${Date.now()}.png`;
  const tmpJpg = `/tmp/dcfinspector_screenshot_${Date.now()}.jpg`;

  if (platform === 'ios') {
    await execAsync(`xcrun simctl io "${deviceId}" screenshot "${tmpPng}"`);
  } else {
    const adbPath = '/opt/homebrew/bin/adb';
    const deviceTmpPath = '/sdcard/dcfinspector_ss.png';
    // Capture to device storage then pull — avoids exec-out buffer limits
    await execAsync(`${adbPath} -s "${deviceId}" shell screencap -p "${deviceTmpPath}"`);
    await execAsync(`${adbPath} -s "${deviceId}" pull "${deviceTmpPath}" "${tmpPng}"`, { maxBuffer: 50 * 1024 * 1024 });
    await execAsync(`${adbPath} -s "${deviceId}" shell rm -f "${deviceTmpPath}"`);
  }

  // Convert to JPEG for drastically smaller transfer size (PNG → JPEG 80%)
  try {
    await execAsync(`sips -s format jpeg -s formatOptions ${quality} "${tmpPng}" --out "${tmpJpg}"`);
    const { stdout } = await execAsync(`base64 < "${tmpJpg}"`, { maxBuffer: 50 * 1024 * 1024 });
    await execAsync(`rm -f "${tmpPng}" "${tmpJpg}"`);
    return stdout.trim();
  } catch {
    // sips not available; fall back to PNG
    const { stdout } = await execAsync(`base64 < "${tmpPng}"`, { maxBuffer: 50 * 1024 * 1024 });
    await execAsync(`rm -f "${tmpPng}"`);
    return stdout.trim();
  }
}

export async function tap(deviceId: string, platform: 'ios' | 'android', x: number, y: number): Promise<void> {
  if (platform === 'ios') {
    // xcrun simctl io tap requires Xcode 15+; fall back to xdotool-style via simctl
    await execAsync(`xcrun simctl io "${deviceId}" tap ${Math.round(x)} ${Math.round(y)}`);
  } else {
    const adbPath = '/opt/homebrew/bin/adb';
    await execAsync(`${adbPath} -s "${deviceId}" shell input tap ${Math.round(x)} ${Math.round(y)}`);
  }
}

export async function swipe(
  deviceId: string,
  platform: 'ios' | 'android',
  x1: number, y1: number,
  x2: number, y2: number,
  durationMs: number = 300
): Promise<void> {
  if (platform === 'ios') {
    await execAsync(
      `xcrun simctl io "${deviceId}" swipe ${Math.round(x1)} ${Math.round(y1)} ${Math.round(x2)} ${Math.round(y2)} ${durationMs}`
    );
  } else {
    const adbPath = '/opt/homebrew/bin/adb';
    await execAsync(
      `${adbPath} -s "${deviceId}" shell input swipe ${Math.round(x1)} ${Math.round(y1)} ${Math.round(x2)} ${Math.round(y2)} ${durationMs}`
    );
  }
}

export async function typeText(deviceId: string, platform: 'ios' | 'android', text: string): Promise<void> {
  if (platform === 'ios') {
    const escaped = text.replace(/'/g, "\\'");
    await execAsync(`xcrun simctl io "${deviceId}" type '${escaped}'`);
  } else {
    const adbPath = '/opt/homebrew/bin/adb';
    // ADB input text doesn't handle spaces well; use key events for space
    const escaped = text.replace(/ /g, '%s');
    await execAsync(`${adbPath} -s "${deviceId}" shell input text '${escaped}'`);
  }
}

export async function getLogs(deviceId: string, platform: 'ios' | 'android', lines: number = 100): Promise<string> {
  if (platform === 'ios') {
    // Get recent logs from booted simulator
    const { stdout } = await execAsync(
      `xcrun simctl spawn booted log show --predicate 'subsystem contains "com.dotcorr"' --last 1m 2>/dev/null | tail -${lines}`
    ).catch(() => execAsync(`xcrun simctl spawn "${deviceId}" log show --last 30s 2>/dev/null | tail -${lines}`));
    return stdout;
  } else {
    const adbPath = '/opt/homebrew/bin/adb';
    const { stdout } = await execAsync(
      `${adbPath} -s "${deviceId}" logcat -d -t ${lines} "*:S" DCFlightNative:V DCFlightJni:V DCFTextComponent:V flutter:V 2>&1`
    ).catch(() => execAsync(`${adbPath} -s "${deviceId}" logcat -d | tail -${lines}`));
    return stdout;
  }
}

export async function pressBack(deviceId: string): Promise<void> {
  const adbPath = '/opt/homebrew/bin/adb';
  await execAsync(`${adbPath} -s "${deviceId}" shell input keyevent KEYCODE_BACK`);
}

export async function pressHome(deviceId: string, platform: 'ios' | 'android'): Promise<void> {
  if (platform === 'ios') {
    await execAsync(`xcrun simctl io "${deviceId}" keyevent home`);
  } else {
    const adbPath = '/opt/homebrew/bin/adb';
    await execAsync(`${adbPath} -s "${deviceId}" shell input keyevent KEYCODE_HOME`);
  }
}

export async function launchApp(deviceId: string, platform: 'ios' | 'android', bundleId: string): Promise<void> {
  if (platform === 'ios') {
    await execAsync(`xcrun simctl launch "${deviceId}" "${bundleId}"`);
  } else {
    const adbPath = '/opt/homebrew/bin/adb';
    await execAsync(`${adbPath} -s "${deviceId}" shell monkey -p "${bundleId}" -c android.intent.category.LAUNCHER 1`);
  }
}

export function startLogStream(
  deviceId: string,
  platform: 'ios' | 'android',
  onData: (line: string) => void,
  onError?: (err: string) => void
): () => void {
  let proc: ReturnType<typeof spawn>;

  if (platform === 'ios') {
    proc = spawn('xcrun', [
      'simctl', 'spawn', deviceId, 'log', 'stream',
      '--predicate', 'subsystem CONTAINS "com.dotcorr" OR category CONTAINS "Flutter"',
      '--style', 'compact',
    ]);
  } else {
    proc = spawn('/opt/homebrew/bin/adb', [
      '-s', deviceId, 'logcat',
      '-v', 'time',
      'DCFlightNative:V', 'DCFlightJni:V', 'DCFTextComponent:V', 'flutter:V', '*:S',
    ]);
  }

  proc.stdout?.on('data', (data: Buffer) => {
    const lines = data.toString().split('\n');
    for (const line of lines) {
      if (line.trim()) onData(line);
    }
  });

  proc.stderr?.on('data', (data: Buffer) => {
    onError?.(data.toString());
  });

  return () => {
    proc.kill();
  };
}
