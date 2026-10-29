'use strict';
const { spawn } = require('node:child_process');
const readline = require('node:readline');
class RpcClient {
  constructor(exe, args = ['app-server', '--stdio']) {
    this.seq = 0; this.pending = new Map(); this.closed = false;
    this.child = spawn(exe, args, { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    this.child.stderr.resume(); // Do not persist server diagnostics that may contain account data.
    this.child.stdin.on('error', () => {});
    this.child.on('error', () => this.failAll('Unable to start Codex'));
    this.child.on('exit', () => { this.closed = true; this.failAll('Codex connection closed'); });
    readline.createInterface({ input: this.child.stdout }).on('line', line => {
      let m; try { m = JSON.parse(line); } catch { return; }
      const p = this.pending.get(m.id);
      if (p) { clearTimeout(p.timer); this.pending.delete(m.id); m.error ? p.reject(Error('Codex request rejected')) : p.resolve(m.result); }
      else if (m.id !== undefined && m.method) this.child.stdin.write(JSON.stringify({ id: m.id, error: { code: -32601, message: 'Read-only quota client' } }) + '\n');
    });
  }
  failAll(message) { for (const p of this.pending.values()) { clearTimeout(p.timer); p.reject(Error(message)); } this.pending.clear(); }
  request(method, params, timeout = 15000) {
    if (this.closed) return Promise.reject(Error('Codex connection closed'));
    const id = ++this.seq;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.pending.delete(id); reject(Error('Codex request timed out')); }, timeout);
      this.pending.set(id, { resolve, reject, timer });
      this.child.stdin.write(JSON.stringify({ id, method, ...(params ? { params } : {}) }) + '\n');
    });
  }
  async initialize() { await this.request('initialize', { clientInfo: { name: 'codex_quota_peek', title: 'Codex Quota Peek', version: '0.1.0-alpha.1' } }); this.child.stdin.write('{"method":"initialized","params":{}}\n'); }
  close() { this.closed = true; this.failAll('Quota client stopped'); this.child.kill(); }
}
module.exports = { RpcClient };
