// DCFlight Inspector — dual-device UI

const API = 'http://localhost:7070/api';
const WS_URL = 'ws://localhost:7070';

// State
let devices = [];
let primary = null;   // { id, name, platform, type }
let secondary = null;
let ws = null;
let autoTimer = null;
let autoActive = false;
let recentBundles = JSON.parse(localStorage.getItem('dcfi_bundles') || '[]');
let logFilter = '';

// ---- Utils ----

function el(id) { return document.getElementById(id); }

function appendLog(text, cls = '') {
  const out = el('log-output');
  const hidden = logFilter && !text.toLowerCase().includes(logFilter.toLowerCase());
  const div = document.createElement('div');
  div.className = 'log-line' + (cls ? ' ' + cls : '') + (hidden ? ' hidden' : '');
  div.textContent = text;
  out.appendChild(div);
  out.scrollTop = out.scrollHeight;
  while (out.children.length > 2000) out.removeChild(out.firstChild);
}

function classifyLog(line) {
  const l = line.toLowerCase();
  if (l.includes('error') || l.includes('fatal') || l.includes('exception') || l.includes('crash')) return 'error';
  if (l.includes('warn')) return 'warn';
  if (l.includes('success') || l.includes('complete')) return 'ok';
  if (l.includes('verbose') || l.startsWith('v/') || l.startsWith('d/')) return 'dim';
  return '';
}

function setStatus(text, online = true) {
  el('status-text').textContent = text;
  el('status-dot').className = 'status-dot' + (online ? ' online' : '');
}

// ---- Devices ----

async function fetchDevices() {
  try {
    const res = await fetch(`${API}/devices`);
    const data = await res.json();
    devices = data.devices || [];
    renderDevices();
    setStatus(`${devices.length} device${devices.length !== 1 ? 's' : ''}`, true);
  } catch {
    el('device-list').innerHTML = '<p class="empty-state" style="color:#f87171">Server not reachable</p>';
    setStatus('offline', false);
  }
}

function renderDevices() {
  const list = el('device-list');
  if (!devices.length) {
    list.innerHTML = '<p class="empty-state">No devices found</p>';
    return;
  }
  list.innerHTML = '';
  for (const d of devices) {
    const div = document.createElement('div');
    div.className = 'device-item'
      + (primary && primary.id === d.id ? ' primary' : '')
      + (secondary && secondary.id === d.id ? ' secondary' : '');
    div.innerHTML = `
      <span class="device-icon">${d.platform === 'ios' ? '📱' : '🤖'}</span>
      <div class="device-info">
        <div class="device-name">${d.name}</div>
        <div class="device-meta">${d.type} · ${d.state || 'online'}</div>
      </div>`;
    div.addEventListener('click', function(e) {
      if (e.altKey || e.metaKey) {
        secondary = d;
        appendLog('[Inspector] Secondary: ' + d.name, 'dim');
      } else {
        primary = d;
        appendLog('[Inspector] Primary: ' + d.name, 'dim');
      }
      renderDevices();
      updatePanelHeaders();
    });
    list.appendChild(div);
  }
}

function updatePanelHeaders() {
  el('primary-name').textContent = primary ? primary.name : 'no device';
  el('secondary-name').textContent = secondary ? secondary.name : 'no device';
}

// ---- Screenshots ----

async function captureDevice(device, imgId, footerId) {
  if (!device) return;
  const img = el(imgId);
  img.classList.add('loading');
  try {
    const res = await fetch(`${API}/screenshot`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: device.id, platform: device.platform, quality: 75 }),
    });
    const data = await res.json();
    if (data.error) { appendLog('[Error] ' + data.error, 'error'); return; }
    const mime = data.mimeType || 'image/jpeg';
    img.src = 'data:' + mime + ';base64,' + data.screenshot;
    img.style.display = 'block';
    img.closest('.ss-box').querySelector('.ss-placeholder').style.display = 'none';
    img.onload = function() {
      el(footerId).textContent = img.naturalWidth + 'x' + img.naturalHeight + '  ·  ' + new Date().toLocaleTimeString();
    };
  } catch (e) {
    appendLog('[Error] Screenshot: ' + e, 'error');
  } finally {
    img.classList.remove('loading');
  }
}

function capturePrimary() { captureDevice(primary, 'ss-img-primary', 'pf-primary'); }
function captureSecondary() { captureDevice(secondary, 'ss-img-secondary', 'pf-secondary'); }
function captureAll() { capturePrimary(); if (secondary) captureSecondary(); }

// Auto-screenshot
function startAuto(intervalMs) {
  stopAuto();
  if (!intervalMs) return;
  autoActive = true;
  el('btn-auto-toggle').dataset.active = 'true';
  el('btn-auto-toggle').textContent = 'Stop';
  captureAll();
  autoTimer = setInterval(captureAll, intervalMs);
}

function stopAuto() {
  autoActive = false;
  if (autoTimer) { clearInterval(autoTimer); autoTimer = null; }
  el('btn-auto-toggle').dataset.active = 'false';
  el('btn-auto-toggle').textContent = 'Start';
}

// Click-to-tap
function setupTapOverlay(ssBoxId, imgId, canvasId, checkId) {
  const img = el(imgId);
  const canvas = el(canvasId);
  const check = el(checkId);

  img.addEventListener('click', async function(e) {
    if (!check.checked) return;
    const device = ssBoxId.includes('primary') ? primary : secondary;
    if (!device) return;

    const rect = img.getBoundingClientRect();
    const relX = (e.clientX - rect.left) / rect.width;
    const relY = (e.clientY - rect.top) / rect.height;
    const tapX = Math.round(relX * img.naturalWidth);
    const tapY = Math.round(relY * img.naturalHeight);

    drawTap(canvas, e.clientX - rect.left, e.clientY - rect.top, rect.width, rect.height);
    appendLog('[Tap] ' + device.name.split(' ')[0] + ' (' + tapX + ', ' + tapY + ')', 'dim');

    try {
      await fetch(`${API}/tap`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ deviceId: device.id, platform: device.platform, x: tapX, y: tapY }),
      });
      setTimeout(function() {
        captureDevice(device, imgId, ssBoxId.includes('primary') ? 'pf-primary' : 'pf-secondary');
      }, 400);
    } catch (err) {
      appendLog('[Error] Tap failed: ' + err, 'error');
    }
  });
}

function drawTap(canvas, cx, cy, w, h) {
  canvas.width = w; canvas.height = h;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, w, h);
  ctx.beginPath();
  ctx.arc(cx, cy, 18, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(255,255,255,0.8)';
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(cx, cy, 4, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(255,255,255,0.9)';
  ctx.fill();
  setTimeout(function() { ctx.clearRect(0, 0, w, h); }, 600);
}

// ---- Bundle IDs ----

function saveBundle(id) {
  if (!id) return;
  recentBundles = [id].concat(recentBundles.filter(function(b) { return b !== id; })).slice(0, 6);
  localStorage.setItem('dcfi_bundles', JSON.stringify(recentBundles));
  renderRecentBundles();
}

function renderRecentBundles() {
  const c = el('recent-bundles');
  if (!c) return;
  c.innerHTML = '';
  for (const b of recentBundles) {
    const chip = document.createElement('span');
    chip.className = 'recent-chip';
    chip.textContent = b.split('.').pop();
    chip.title = b;
    chip.addEventListener('click', function() { el('input-bundle').value = b; });
    c.appendChild(chip);
  }
}

// ---- Actions ----

el('btn-screenshot').addEventListener('click', captureAll);

el('btn-home').addEventListener('click', async function() {
  if (!primary) return;
  await fetch(`${API}/home`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: primary.id, platform: primary.platform }) });
  appendLog('[Action] Home', 'dim');
});

el('btn-back').addEventListener('click', async function() {
  if (!primary) return;
  await fetch(`${API}/back`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: primary.id }) });
  appendLog('[Action] Back', 'dim');
});

el('btn-launch').addEventListener('click', async function() {
  if (!primary) return;
  const bundleId = el('input-bundle').value.trim();
  if (!bundleId) return;
  saveBundle(bundleId);
  const r = await fetch(`${API}/launch`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: primary.id, platform: primary.platform, bundleId }) });
  const d = await r.json();
  if (d.error) appendLog('[Error] Launch: ' + d.error, 'error');
  else appendLog('[Launch] ' + bundleId, 'ok');
  setTimeout(capturePrimary, 1500);
});

el('btn-type').addEventListener('click', async function() {
  if (!primary) return;
  const text = el('input-type').value;
  if (!text) return;
  await fetch(`${API}/type`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: primary.id, platform: primary.platform, text }) });
  appendLog('[Type] "' + text + '"', 'dim');
});

el('btn-tap').addEventListener('click', async function() {
  if (!primary) return;
  const x = parseInt(el('input-tap-x').value);
  const y = parseInt(el('input-tap-y').value);
  if (isNaN(x) || isNaN(y)) return;
  await fetch(`${API}/tap`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: primary.id, platform: primary.platform, x, y }) });
  appendLog('[Tap] (' + x + ', ' + y + ')', 'dim');
  setTimeout(capturePrimary, 400);
});

el('btn-swipe').addEventListener('click', async function() {
  if (!primary) return;
  const vals = ['sw-x1','sw-y1','sw-x2','sw-y2'].map(function(id) { return parseInt(el(id).value); });
  if (vals.some(isNaN)) return;
  const [x1,y1,x2,y2] = vals;
  await fetch(`${API}/swipe`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: primary.id, platform: primary.platform, x1, y1, x2, y2 }) });
  appendLog('[Swipe] (' + x1 + ',' + y1 + ') -> (' + x2 + ',' + y2 + ')', 'dim');
  setTimeout(capturePrimary, 500);
});

el('btn-auto-toggle').addEventListener('click', function() {
  if (autoActive) { stopAuto(); return; }
  const ms = parseInt(el('sel-interval').value);
  if (!ms) return;
  if (!primary) { appendLog('[Inspector] Select a device first', 'warn'); return; }
  startAuto(ms);
});

el('sel-interval').addEventListener('change', function() {
  if (autoActive) startAuto(parseInt(el('sel-interval').value));
});

// Dual view toggle
el('chk-dual').addEventListener('change', function(e) {
  el('screens-area').className = 'screens-area' + (e.target.checked ? '' : ' single');
});

// ---- Logs ----

el('btn-logs-stream').addEventListener('click', function() {
  if (!primary) { appendLog('[Inspector] Select a device first', 'warn'); return; }
  connectWs(primary);
});

el('btn-logs-stop').addEventListener('click', function() {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'stop_logs' }));
    appendLog('[Inspector] Log stream stopped', 'dim');
  }
});

el('btn-logs-clear').addEventListener('click', function() {
  el('log-output').innerHTML = '';
});

el('log-filter').addEventListener('input', function(e) {
  logFilter = e.target.value.toLowerCase();
  for (const line of el('log-output').children) {
    const hidden = logFilter && !line.textContent.toLowerCase().includes(logFilter);
    line.classList.toggle('hidden', hidden);
  }
});

el('btn-refresh-devices').addEventListener('click', fetchDevices);

function connectWs(device) {
  if (ws && ws.readyState <= 1) {
    ws.send(JSON.stringify({ type: 'start_logs', deviceId: device.id, platform: device.platform }));
    appendLog('[Inspector] Log stream: ' + device.name, 'ok');
    return;
  }
  ws = new WebSocket(WS_URL);
  ws.onopen = function() {
    ws.send(JSON.stringify({ type: 'start_logs', deviceId: device.id, platform: device.platform }));
    appendLog('[Inspector] Log stream: ' + device.name, 'ok');
  };
  ws.onmessage = function(e) {
    try {
      const msg = JSON.parse(e.data);
      if (msg.type === 'log') appendLog(msg.line, classifyLog(msg.line));
    } catch(err) {}
  };
  ws.onerror = function() { appendLog('[Inspector] WebSocket error', 'error'); };
  ws.onclose = function() { appendLog('[Inspector] Log stream closed', 'dim'); };
}

// ---- Keyboard shortcuts ----
document.addEventListener('keydown', function(e) {
  if (e.key === 's' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); captureAll(); }
  if (e.key === 'l' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); el('btn-logs-stream').click(); }
});

// ---- Init ----
setupTapOverlay('ss-box-primary', 'ss-img-primary', 'tap-canvas-primary', 'chk-tap-primary');
setupTapOverlay('ss-box-secondary', 'ss-img-secondary', 'tap-canvas-secondary', 'chk-tap-secondary');
renderRecentBundles();
['com.dotcorr.dcfGo', 'com.dotcorr.dcf_go', 'com.dotcorr.app.salontime'].forEach(saveBundle);
fetchDevices();
appendLog('[Inspector] Ready — Click a device to start', 'ok');
