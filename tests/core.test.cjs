const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { validateConfig, normalizeLimits, budget, updateLedger, dayKey, atomicJson, readJson, accountFingerprint } = require('../src/core.cjs');
const now = Date.parse('2026-10-28T04:00:00Z'), reset = '2026-11-02T04:00:00Z';
const config = validateConfig({ timeZone: 'Asia/Shanghai' });
const sample = (remaining, resetsAt = reset) => ({ week: { remaining, resetsAt }, short: { remaining: 50 } });
const ledger = () => ({ entries: {} });
test('normalizes remaining instead of used; keeps missing windows null', () => {
  assert.deepEqual(normalizeLimits({ rateLimits: { primary: { usedPercent: 42, resetsAt: 1793160000, windowDurationMins: 300 } } }).week, null);
  assert.equal(normalizeLimits({ rateLimits: { primary: { usedPercent: 42 } } }).short.remaining, 58);
});
test('does not pick unrelated multi-bucket quota', () => assert.throws(() => normalizeLimits({ rateLimitsByLimitId: { another: { primary: { usedPercent: 0 } } } })));
test('invalid or absent windows are rejected', () => {
  assert.throws(() => normalizeLimits({ rateLimits: { primary: { usedPercent: 101 } } }));
  assert.throws(() => normalizeLimits({ rateLimits: {} }));
});
test('settings reject unsafe polling and invalid timezone', () => {
  assert.throws(() => validateConfig({ foregroundSeconds: 1 }));
  assert.throws(() => validateConfig({ reservePercent: 101 }));
  assert.throws(() => validateConfig({ timeZone: 'invalid' }));
});
test('calendar day respects configured timezone', () => assert.equal(dayKey(Date.parse('2026-10-28T17:00:00Z'), 'Asia/Shanghai'), '2026-10-29'));
test('budget reserves 10% and respects one-day minimum', () => { assert.equal(budget(72, reset, now, 10), 12.96); assert.equal(budget(20, new Date(now + 3600000).toISOString(), now, 10), 18); });
test('expired reset does not produce a budget', () => assert.equal(budget(50, new Date(now - 1).toISOString(), now, 10), null));
test('daily budget is fixed while consumption reduces suggested remainder', () => {
  const l = ledger(); const first = updateLedger(l, sample(70), 'a', now, config);
  const second = updateLedger(l, sample(65), 'a', now + 3600000, config);
  assert.equal(first.cap, second.cap); assert.equal(second.spent, 5); assert.equal(second.left, 7.6);
});
test('same observation is not counted twice', () => { const l = ledger(); updateLedger(l, sample(70), 'a', now, config); updateLedger(l, sample(65), 'a', now, config); assert.equal(updateLedger(l, sample(65), 'a', now, config).spent, 5); });
test('small quota corrections do not double-count usage', () => { const l = ledger(); for (const n of [70, 65, 66, 65]) updateLedger(l, sample(n), 'a', now, config); assert.equal(updateLedger(l, sample(64), 'a', now, config).spent, 6); });
test('reset timestamp jitter does not erase daily consumption', () => { const l = ledger(); updateLedger(l, sample(70), 'a', now, config); assert.equal(updateLedger(l, sample(65, '2026-11-02T04:00:01Z'), 'a', now, config).spent, 5); });
test('same-day reset retains earlier consumption but starts a new blue segment', () => {
  const l = ledger(); updateLedger(l, sample(70), 'a', now, config); updateLedger(l, sample(60), 'a', now, config);
  const after = updateLedger(l, sample(100, '2026-11-04T04:00:00Z'), 'a', now, config);
  assert.equal(after.spent, 10); assert.equal(after.segmentSpent, 0); assert.equal(after.segments, 2);
  assert.equal(updateLedger(l, sample(97, '2026-11-04T04:00:00Z'), 'a', now, config).spent, 13);
});
test('accounts have separate baselines', () => { const l = ledger(); updateLedger(l, sample(70), 'a', now, config); updateLedger(l, sample(60), 'a', now, config); assert.equal(updateLedger(l, sample(30), 'b', now, config).spent, 0); assert.equal(updateLedger(l, sample(59), 'a', now, config).spent, 11); });
test('cross-day starts at first sample rather than inventing midnight usage', () => { const l = ledger(); updateLedger(l, sample(70), 'a', now, config); assert.equal(updateLedger(l, sample(60), 'a', now + 86400000, config).spent, 0); });
test('missing weekly reset disables only daily budget', () => assert.equal(updateLedger(ledger(), { short: { remaining: 70 } }, 'a', now, config), null));
test('suggested remainder never becomes negative', () => { const l = ledger(); updateLedger(l, sample(70), 'a', now, config); assert.equal(updateLedger(l, sample(10), 'a', now, config).left, 0); });
test('fingerprint is salted and does not contain email', () => { const a = { type: 'chatgpt', email: 'fixture@example.invalid' }; assert.notEqual(accountFingerprint(a, 'one'), accountFingerprint(a, 'two')); assert.equal(accountFingerprint(a, 'one').includes('@'), false); assert.throws(() => accountFingerprint({ type: 'apiKey' }, 'x')); });
test('json writes are atomic and corrupt files have a safe fallback', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'quota-peek-core-')); const p = path.join(dir, 'state.json');
  try { atomicJson(p, { n: 1 }); atomicJson(p, { n: 2 }); assert.deepEqual(readJson(p), { n: 2 }); fs.writeFileSync(p, '{broken'); assert.deepEqual(readJson(p, { fallback: true }), { fallback: true }); } finally { fs.rmSync(dir, { recursive: true }); }
});
