# Codex Quota Peek 0.1.0-alpha.1

A quiet Windows quota overlay: it appears when Codex is in front, hides when you switch away, and keeps real remaining quota separate from your suggested daily budget.

Windows x64 portable ZIP includes Node.js. Extract and run `Launch.cmd`. Codex must already be installed and signed in with a ChatGPT subscription. This is an unofficial, unsigned early-test release.

**Yellow:** actual short-window and weekly remaining allowance. **Blue:** today's monitored weekly consumption and suggested remainder. Tray controls provide display mode, settings, status and exit.

Defaults: 15-second foreground / 60-second background polling; failures back off to five minutes. Local data lives in `%LOCALAPPDATA%\CodexQuotaPeek`. No separate passwords or API keys are requested by this tool.

Validated: 22 automated Node tests, PowerShell syntax, synthetic WPF rendering and one real local quota query. See `docs/TESTING.md` for open gates; compatibility across computers/plans is not yet established. The screenshot contains synthetic data.

每日建议是均摊规划，不是官方每日限额；“今日已用”从首次监测起统计。请下载ZIP便携包并解压启动，不要把GitHub源码ZIP当作带运行环境的发行包。

Please report Windows/Codex version, installation method, reproduction steps and sanitized status errors. Do not upload account credentials, emails or personal ledgers.
