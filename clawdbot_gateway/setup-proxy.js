#!/usr/bin/env node
'use strict';

/**
 * Clawdbot HA Add-on Setup Proxy
 *
 * - Listens on 127.0.0.1:8099 (Ingress entry)
 * - Reverse-proxies HTTP + WebSocket to the running Clawdbot Gateway (default 127.0.0.1:18789)
 * - Optionally serves a simple setup UI at /__setup (feature-flag via add-on option)
 *
 * Design goals:
 * - Keep behavior unchanged when easy setup is disabled (transparent proxy)
 * - Never log secrets (API keys, OAuth codes, tokens)
 */

const http = require('http');
const net = require('net');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PROXY_HOST = process.env.SETUP_PROXY_HOST || '127.0.0.1';
const PROXY_PORT = parseInt(process.env.SETUP_PROXY_PORT || '8099', 10);

const GATEWAY_HOST = process.env.GATEWAY_HOST || '127.0.0.1';
const GATEWAY_PORT = parseInt(process.env.GATEWAY_PORT || '18789', 10);

const EASY_SETUP_UI = String(process.env.EASY_SETUP_UI || '').toLowerCase() === 'true';

const CLAWDBOT_ACTIVE_DIR = process.env.CLAWDBOT_ACTIVE_DIR || '/config/clawdbot/source/active';
const CLAWDBOT_STATE_DIR = process.env.CLAWDBOT_STATE_DIR || '/config/clawdbot/data/state';
const CLAWDBOT_CONFIG_PATH = process.env.CLAWDBOT_CONFIG_PATH || '/config/clawdbot/data/clawdbot.json';

const ENV_PATH = path.posix.join(CLAWDBOT_STATE_DIR, '.env');

function safeJsonParse(text) {
  try {
    return { ok: true, value: JSON.parse(text) };
  } catch {
    return { ok: false, value: null };
  }
}

function exists(p) {
  try {
    fs.accessSync(p, fs.constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

function readBody(req, maxBytes = 256 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > maxBytes) {
        reject(new Error('body_too_large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(body);
}

function sendText(res, statusCode, body, contentType = 'text/plain; charset=utf-8') {
  res.writeHead(statusCode, { 'content-type': contentType, 'cache-control': 'no-store' });
  res.end(body);
}

function htmlEscape(s) {
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function shouldServeSetupForRequest(reqUrl) {
  if (!EASY_SETUP_UI) return false;
  if (reqUrl.startsWith('/__setup')) return true;
  // Auto-show setup if no config exists yet (typical first-run).
  return !exists(CLAWDBOT_CONFIG_PATH);
}

function pnpmCwd() {
  // The add-on ensures /config/clawdbot/source/active points to a built version.
  // If it's not there yet, we still try; errors are surfaced to the UI.
  return CLAWDBOT_ACTIVE_DIR;
}

function runPnpm(args, { input, timeoutMs = 120000 } = {}) {
  return new Promise((resolve) => {
    const child = spawn('pnpm', args, {
      cwd: pnpmCwd(),
      env: { ...process.env },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    const timer = setTimeout(() => {
      try {
        child.kill('SIGKILL');
      } catch {
        // ignore
      }
    }, timeoutMs);

    child.stdout.on('data', (d) => {
      stdout += d.toString('utf8');
    });
    child.stderr.on('data', (d) => {
      stderr += d.toString('utf8');
    });

    child.on('close', (code) => {
      clearTimeout(timer);
      resolve({ code: code ?? 1, stdout, stderr });
    });

    if (typeof input === 'string' && input.length > 0) {
      child.stdin.write(input);
    }
    child.stdin.end();
  });
}

function gatewayWsUrl() {
  // Gateway RPC is over WebSocket; CLI expects ws://
  return `ws://${GATEWAY_HOST}:${GATEWAY_PORT}`;
}

async function gatewayCall(method, paramsObj, { token, timeoutMs } = {}) {
  const paramsRaw = paramsObj ? JSON.stringify(paramsObj) : '{}';
  const args = ['clawdbot', 'gateway', 'call', method, '--url', gatewayWsUrl(), '--params', paramsRaw, '--json'];
  if (token) args.push('--token', token);
  const { code, stdout, stderr } = await runPnpm(args, { timeoutMs: timeoutMs ?? 120000 });
  const parsed = safeJsonParse(stdout.trim());
  return {
    ok: code === 0,
    code,
    json: parsed.ok ? parsed.value : null,
    stdout,
    stderr,
  };
}

function parseDotEnv(text) {
  const lines = text.split(/\r?\n/);
  const out = new Map();
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    const k = trimmed.slice(0, idx).trim();
    const v = trimmed.slice(idx + 1).trim();
    out.set(k, v);
  }
  return out;
}

function serializeDotEnv(map) {
  const keys = Array.from(map.keys()).sort();
  const lines = [
    '# Generated by Clawdbot HA Add-on Setup UI',
    '# Do not commit this file. Keep it private.',
    ...keys.map((k) => `${k}=${map.get(k) ?? ''}`),
    '',
  ];
  return lines.join('\n');
}

function writeEnvFile(updates) {
  const current = exists(ENV_PATH) ? fs.readFileSync(ENV_PATH, 'utf8') : '';
  const m = parseDotEnv(current);

  for (const [k, v] of Object.entries(updates)) {
    if (typeof v === 'string' && v.length > 0) {
      m.set(k, v);
    } else if (v === null) {
      m.delete(k);
    }
  }

  const next = serializeDotEnv(m);
  fs.mkdirSync(path.posix.dirname(ENV_PATH), { recursive: true });
  fs.writeFileSync(ENV_PATH, next, { encoding: 'utf8', mode: 0o600 });
}

const SETUP_HTML = `<!doctype html>
<html lang="de">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Clawdbot Setup (Home Assistant)</title>
    <style>
      :root { --bg:#0b0f14; --panel:#111823; --text:#e7eef7; --muted:#9fb1c5; --acc:#ff5a2d; --line:#223043; }
      @media (prefers-color-scheme: light) { :root { --bg:#f6f8fb; --panel:#ffffff; --text:#132033; --muted:#4d637a; --line:#e2e8f0; } }
      body { margin:0; font: 14px/1.5 system-ui, -apple-system, Segoe UI, Roboto, sans-serif; background:var(--bg); color:var(--text); }
      .wrap { max-width: 980px; margin: 0 auto; padding: 20px; }
      .hero { display:flex; gap:16px; align-items:flex-start; justify-content:space-between; }
      .hero h1 { margin:0 0 4px; font-size: 20px; }
      .hero p { margin:0; color:var(--muted); }
      .card { background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:16px; margin-top:14px; }
      .row { display:flex; gap:12px; flex-wrap:wrap; }
      .col { flex:1; min-width: 280px; }
      label { display:block; font-weight:600; margin: 10px 0 6px; }
      input[type="text"], input[type="password"], textarea { width:100%; box-sizing:border-box; padding:10px 12px; border-radius:10px; border:1px solid var(--line); background:transparent; color:var(--text); }
      textarea { min-height: 110px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
      button { appearance:none; border:1px solid var(--line); background:transparent; color:var(--text); padding:10px 12px; border-radius:10px; cursor:pointer; }
      button.primary { border-color: color-mix(in oklab, var(--acc), var(--line)); background: color-mix(in oklab, var(--acc) 20%, transparent); }
      button:disabled { opacity:.6; cursor:not-allowed; }
      .pill { display:inline-block; padding: 4px 8px; border-radius: 999px; border:1px solid var(--line); color: var(--muted); }
      pre { margin: 10px 0 0; padding: 12px; border-radius: 10px; border:1px solid var(--line); overflow:auto; background: rgba(0,0,0,.15); }
      .warn { color: #ffb020; }
      .ok { color: #2fbf71; }
      .muted { color: var(--muted); }
      .small { font-size: 12px; }
      a { color: var(--acc); }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="hero">
        <div>
          <h1>Clawdbot Setup (Home Assistant)</h1>
          <p>Einfaches Setup ohne SSH: ChatGPT/Codex OAuth oder API Keys setzen.</p>
        </div>
        <div class="pill" id="statusPill">Status wird geladen…</div>
      </div>

      <div class="card">
        <div class="row">
          <div class="col">
            <h2 style="margin:0 0 6px; font-size:16px;">1) Wizard (empfohlen)</h2>
            <p class="muted" style="margin:0 0 10px;">Startet den offiziellen Clawdbot Wizard über Gateway-RPC. Dort kannst du „OpenAI Codex (ChatGPT OAuth)“ auswählen.</p>
            <div class="row" style="gap:8px;">
              <button class="primary" id="btnWizardStart">Wizard starten</button>
              <button id="btnWizardStatus">Status</button>
              <button id="btnWizardNext">Weiter</button>
              <button id="btnWizardCancel">Abbrechen</button>
            </div>
            <label for="gatewayToken">Optional: Gateway Token (falls du Gateway-Auth aktiviert hast)</label>
            <input id="gatewayToken" type="password" placeholder="leer lassen, wenn nicht benötigt" />
            <p class="small muted">Hinweis: Token wird nur für RPC-Aufrufe verwendet und im Browser nicht persistiert.</p>
            <label for="wizardNextParams">Wizard-Weiter (JSON)</label>
            <textarea id="wizardNextParams" placeholder='Beispiel: {"choice":"openai-codex"}'></textarea>
            <p class="small muted">Wenn du nicht weißt, was hier rein soll: zuerst „Status“ klicken und den aktuellen Step anschauen.</p>
          </div>
          <div class="col">
            <h2 style="margin:0 0 6px; font-size:16px;">2) API Keys (Fallback)</h2>
            <p class="muted" style="margin:0 0 10px;">Schreibt Keys nach <code>/config/clawdbot/data/state/.env</code>. Du kannst später jederzeit umstellen.</p>
            <label for="anthropicKey">Anthropic API Key</label>
            <input id="anthropicKey" type="password" placeholder="sk-ant-…" />
            <label for="openaiKey">OpenAI API Key</label>
            <input id="openaiKey" type="password" placeholder="sk-…" />
            <div class="row" style="gap:8px; margin-top:10px;">
              <button class="primary" id="btnSaveKeys">Keys speichern</button>
              <button id="btnCheckModels">Model/Auth Status</button>
            </div>
            <p class="small muted">Keys werden nie im Klartext angezeigt. Logs enthalten keine Secrets.</p>
          </div>
        </div>
      </div>

      <div class="card">
        <h2 style="margin:0 0 6px; font-size:16px;">Ausgabe</h2>
        <p class="muted" style="margin:0 0 10px;">Hier siehst du die Antworten der RPC-/CLI-Aufrufe (gekürzt, ohne Secrets).</p>
        <pre id="out">(noch keine Ausgabe)</pre>
        <div id="wizardHelper" style="margin-top:12px;"></div>
      </div>

      <div class="card">
        <h2 style="margin:0 0 6px; font-size:16px;">Weiter zur normalen Oberfläche</h2>
        <p class="muted" style="margin:0 0 10px;">Wenn alles eingerichtet ist, kannst du zur normalen Clawdbot Control UI wechseln.</p>
        <a href="/" id="linkControlUi">Control UI öffnen</a>
      </div>

      <p class="small muted" style="margin-top:14px;">Pfad: <code>/__setup</code>. (Nur aktiv, wenn im Add-on <code>easy_setup_ui</code> eingeschaltet ist.)</p>
    </div>

    <script>
      const out = document.getElementById('out');
      const statusPill = document.getElementById('statusPill');
      const gatewayToken = document.getElementById('gatewayToken');
      const wizardHelper = document.getElementById('wizardHelper');

      function pretty(v) {
        try { return JSON.stringify(v, null, 2); } catch { return String(v); }
      }

      function setOut(v) {
        out.textContent = typeof v === 'string' ? v : pretty(v);
      }

      function clearWizardHelper() {
        wizardHelper.innerHTML = '';
      }

      function getActionsFromEnvelope(env) {
        if (!env || typeof env !== 'object') return [];
        const payload = env.json || env;
        const candidates = [];
        const direct = payload && payload.actions;
        if (Array.isArray(direct)) candidates.push(direct);
        const step = payload && payload.step;
        if (step && Array.isArray(step.actions)) candidates.push(step.actions);
        if (step && Array.isArray(step.choices)) candidates.push(step.choices);
        if (step && Array.isArray(step.options)) candidates.push(step.options);
        // Flatten and normalize
        const flat = candidates.flat().filter(Boolean);
        const out = [];
        for (const a of flat) {
          if (typeof a === 'string') {
            out.push({ label: a, params: { choice: a } });
            continue;
          }
          if (!a || typeof a !== 'object') continue;
          const label = a.label || a.title || a.name || a.text || a.id || 'Weiter';
          const params = a.next || a.params || (a.value != null ? { value: a.value } : null);
          if (params && typeof params === 'object') out.push({ label, params });
        }
        return out;
      }

      async function wizardNext(params) {
        const r = await api('/wizard/next', {
          method: 'POST',
          body: JSON.stringify({ token: gatewayToken.value || null, params })
        });
        return r;
      }

      function renderWizardHelper(env) {
        clearWizardHelper();
        const actions = getActionsFromEnvelope(env);
        if (!actions.length) return;

        const wrap = document.createElement('div');
        wrap.className = 'card';
        wrap.style.padding = '12px';
        wrap.style.borderStyle = 'dashed';

        const h = document.createElement('div');
        h.innerHTML = '<strong>Wizard Schnell-Buttons</strong><div class="small muted">Wenn der Wizard Aktionen liefert, kannst du hier klicken (ansonsten nutze „Wizard-Weiter (JSON)“).</div>';
        wrap.appendChild(h);

        const row = document.createElement('div');
        row.className = 'row';
        row.style.gap = '8px';
        row.style.marginTop = '10px';

        for (const a of actions.slice(0, 8)) {
          const btn = document.createElement('button');
          btn.className = 'primary';
          btn.textContent = a.label;
          btn.addEventListener('click', async () => {
            setOut('Wizard weiter…');
            try {
              const nextRes = await wizardNext(a.params);
              setOut(nextRes);
              renderWizardHelper(nextRes);
            } catch (e) {
              setOut('Fehler: ' + e.message);
            } finally { refreshPill(); }
          });
          row.appendChild(btn);
        }
        wrap.appendChild(row);
        wizardHelper.appendChild(wrap);
      }

      async function api(path, opts) {
        const res = await fetch('/__setup/api' + path, {
          headers: { 'content-type': 'application/json' },
          ...opts,
        });
        const text = await res.text();
        let json = null;
        try { json = JSON.parse(text); } catch {}
        if (!res.ok) {
          throw new Error((json && json.error) ? json.error : text || ('HTTP ' + res.status));
        }
        return json ?? text;
      }

      async function refreshPill() {
        try {
          const env = await api('/env', { method: 'GET' });
          const parts = [];
          parts.push(env.configExists ? 'Config: ok' : 'Config: fehlt');
          parts.push(env.activeDirExists ? 'Build: ok' : 'Build: fehlt');
          statusPill.textContent = parts.join(' · ');
          statusPill.className = 'pill ' + (env.configExists ? 'ok' : 'warn');
        } catch (e) {
          statusPill.textContent = 'Status: Fehler';
          statusPill.className = 'pill warn';
        }
      }

      document.getElementById('btnWizardStart').addEventListener('click', async () => {
        setOut('Wizard wird gestartet…');
        try {
          const r = await api('/wizard/start', {
            method: 'POST',
            body: JSON.stringify({ token: gatewayToken.value || null })
          });
          setOut(r);
          renderWizardHelper(r);
        } catch (e) {
          setOut('Fehler: ' + e.message);
          clearWizardHelper();
        } finally { refreshPill(); }
      });

      document.getElementById('btnWizardStatus').addEventListener('click', async () => {
        setOut('Status wird geladen…');
        try {
          const r = await api('/wizard/status', {
            method: 'POST',
            body: JSON.stringify({ token: gatewayToken.value || null })
          });
          setOut(r);
          renderWizardHelper(r);
        } catch (e) {
          setOut('Fehler: ' + e.message);
          clearWizardHelper();
        } finally { refreshPill(); }
      });

      document.getElementById('btnWizardCancel').addEventListener('click', async () => {
        setOut('Wizard wird abgebrochen…');
        try {
          const r = await api('/wizard/cancel', {
            method: 'POST',
            body: JSON.stringify({ token: gatewayToken.value || null })
          });
          setOut(r);
          clearWizardHelper();
        } catch (e) {
          setOut('Fehler: ' + e.message);
          clearWizardHelper();
        } finally { refreshPill(); }
      });

      document.getElementById('btnWizardNext').addEventListener('click', async () => {
        setOut('Wizard weiter…');
        try {
          const raw = document.getElementById('wizardNextParams').value || '{}';
          let params = null;
          try { params = JSON.parse(raw); } catch { throw new Error('Ungültiges JSON in „Wizard-Weiter (JSON)“'); }
          const r = await api('/wizard/next', {
            method: 'POST',
            body: JSON.stringify({ token: gatewayToken.value || null, params })
          });
          setOut(r);
          renderWizardHelper(r);
        } catch (e) {
          setOut('Fehler: ' + e.message);
        } finally { refreshPill(); }
      });

      document.getElementById('btnSaveKeys').addEventListener('click', async () => {
        setOut('Keys werden gespeichert…');
        try {
          const anthropicKey = document.getElementById('anthropicKey').value || null;
          const openaiKey = document.getElementById('openaiKey').value || null;
          const r = await api('/keys', {
            method: 'POST',
            body: JSON.stringify({ anthropicKey, openaiKey })
          });
          setOut(r);
          document.getElementById('anthropicKey').value = '';
          document.getElementById('openaiKey').value = '';
        } catch (e) {
          setOut('Fehler: ' + e.message);
        } finally { refreshPill(); }
      });

      document.getElementById('btnCheckModels').addEventListener('click', async () => {
        setOut('Model/Auth Status wird geladen…');
        try {
          const r = await api('/models/status', { method: 'GET' });
          setOut(r);
        } catch (e) {
          setOut('Fehler: ' + e.message);
        } finally { refreshPill(); }
      });

      refreshPill();
      setInterval(refreshPill, 5000);
    </script>
  </body>
</html>`;

async function handleSetupApi(req, res) {
  const url = req.url || '/';
  const pathOnly = url.replace(/^\/__setup\/api/, '') || '/';

  if (req.method === 'GET' && pathOnly === '/env') {
    return sendJson(res, 200, {
      ok: true,
      easySetupUi: EASY_SETUP_UI,
      proxy: { host: PROXY_HOST, port: PROXY_PORT },
      gateway: { host: GATEWAY_HOST, port: GATEWAY_PORT, url: gatewayWsUrl() },
      activeDir: CLAWDBOT_ACTIVE_DIR,
      activeDirExists: exists(CLAWDBOT_ACTIVE_DIR),
      stateDir: CLAWDBOT_STATE_DIR,
      configPath: CLAWDBOT_CONFIG_PATH,
      configExists: exists(CLAWDBOT_CONFIG_PATH),
      envPath: ENV_PATH,
    });
  }

  if (req.method === 'GET' && pathOnly === '/models/status') {
    const { code, stdout, stderr } = await runPnpm(['clawdbot', 'models', 'status', '--json'], { timeoutMs: 60000 });
    const parsed = safeJsonParse(stdout.trim());
    return sendJson(res, code === 0 ? 200 : 500, {
      ok: code === 0,
      code,
      json: parsed.ok ? parsed.value : null,
      // never echo raw stdout/stderr if it might contain sensitive fields; keep best-effort safe
      message: code === 0 ? 'ok' : 'models status failed',
      stderr: (stderr || '').split(/\r?\n/).slice(0, 50).join('\n'),
    });
  }

  if (req.method === 'POST' && pathOnly === '/wizard/start') {
    const body = await readBody(req);
    const parsed = safeJsonParse(body);
    const token = parsed.ok && parsed.value && parsed.value.token ? String(parsed.value.token) : undefined;
    const startParams =
      parsed.ok && parsed.value && parsed.value.params && typeof parsed.value.params === 'object'
        ? parsed.value.params
        : { mode: 'local', flow: 'quickstart' };
    const r = await gatewayCall('wizard.start', startParams, { token, timeoutMs: 60000 });
    return sendJson(res, r.ok ? 200 : 500, {
      ok: r.ok,
      code: r.code,
      json: r.json,
      message: r.ok ? 'ok' : 'wizard.start failed',
      stderr: (r.stderr || '').split(/\r?\n/).slice(0, 50).join('\n'),
    });
  }

  if (req.method === 'POST' && pathOnly === '/wizard/status') {
    const body = await readBody(req);
    const parsed = safeJsonParse(body);
    const token = parsed.ok && parsed.value && parsed.value.token ? String(parsed.value.token) : undefined;
    const r = await gatewayCall('wizard.status', {}, { token, timeoutMs: 60000 });
    return sendJson(res, r.ok ? 200 : 500, {
      ok: r.ok,
      code: r.code,
      json: r.json,
      message: r.ok ? 'ok' : 'wizard.status failed',
      stderr: (r.stderr || '').split(/\r?\n/).slice(0, 50).join('\n'),
    });
  }

  if (req.method === 'POST' && pathOnly === '/wizard/cancel') {
    const body = await readBody(req);
    const parsed = safeJsonParse(body);
    const token = parsed.ok && parsed.value && parsed.value.token ? String(parsed.value.token) : undefined;
    const r = await gatewayCall('wizard.cancel', {}, { token, timeoutMs: 60000 });
    return sendJson(res, r.ok ? 200 : 500, {
      ok: r.ok,
      code: r.code,
      json: r.json,
      message: r.ok ? 'ok' : 'wizard.cancel failed',
      stderr: (r.stderr || '').split(/\r?\n/).slice(0, 50).join('\n'),
    });
  }

  if (req.method === 'POST' && pathOnly === '/wizard/next') {
    const body = await readBody(req);
    const parsed = safeJsonParse(body);
    const token = parsed.ok && parsed.value && parsed.value.token ? String(parsed.value.token) : undefined;
    const params = parsed.ok && parsed.value && parsed.value.params && typeof parsed.value.params === 'object' ? parsed.value.params : {};
    const r = await gatewayCall('wizard.next', params, { token, timeoutMs: 60000 });
    return sendJson(res, r.ok ? 200 : 500, {
      ok: r.ok,
      code: r.code,
      json: r.json,
      message: r.ok ? 'ok' : 'wizard.next failed',
      stderr: (r.stderr || '').split(/\r?\n/).slice(0, 50).join('\n'),
    });
  }

  if (req.method === 'POST' && pathOnly === '/keys') {
    const body = await readBody(req);
    const parsed = safeJsonParse(body);
    if (!parsed.ok || !parsed.value || typeof parsed.value !== 'object') {
      return sendJson(res, 400, { ok: false, error: 'invalid_json' });
    }

    const anthropicKey = parsed.value.anthropicKey ? String(parsed.value.anthropicKey).trim() : '';
    const openaiKey = parsed.value.openaiKey ? String(parsed.value.openaiKey).trim() : '';

    const updates = {};
    if (anthropicKey) updates.ANTHROPIC_API_KEY = anthropicKey;
    if (openaiKey) updates.OPENAI_API_KEY = openaiKey;
    if (!anthropicKey && !openaiKey) {
      return sendJson(res, 400, { ok: false, error: 'no_keys_provided' });
    }

    try {
      writeEnvFile(updates);
      return sendJson(res, 200, { ok: true, message: 'saved', path: ENV_PATH });
    } catch (e) {
      return sendJson(res, 500, { ok: false, error: 'write_failed' });
    }
  }

  return sendJson(res, 404, { ok: false, error: 'not_found' });
}

function proxyHttp(req, res) {
  const options = {
    host: GATEWAY_HOST,
    port: GATEWAY_PORT,
    method: req.method,
    path: req.url,
    headers: { ...req.headers, host: `${GATEWAY_HOST}:${GATEWAY_PORT}` },
  };

  const upstream = http.request(options, (upRes) => {
    res.writeHead(upRes.statusCode || 502, upRes.headers);
    upRes.pipe(res);
  });

  upstream.on('error', () => {
    sendText(
      res,
      502,
      'Gateway ist noch nicht erreichbar. Bitte ein paar Minuten warten und erneut versuchen.\n'
    );
  });

  req.pipe(upstream);
}

function proxyWs(req, socket, head) {
  const upstream = net.connect(GATEWAY_PORT, GATEWAY_HOST, () => {
    // Reconstruct the raw HTTP upgrade request.
    let headerLines = `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`;
    const headers = req.headers || {};
    for (const [k, v] of Object.entries(headers)) {
      if (typeof v === 'undefined') continue;
      if (Array.isArray(v)) {
        for (const one of v) headerLines += `${k}: ${one}\r\n`;
      } else {
        headerLines += `${k}: ${v}\r\n`;
      }
    }
    headerLines += `\r\n`;

    upstream.write(headerLines);
    if (head && head.length) upstream.write(head);
    socket.pipe(upstream).pipe(socket);
  });

  upstream.on('error', () => {
    try {
      socket.destroy();
    } catch {
      // ignore
    }
  });
}

const server = http.createServer(async (req, res) => {
  const url = req.url || '/';

  if (EASY_SETUP_UI && url === '/__setup') {
    res.writeHead(302, { location: '/__setup/' });
    res.end();
    return;
  }

  if (shouldServeSetupForRequest(url)) {
    if (url.startsWith('/__setup/api/')) {
      try {
        await handleSetupApi(req, res);
      } catch (e) {
        sendJson(res, 500, { ok: false, error: 'internal_error' });
      }
      return;
    }

    if (url.startsWith('/__setup/')) {
      return sendText(res, 200, SETUP_HTML, 'text/html; charset=utf-8');
    }

    // Auto-setup landing (root) if config missing
    return sendText(res, 200, SETUP_HTML, 'text/html; charset=utf-8');
  }

  // Transparent proxy mode
  return proxyHttp(req, res);
});

server.on('upgrade', (req, socket, head) => {
  const url = req.url || '/';
  if (EASY_SETUP_UI && url.startsWith('/__setup/')) {
    socket.destroy();
    return;
  }
  proxyWs(req, socket, head);
});

server.listen(PROXY_PORT, PROXY_HOST, () => {
  // Intentionally minimal logs (no secrets).
  process.stdout.write(
    `[setup-proxy] listening on ${PROXY_HOST}:${PROXY_PORT}, proxying to ${GATEWAY_HOST}:${GATEWAY_PORT}, easy_setup_ui=${EASY_SETUP_UI}\n`
  );
});

