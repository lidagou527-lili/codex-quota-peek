'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { RpcClient } = require('./rpc.cjs');
const { validateConfig, normalizeLimits, updateLedger, atomicJson, readJson, accountFingerprint } = require('./core.cjs');
const arg = name => process.argv.find(a => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const dataDir = arg('data-dir') || process.env.QUOTA_PEEK_DATA_DIR || path.join(process.env.LOCALAPPDATA || process.cwd(), 'CodexQuotaPeek');
const once = process.argv.includes('--once'), owner = Number(arg('owner'));
fs.mkdirSync(dataDir, { recursive: true });
let lock;
try { lock = fs.openSync(path.join(dataDir, 'collector.lock'), 'wx'); fs.writeFileSync(lock, String(process.pid)); }
catch {
  const prior = Number(readFile(path.join(dataDir, 'collector.lock')));
  if (!Number.isInteger(prior) || prior <= 0) { console.error('Invalid collector lock. Exit the app and remove collector.lock from the data directory.'); process.exit(2); }
  try { process.kill(prior, 0); console.error('Quota collector already running'); process.exit(2); }
  catch { try { fs.unlinkSync(path.join(dataDir, 'collector.lock')); lock = fs.openSync(path.join(dataDir, 'collector.lock'), 'wx'); fs.writeFileSync(lock, String(process.pid)); } catch { process.exit(2); } }
}
function readFile(p) { try { return fs.readFileSync(p, 'utf8'); } catch { return ''; } }
function findCodex(config) {
  const explicit = arg('codex') || process.env.CODEX_QUOTA_CODEX_PATH || config.codexPath;
  if (explicit) { if (!fs.existsSync(explicit) || path.extname(explicit).toLowerCase() !== '.exe') throw Error('Configured Codex executable not found'); return explicit; }
  const root = path.join(process.env.LOCALAPPDATA || '', 'OpenAI', 'Codex', 'bin');
  const candidates = fs.existsSync(root) ? fs.readdirSync(root).map(n => path.join(root, n, 'codex.exe')).filter(p => fs.existsSync(p)) : [];
  candidates.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  if (candidates[0]) return candidates[0];
  try { const found = execFileSync('where.exe', ['codex.exe'], { encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] }).trim().split(/\r?\n/)[0]; if (found && fs.existsSync(found)) return found; } catch {}
  throw Error('Codex not found. Install Codex or set codexPath in settings.json');
}
const statePath = path.join(dataDir, 'ledger.json'), snapshotPath = path.join(dataDir, 'snapshot.json');
let ledger = readJson(statePath, null);
if (!ledger || ledger.version !== 1 || !ledger.salt || typeof ledger.entries !== 'object') ledger = { version: 1, salt: crypto.randomBytes(32).toString('hex'), entries: {} };
let rpc, authStamp, failures = 0, stopped = false, timeout, timer, snapshot = readJson(snapshotPath, {});
let lastAccount = null;
function status(error) { atomicJson(path.join(dataDir, 'status.json'), { checkedAt: new Date().toISOString(), error, failures }); }
function authVersion() { try { return fs.statSync(path.join(process.env.CODEX_HOME || path.join(process.env.USERPROFILE || '', '.codex'), 'auth.json')).mtimeMs; } catch { return 0; } }
async function poll() {
  let base = 60;
  try {
    const settingsPath = path.join(dataDir, 'settings.json');
    const input = fs.existsSync(settingsPath) ? readJson(settingsPath, null) : {};
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw Error('Invalid settings.json; restore settings.example.json');
    const config = validateConfig(input);
    const visible = readJson(path.join(dataDir, 'visibility.json'), {}).visible === true;
    base = visible ? config.foregroundSeconds : config.backgroundSeconds;
    const changed = authVersion();
    if (!rpc || rpc.closed || changed !== authStamp) { rpc?.close(); rpc = new RpcClient(findCodex(config)); await rpc.initialize(); authStamp = changed; }
    const { account } = await rpc.request('account/read', { refreshToken: false });
    const accountKey = accountFingerprint(account, ledger.salt);
    if ((lastAccount && accountKey !== lastAccount) || (snapshot.accountKey && snapshot.accountKey !== accountKey)) {
      snapshot = { accountKey, updatedAt: null, short: null, week: null, daily: null }; atomicJson(snapshotPath, snapshot);
    }
    lastAccount = accountKey;
    const limits = normalizeLimits(await rpc.request('account/rateLimits/read'));
    const now = Date.now();
    snapshot = { ...limits, accountKey, updatedAt: new Date(now).toISOString(), daily: updateLedger(ledger, limits, accountKey, now, config), timeZone: config.timeZone };
    atomicJson(statePath, ledger); atomicJson(snapshotPath, snapshot); failures = 0; status(null);
    if (once) { console.log(JSON.stringify({ ok: true, short: snapshot.short, week: snapshot.week, daily: snapshot.daily })); return stop(0); }
  } catch (e) {
    failures++; status(e.message); rpc?.close(); rpc = null;
    if (once) { console.error(e.message); return stop(1); }
  }
  if (!stopped) timeout = setTimeout(poll, failures ? Math.min(300, base * 2 ** Math.min(failures, 4)) * 1000 : base * 1000);
}
function stop(code = 0) {
  if (stopped) return; stopped = true; clearTimeout(timeout); clearInterval(timer); rpc?.close();
  try { fs.closeSync(lock); fs.unlinkSync(path.join(dataDir, 'collector.lock')); } catch {}
  process.exitCode = code; setTimeout(() => process.exit(code), 200).unref();
}
if (owner) timer = setInterval(() => { try { process.kill(owner, 0); } catch { stop(); } }, 1000);
process.on('SIGTERM', () => stop()); process.on('SIGINT', () => stop());
poll();
