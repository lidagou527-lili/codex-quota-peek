# Test status

Date: 2026-10-28. Local system: Windows 11 x64. This document separates checks already executed from release follow-up work.

## Executed locally

- 22 Node tests: quota normalization, missing windows, unrelated buckets, config validation, timezone day boundaries, fixed daily budgets, repeated observations, correction noise, reset jitter, same-day reset accumulation, account separation, cross-day baselines, exhausted suggestions, fingerprints, atomic storage, RPC initialization/correlation/errors/timeouts/child exit.
- Node syntax validation.
- PowerShell parser checks and a WPF preview render using synthetic data.
- Collector smoke query against the installed Codex engine with separate temporary test data. Returned short and weekly windows successfully.

## Manual release gates

Do not mark these complete merely because a unit test passes:

- [ ] A second computer without developer runtime paths can extract and launch the portable build.
- [ ] Uninstalled Codex, signed-out Codex and API-key-only login show actionable states.
- [ ] Missing short/weekly windows work against actual affected plans.
- [ ] Real quota reset, local midnight, account switching and sleep/resume preserve the intended accounting.
- [ ] Multimonitor and 100%/150%/200% scaling remain readable and recover an off-screen position.
- [ ] Long-running foreground/background switching does not interfere with work.
- [ ] Network failures, throttling and recovery are tested beyond mocked RPC failures.

Target before removing alpha label: at least five independent installations and three workdays without blocking failures. This is a suggested gate, not completed research.

## Reproduce

Run `npm test`, `npm run check` and `powershell -File scripts/check-windows.ps1`. Query real limits using `Start.ps1 -Check -DataDirectory <unique-temp-directory>`. The `-Check` mode requires an installed/authenticated Codex engine and creates local quota state; never publish that directory.
