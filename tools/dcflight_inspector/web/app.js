// DCFlight Inspector — web UI client

const API = 'http://localhost:7070/api';
const WS_URL = 'ws://localhost:7070';

let selectedDevice = null; // { id, name, platform, type }
let ws = null;
let autoRefreshTimer = null;
let screenshotNaturalSize = { w: 1, h: 1 };

// ---- Device Management ----

async function fetchDevices() {
  const list = document.getElementById('device-list');
  list.innerHTML = '<p class="empty-state">Loading…</p>';
  try {
    const res = await fetch(`${API}/devices`);
    const { devices } = await res.json();
    renderDevices(devices);
  } catch {
    list.innerHTML = '<p class="empty-state" style="color:#cc0000">Server not reachable. Make sure DCFlight Inspector is running.</p>';
  }
}

function renderDevices(devices) {
  const list = document.getElementById('device-list');
  if (!devices.length) {
    list.innerHTML = '<p class="empty-state">No devices found.<br>Boot a simulator or connect a device.</p>';
    return;
  }
  list.innerHTML = '';
  for (const d of devices) {
    const el = document.createElement('div');
    el.className = 'device-item' + (selectedDevice?.id === d.id ? ' selected' : '');
    el.dataset.id = d.id;
    el.innerHTML = `
      <span class="device-icon">${d.platform === 'ios' ? '📱' : '🤖'}</span>
      <div class="device-info">
        <div class="device-name">${d.name}</div>
        <div class="device-meta">${d.type} · ${d.state ?? 'online'}</div>
      </div>`;
    el.addEventListener('click', () => selectDevice(d));
    list.appendChild(el);
  }
}

function selectDevice(device) {
  selectedDevice = device;
  document.getElementById('controls-section').style.display = '';
  // Re-render list to update selection highlight
  document.querySelectorAll('.device-item').forEach(el => {
    el.classList.toggle('selected', el.dataset.id === device.id);
  });
  appendLog(`[Inspector] Selected: ${device.name} (${device.id})`);
}

// ---- Screenshot ----

async function captureScreenshot() {
  if (!selectedDevice) return alert('Select a device first');
  document.getElementById('screenshot-info').textContent = 'Capturing…';
  try {
    const res = await fetch(`${API}/screenshot`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: selectedDevice.id, platform: selectedDevice.platform }),
    });
    const { screenshot, error } = await res.json();
    if (error) { appendLog(`[Error] ${error}`, 'error'); return; }

    const img = document.getElementById('screenshot-img');
    const placeholder = document.getElementById('screenshot-placeholder');
    img.src = `data:image/png;base64,${screenshot}`;
    img.style.display = 'block';
    placeholder.style.display = 'none';

    img.onload = () => {
      screenshotNaturalSize = { w: img.naturalWidth, h: img.naturalHeight };
      document.getElementById('screenshot-info').textContent =
        `${screenshotNaturalSize.w}×${screenshotNaturalSize.h}  ·  ${new Date().toLocaleTimeString()}`;
    };
  } catch (e) {
    appendLog(`[Error] Screenshot failed: ${e}`, 'error');
  }
}

// Click-to-tap overlay
document.getElementById('screenshot-img').addEventListener('click', async (e) => {
  if (!document.getElementById('chk-click-to-tap').checked) return;
  if (!selectedDevice) return;

  const img = e.currentTarget;
  const rect = img.getBoundingClientRect();
  const relX = (e.clientX - rect.left) / rect.width;
  const relY = (e.clientY - rect.top) / rect.height;
  const tapX = Math.round(relX * screenshotNaturalSize.w);
  const tapY = Math.round(relY * screenshotNaturalSize.h);

  appendLog(`[Tap] (${tapX}, ${tapY})`);
  drawTapIndicator(e.clientX - rect.left, e.clientY - rect.top, rect.width, rect.height);

  try {
    await fetch(`${API}/tap`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: selectedDevice.id, platform: selectedDevice.platform, x: tapX, y: tapY }),
    });
    // Auto-capture after tap
    setTimeout(captureScreenshot, 400);
  } catch (e) {
    appendLog(`[Error] Tap failed: ${e}`, 'error');
  }
});

function drawTapIndicator(cx, cy, w, h) {
  const canvas = document.getElementById('tap-overlay');
  canvas.style.display = 'block';
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, w, h);
  ctx.beginPath();
  ctx.arc(cx, cy, 20, 0, Math.PI * 2);
  ctx.strokeStyle = '#000';
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(cx, cy, 4, 0, Math.PI * 2);
  ctx.fillStyle = '#000';
  ctx.fill();
  setTimeout(() => {
    ctx.clearRect(0, 0, w, h);
    canvas.style.display = 'none';
  }, 600);
}

// Auto-refresh
document.getElementById('btn-auto-refresh').addEventListener('click', function() {
  const active = this.dataset.active === 'true';
  if (active) {
    clearInterval(autoRefreshTimer);
    autoRefreshTimer = null;
    this.dataset.active = 'false';
    this.textContent = 'Auto-screenshot (3s)';
  } else {
    if (!selectedDevice) { alert('Select a device first'); return; }
    this.dataset.active = 'true';
    this.textContent = 'Stop auto-screenshot';
    autoRefreshTimer = setInterval(captureScreenshot, 3000);
    captureScreenshot();
  }
});

// ---- Action Buttons ----

document.getElementById('btn-screenshot').addEventListener('click', captureScreenshot);

document.getElementById('btn-home').addEventListener('click', async () => {
  if (!selectedDevice) return;
  await fetch(`${API}/home`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: selectedDevice.id, platform: selectedDevice.platform }),
  });
  appendLog('[Action] Home pressed');
});

document.getElementById('btn-back').addEventListener('click', async () => {
  if (!selectedDevice) return;
  await fetch(`${API}/back`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: selectedDevice.id }),
  });
  appendLog('[Action] Back pressed');
});

document.getElementById('btn-launch').addEventListener('click', async () => {
  if (!selectedDevice) return;
  const bundleId = document.getElementById('input-bundle').value.trim();
  if (!bundleId) return;
  await fetch(`${API}/launch`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: selectedDevice.id, platform: selectedDevice.platform, bundleId }),
  });
  appendLog(`[Action] Launched ${bundleId}`);
  setTimeout(captureScreenshot, 1500);
});

document.getElementById('btn-type').addEventListener('click', async () => {
  if (!selectedDevice) return;
  const text = document.getElementById('input-type').value;
  if (!text) return;
  await fetch(`${API}/type`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: selectedDevice.id, platform: selectedDevice.platform, text }),
  });
  appendLog(`[Type] "${text}"`);
});

document.getElementById('btn-tap').addEventListener('click', async () => {
  if (!selectedDevice) return;
  const x = parseInt(document.getElementById('input-tap-x').value);
  const y = parseInt(document.getElementById('input-tap-y').value);
  if (isNaN(x) || isNaN(y)) return;
  await fetch(`${API}/tap`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: selectedDevice.id, platform: selectedDevice.platform, x, y }),
  });
  appendLog(`[Tap] (${x}, ${y})`);
  setTimeout(captureScreenshot, 400);
});

document.getElementById('btn-swipe').addEventListener('click', async () => {
  if (!selectedDevice) return;
  const x1 = parseInt(document.getElementById('sw-x1').value);
  const y1 = parseInt(document.getElementById('sw-y1').value);
  const x2 = parseInt(document.getElementById('sw-x2').value);
  const y2 = parseInt(document.getElementById('sw-y2').value);
  if ([x1, y1, x2, y2].some(isNaN)) return;
  await fetch(`${API}/swipe`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: selectedDevice.id, platform: selectedDevice.platform, x1, y1, x2, y2 }),
  });
  appendLog(`[Swipe] (${x1},${y1}) → (${x2},${y2})`);
  setTimeout(captureScreenshot, 500);
});

// ---- Logs ----

function appendLog(line, type = '') {
  const out = document.getElementById('log-output');
  const el = document.createElement('div');
  el.className = 'log-line' + (type ? ` ${type}` : '');
  el.textContent = line;
  out.appendChild(el);
  out.scrollTop = out.scrollHeight;
}

document.getElementById('btn-clear-logs').addEventListener('click', () => {
  document.getElementById('log-output').innerHTML = '';
});

function startLogStream() {
  if (!selectedDevice) { alert('Select a device first'); return; }
  if (!ws || ws.readyState !== WebSocket.OPEN) {
    ws = new WebSocket(WS_URL);
    ws.onopen = () => {
      ws.send(JSON.stringify({ type: 'start_logs', deviceId: selectedDevice.id, platform: selectedDevice.platform }));
      appendLog('[Inspector] Log stream started', 'ok');
    };
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.type === 'log') {
        const l = msg.line.toLowerCase();
        const type = l.includes('error') || l.includes('fatal') || l.includes('exception') ? 'error'
          : l.includes('warn') ? 'warn'
          : l.includes('✅') || l.includes('success') ? 'ok'
          : '';
        appendLog(msg.line, type);
      }
    };
    ws.onerror = () => appendLog('[Inspector] WebSocket error', 'error');
    ws.onclose = () => appendLog('[Inspector] Log stream ended');
  } else {
    ws.send(JSON.stringify({ type: 'start_logs', deviceId: selectedDevice.id, platform: selectedDevice.platform }));
    appendLog('[Inspector] Log stream started', 'ok');
  }
}

function stopLogStream() {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'stop_logs' }));
    appendLog('[Inspector] Log stream stopped');
  }
}

document.getElementById('btn-start-logs').addEventListener('click', startLogStream);
document.getElementById('btn-stop-logs').addEventListener('click', stopLogStream);
document.getElementById('btn-refresh-devices').addEventListener('click', fetchDevices);

// ---- Init ----
fetchDevices();
appendLog('[Inspector] Ready. Select a device to begin.');
