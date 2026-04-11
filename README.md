# ccSwitch

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-orange)
![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-blue)
[![Latest Release](https://img.shields.io/github/v/release/eiis/ccSwitch)](https://github.com/eiis/ccSwitch/releases)
[![Downloads](https://img.shields.io/github/downloads/eiis/ccSwitch/total)](https://github.com/eiis/ccSwitch/releases)

Lightweight macOS menu bar account switcher for Codex / ChatGPT, with local auth management and usage-aware switching.

[中文](README.zh.md) · [Download](https://github.com/eiis/ccSwitch/releases) · [Feedback](https://github.com/eiis/ccSwitch/issues)

* * *

## ✨ Features

- Multi-account switching — Save multiple Codex / ChatGPT accounts locally and switch with one click
- Usage visibility — Inspect 5-hour and 7-day usage windows for each account
- Auto fallback — Automatically switches away from the current account when usage is exhausted
- Safe manual switching — Pre-checks target account usage before applying the switch
- Local-first — Reads and writes `~/.codex/auth.json` directly, with no third-party sync
- Menu bar workflow — Fast access from the menu bar, plus a larger account management window

* * *

## Installation

### Direct Download

Download the latest `ccSwitch-macos-unsigned.zip` from the [Releases](https://github.com/eiis/ccSwitch/releases) page, unzip it, and move `ccSwitch.app` to your `/Applications` folder.

Because this build is distributed without an Apple Developer account:

- it is ad-hoc signed
- it is not notarized
- macOS may warn on first launch

If macOS blocks the app, right-click `ccSwitch.app` and choose `Open`.

If Gatekeeper quarantine still prevents launch, run:

```bash
xattr -dr com.apple.quarantine /Applications/ccSwitch.app
```

### Build from Source

```bash
git clone https://github.com/eiis/ccSwitch.git
cd ccSwitch
swift build
swift run ccSwitchboardMac
```

> Requirements: macOS 13.0 or later. Xcode Command Line Tools or full Xcode is required only for building from source.

* * *

## Usage

- Import Current Auth: import the account currently stored in `~/.codex/auth.json`
- Add OpenAI Account: add another account through browser-based OpenAI login
- Set Active: switch the local Codex auth to the selected saved account
- Refresh: update all account usage information immediately

Manual switching behavior:

- The app refreshes the target account usage before switching
- If the target account is already exhausted, the switch is blocked
- If the active account later becomes exhausted and another usable account exists, the app can auto-switch

* * *

## How It Works

`ccSwitch` stores imported account metadata locally, then swaps the active account by rewriting `~/.codex/auth.json`. Usage information is fetched from the ChatGPT usage API using each account's local auth token and account ID.

The app does not proxy requests, host credentials remotely, or modify Codex itself. It only manages local auth state on your Mac.

* * *

## Project Structure

```text
Sources/ccSwitchboardMac/
├── App/                         # App lifecycle and state management
├── Core/
│   ├── Auth/                    # auth.json parsing, normalization, OAuth login
│   ├── Storage/                 # local account persistence
│   └── Usage/                   # usage API fetching and interpretation
├── Features/
│   ├── Accounts/                # account manager window UI
│   └── MenuBar/                 # menu bar dropdown UI
└── Shared/                      # shared models, badges, icon rendering

scripts/package_release.sh       # builds release .app bundle and zip
```

* * *

## Packaging

To build a distributable release bundle locally:

```bash
./scripts/package_release.sh
```

Output:

- `dist/ccSwitch.app`
- `dist/ccSwitch-macos-unsigned.zip`

* * *

## Limitations

- The app controls local `auth.json`; it does not guarantee a running Codex process will reload credentials immediately
- Automatic switching depends on the latest fetched usage data
- Without notarization, first-launch friction on macOS is expected

* * *

## License

[MIT](LICENSE) © 2026 eiis

