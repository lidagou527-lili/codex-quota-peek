'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const DEFAULTS = Object.freeze({ codexPath: '', foregroundSeconds: 15, backgroundSeconds: 60, reservePercent: 10, timeZone: 'local', showMode: 'codex', language: 'auto' });
function validateConfig(input = {}) {
  const c = { ...DEFAULTS, ...input };
  for (const key of ['foregroundSeconds', 'backgroundSeconds']) {
    if (!Number.isFinite(c[key]) || c[key] < 15 || c[key] > 3600) throw Error(`${key} must be 15–3600 seconds`);
  }
  if (!Number.isFinite(c.reservePercent) || c.reservePercent < 0 || c.reservePercent > 90) throw Error('reservePercent must be 0–90');
  if (!['codex', 'always'].includes(c.showMode)) throw Error('showMode must be codex or always');
  if (!['auto', 'zh', 'en'].includes(c.language)) throw Error('language must be auto, zh or en');
  if (typeof c.codexPath !== 'string') throw Error('codexPath must be a string');
  if (c.timeZone !== 'local') new Intl.DateTimeFormat('en', { timeZone: c.timeZone }).format();
  return c;
}
function dayKey(now, zone = 'local') {
  const parts = new Intl.DateTimeFormat('en-CA', { ...(zone === 'local' ? {} : { timeZone: zone }), year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date(now));
  const value = name => parts.find(p => p.type === name).value;
  return `${value('year')}-${value('month')}-${value('day')}`;
}
function normalizeWindow(w) {
  if (!w || !Number.isFinite(w.usedPercent) || w.usedPercent < 0 || w.usedPercent > 100) return null;
  return { remaining: 100 - w.usedPercent, resetsAt: Number.isFinite(w.resetsAt) && w.resetsAt > 0 ? new Date(w.resetsAt * 1000).toISOString() : null, minutes: Number.isFinite(w.windowDurationMins) ? w.windowDurationMins : null };
}
function normalizeLimits(result) {
  const map = result?.rateLimitsByLimitId;
  const r = map ? map.codex : result?.rateLimits;
  if (!r || (r.limitId && r.limitId !== 'codex')) throw Error('Codex quota bucket unavailable');
  const short = normalizeWindow(r.primary), week = normalizeWindow(r.secondary);
  if (!short && !week) throw Error('No supported quota windows returned');
  return { short, week, planType: r.planType || null };
}
function sameCycle(a, b) { return a && b && Math.abs(Date.parse(a) - Date.parse(b)) <= 60000; }
function budget(remaining, resetsAt, now, reserve) {
  const days = (Date.parse(resetsAt) - now) / 86400000;
  if (!Number.isFinite(days) || days <= 0) return null;
  return Math.min(remaining, remaining / Math.max(1, days)) * (1 - reserve / 100);
}
const round = n => Math.round(n * 10) / 10;
function updateLedger(ledger, sample, accountKey, now, config) {
  if (!sample.week || !sample.week.resetsAt) return null;
  const cap = budget(sample.week.remaining, sample.week.resetsAt, now, config.reservePercent);
  if (cap === null) return null;
  const day = dayKey(now, config.timeZone), key = `${accountKey}:${day}`;
  let e = ledger.entries[key];
  if (!e) {
    e = ledger.entries[key] = { day, accountKey, startedAt: new Date(now).toISOString(), cycle: sample.week.resetsAt, watermark: sample.week.remaining, spent: 0, segmentSpent: 0, cap, segments: 1 };
  } else if (!sameCycle(e.cycle, sample.week.resetsAt) || sample.week.remaining > e.watermark + 2) {
    // Keep consumption before a reset, but allocate a fresh budget from the new allowance.
    e.cycle = sample.week.resetsAt; e.watermark = sample.week.remaining; e.segmentSpent = 0; e.cap = e.spent + cap; e.segments++;
  } else {
    const delta = Math.max(0, e.watermark - sample.week.remaining);
    e.spent += delta; e.segmentSpent += delta; e.watermark = Math.min(e.watermark, sample.week.remaining);
  }
  for (const [k, v] of Object.entries(ledger.entries)) if (Date.parse(day + 'T12:00:00Z') - Date.parse(v.day + 'T12:00:00Z') > 14 * 86400000) delete ledger.entries[k];
  return { day, startedAt: e.startedAt, spent: round(e.spent), segmentSpent: round(e.segmentSpent), cap: round(e.cap), left: round(Math.max(0, e.cap - e.spent)), segments: e.segments };
}
function readJson(file, fallback) { try { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); } catch { return fallback; } }
function atomicJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temp, JSON.stringify(value), { encoding: 'utf8', mode: 0o600 });
  fs.renameSync(temp, file);
}
function accountFingerprint(account, salt) {
  if (!account || !['chatgpt', 'chatgptAuthTokens'].includes(account.type)) throw Error('Sign in to Codex with a ChatGPT subscription');
  const identity = account.id || account.accountId || account.email;
  if (!identity) throw Error('Account identity unavailable; refusing to merge usage records');
  return crypto.createHmac('sha256', salt).update(String(identity) + ':' + String(account.organizationId || '')).digest('hex').slice(0, 24);
}
module.exports = { DEFAULTS, validateConfig, dayKey, normalizeLimits, normalizeWindow, budget, updateLedger, sameCycle, readJson, atomicJson, accountFingerprint };
