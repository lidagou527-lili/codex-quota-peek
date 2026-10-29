# Third-party notices

The portable Windows x64 release includes an unmodified Node.js executable downloaded from https://nodejs.org/dist/. Its complete license, including bundled third-party notices, is distributed alongside it as `runtime/NODE-LICENSE.txt`. The exact version and archive SHA256 are recorded in `BUILD-INFO.json` in the release ZIP. Source checkouts do not include this binary.

The application uses Windows PowerShell, WPF, Windows Forms and Windows APIs available on the user's system. Those components are not redistributed in this repository.

The application starts the user's separately installed Codex executable and uses its App Server protocol. Codex is not bundled. The OpenAI Codex source project is at https://github.com/openai/codex; its own licenses and terms apply independently. This project's MIT license does not relicense third-party software or grant rights to OpenAI trademarks.
