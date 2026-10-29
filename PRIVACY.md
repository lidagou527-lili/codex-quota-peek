# Privacy / 隐私说明

Codex Quota Peek stores quota percentages, reset timestamps, daily budget entries, UI position, settings and connection status locally under `%LOCALAPPDATA%\CodexQuotaPeek`. It stores up to 14 days of daily entries. Account identifiers are salted and hashed for local separation; raw emails and login tokens are not written by the helper. This is pseudonymous local data, not a claim of irreversible anonymization.

The collector starts the installed Codex engine and calls `initialize`, `account/read` (without forced token refresh) and `account/rateLimits/read`. Authentication and network requests are handled by Codex. The helper never initiates model conversations or changes login state. Codex's own behavior, data handling and policies remain applicable. This tool adds no analytics server, telemetry endpoint, advertising SDK or upload service.

Foreground detection reads the current process identifier, executable path and product name locally. It does not capture screenshots, read window contents, inspect messages or persist browsing history. The synthetic preview command renders this tool's own WPF visual with demo data.

Build-time downloads come from nodejs.org. CI runs on GitHub Actions. Neither is used to upload your local quota records. A source/release audit must exclude all personal runtime data before publication.

Exit the tray app to stop monitoring. Delete the app's local data directory to clear its records. Removing those records does not delete or sign out your Codex account.

本工具仅在本机保存额度、重置时间、每日预算、设置和位置。账户隔离使用本地随机盐生成的指纹，不保存原始邮箱或凭据。读取前台进程信息只用于显示/隐藏，不录屏、不读聊天内容、不记录浏览历史。联网与既有登录由已安装的Codex引擎处理；本工具不添加遥测上传服务器，不发起模型对话。退出后停止监测；删除本地数据即可清除本工具记录，不会退出Codex。
