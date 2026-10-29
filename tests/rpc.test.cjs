const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { RpcClient } = require('../src/rpc.cjs');
const client = () => new RpcClient(process.execPath, [path.join(__dirname, 'rpc.fixture.cjs')]);
test('initialize and correlate concurrent responses', async () => { const r = client(); try { await r.initialize(); const results = await Promise.all([r.request('one'), r.request('two')]); assert.equal(results[0].method, 'one'); assert.equal(results[1].method, 'two'); } finally { r.close(); } });
test('request errors are surfaced without server payloads', async () => { const r = client(); try { await r.initialize(); await assert.rejects(r.request('error'), /rejected/); } finally { r.close(); } });
test('timeouts reject pending requests', async () => { const r = client(); try { await r.initialize(); await assert.rejects(r.request('hang', {}, 40), /timed out/); } finally { r.close(); } });
test('child shutdown rejects pending work', async () => { const r = client(); try { await r.initialize(); await assert.rejects(r.request('exit'), /closed/); } finally { r.close(); } });
