# Codex Quota Peek

**A quiet Windows quota overlay that appears only while you work in Codex. Unofficial.**

[中文](README.md) · [Privacy](PRIVACY.md) · [Test coverage](docs/TESTING.md)

![Synthetic demonstration, not live account data](docs/preview.png)

Yellow shows actual short-window and weekly remaining quota. Blue shows today's monitored consumption of weekly quota. Switch away from Codex and the overlay hides; collection continues in the background.

## Install

Download `codex-quota-peek-0.1.0-alpha.1-win-x64.zip` from **Releases**, extract it, and double-click `Launch.cmd`. Do not run from inside the ZIP. The portable archive bundles Node.js; the source ZIP does not.

Requires Windows 10/11 x64, Windows PowerShell 5.1, and Codex installed and signed in with a ChatGPT subscription. Tested on one Windows 11 x64 computer; Windows 10, other installations and plans need external testing. This is a standalone helper, not an official plugin, browser extension, API credit meter, or cross-platform application. The alpha is unsigned. Respect administrator script policies.

Use the tray menu to switch between Codex-only and always-visible mode, open settings/status, or exit. Drag to reposition. The small `×` exits. There is no automatic startup or updater; launch it again when needed.

## Quota versus suggested budget

`5h` and `Week` are provider-reported remaining percentages. The short-window label follows its actual duration. Missing windows show `--`.

`Today: 6pp used · 5.8pp suggested left` means six **percentage points of the full weekly allowance** consumed since monitoring began today, with a suggested 5.8pp left. It is not 6% of the short-window pool, a token count, or a guaranteed number of messages.

Daily suggested total is fixed at the first valid sample:

`remaining weekly quota / max(days until weekly reset, 1) × (1 − reserve)`

Default reserve: 10%. Monitoring cannot reconstruct activity before its first sample. Every calendar day is treated equally. This is a planning estimate, not an official daily limit or a prediction of working hours.

Accounts have separate local ledgers. Same-day quota resets preserve prior daily consumption and allocate a fresh suggestion; only consumption within the current quota cycle is drawn as a blue segment. Old observations are preserved during errors, with the last successful timestamp visible.

## Configuration and privacy

Settings and data live in `%LOCALAPPDATA%\CodexQuotaPeek`. Open settings from the tray. Example: [settings.example.json](settings.example.json).

- `codexPath`: optional full path to `codex.exe`. Automatic discovery searches the desktop engine installation and then PATH. A CLI found on PATH must already be authenticated.
- `foregroundSeconds` / `backgroundSeconds`: defaults 15/60, minimum 15. Failures back off up to five minutes. This is polling, not token-by-token live telemetry.
- `reservePercent`: default 10, allowed 0–90; today's allocated budget remains fixed until the next day/cycle.
- `timeZone`: `local` or an IANA zone, for daily accounting. Display timestamps/countdowns use Windows local time.
- `showMode`: `codex` or `always`. `language`: `auto`, `zh`, or `en`.

The helper uses Codex App Server's read-only account and rate-limit requests and reuses Codex-managed authentication. It does not ask for passwords, cookies or API keys. Account identity is used in memory to derive a salted local fingerprint; no raw email or credentials are stored by this tool. See [PRIVACY.md](PRIVACY.md).

## Alpha limitations

Desktop detection depends on process metadata; installation variants, display scaling and multiple monitors need testing. App Server protocol changes may require updates. No weekly allowance/reset means no daily budget. Invalid account identity prevents merging usage. Corrupt ledgers start a new baseline; gaps and resets during downtime may lose historical consumption. Ledgers retain 14 days. The alpha has no auto-update, startup registration, Claude/Doubao support or work-duration predictions.

Exit, delete the extracted app directory, and optionally remove `%LOCALAPPDATA%\CodexQuotaPeek` to uninstall. This does not log you out of Codex.

## Develop

Requires Node.js 22+. Run `npm test`, `npm run check`, and `powershell -File scripts/check-windows.ps1`. Run `Start.ps1 -Check -DataDirectory <temporary-directory>` for a real quota query. Do not share one data directory across processes. `Start.ps1 -PreviewPath docs/preview.png` renders synthetic data. `scripts/build.ps1` fetches Node 24 LTS from nodejs.org, validates its official SHA256, and creates a portable ZIP using a file allowlist.

Report reproducible bugs with Windows/Codex versions and sanitized status messages. Never attach login files, access tokens, emails or full ledgers.

Author: **lidagou527-lili**. MIT-licensed project code. Uses the [Codex App Server protocol](https://developers.openai.com/codex/app-server). Not affiliated with or endorsed by OpenAI. See [third-party notices](THIRD-PARTY-NOTICES.md) for the bundled runtime.
