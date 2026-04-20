# ccSwitch

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-orange)
![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-blue)
[![Latest Release](https://img.shields.io/github/v/release/eiis/ccSwitch)](https://github.com/eiis/ccSwitch/releases)
[![Downloads](https://img.shields.io/github/downloads/eiis/ccSwitch/total)](https://github.com/eiis/ccSwitch/releases)

面向 Codex / ChatGPT 的轻量级 macOS 菜单栏账号切换器，支持本地账号管理与基于额度状态的自动切换。

[English](README.md) · [下载](https://github.com/eiis/ccSwitch/releases) · [反馈](https://github.com/eiis/ccSwitch/issues)

* * *

## 截图

| 菜单栏 | 账号管理 |
|:---:|:---:|
| <img src="screenshots/menubar-v013.png" width="320" /> | <img src="screenshots/accounts-v013.png" width="480" /> |

### 菜单栏实时额度显示

<img src="screenshots/menubar-v013.png" width="642" />

* * *

## ✨ 功能

- 多账号切换：本地保存多个 Codex / ChatGPT 账号并一键切换
- 额度可视化：查看每个账号的 5 小时和 7 天 usage，并显示 reset time
- 菜单栏实时状态：在顶部菜单栏直接显示当前账号的 usage 圆环和数字状态
- 临近上限预警：当前账号 usage 到达 90% 后，菜单栏圆环自动变红
- 更简洁的账号管理界面：用更清晰的布局集中展示账号身份、usage 进度、reset time 和操作按钮
- 自动兜底：当前账号额度耗尽时自动切到下一个可用账号
- 安全手动切换：切换前先校验目标账号 usage，避免切到已耗尽账号
- 声音提醒：为手动切换、自动切换和额度耗尽分别播放不同的 macOS 提示音
- 本地优先：直接读写 `~/.codex/auth.json`，不依赖第三方同步
- 菜单栏工作流：平时从菜单栏快速操作，也提供完整账号管理窗口

* * *

## 安装

### 直接下载

从 [Releases](https://github.com/eiis/ccSwitch/releases) 页面下载最新的 `ccSwitch-macos-unsigned.dmg`，打开后将 `ccSwitch.app` 拖到 `/Applications`。

由于当前没有 Apple Developer 账号，这个安装包：

- 使用 ad-hoc 签名
- 未 notarize
- 首次打开时 macOS 可能弹出安全提示

如果系统拦截，右键 `ccSwitch.app`，选择“打开”即可。

如果仍被隔离属性阻止，可执行：

```bash
xattr -dr com.apple.quarantine /Applications/ccSwitch.app
```

### 从源码构建

```bash
git clone https://github.com/eiis/ccSwitch.git
cd ccSwitch
swift build
swift run ccSwitchboardMac
```

> 要求：macOS 13.0 及以上。只有在源码构建时才需要 Xcode Command Line Tools 或完整 Xcode。

* * *

## 使用方式

- `Import Current Auth`：导入当前 `~/.codex/auth.json` 中的账号
- `Add OpenAI Account`：通过浏览器登录新增 OpenAI 账号
- `Set Active`：把本地 Codex 当前账号切到指定已保存账号
- `Refresh`：立即刷新所有账号 usage

手动切换逻辑：

- 切换前先刷新目标账号 usage
- 如果目标账号已耗尽，切换会被阻止
- 如果切换成功，应用会播放简短确认提示音
- 如果当前活跃账号之后耗尽且存在其他可用账号，应用会自动切换

提醒逻辑：

- 当前账号 usage 到达 90% 后，菜单栏圆环会变红并持续显示高风险状态
- 手动切换成功时播放轻提示音
- 自动兜底切换时播放更明显的提示音
- 所有已保存账号都不可用时播放额度耗尽告警音

* * *

## 工作原理

`ccSwitch` 会把导入的账号元数据保存在本地，并通过重写 `~/.codex/auth.json` 来切换当前活跃账号。每个账号的额度信息通过对应账号本地 auth token 和 account ID 调用 ChatGPT usage API 获取。

应用不会代理请求，不会远程托管凭证，也不会修改 Codex 本体，只管理你这台 Mac 上的本地认证状态。

* * *

## 项目结构

```text
Sources/ccSwitchboardMac/
├── App/                         # 应用生命周期与状态管理
├── Core/
│   ├── Auth/                    # auth.json 解析、规范化、OAuth 登录
│   ├── Storage/                 # 本地账号持久化
│   └── Usage/                   # usage API 获取与解释
├── Features/
│   ├── Accounts/                # 账号管理窗口 UI
│   └── MenuBar/                 # 菜单栏下拉 UI
└── Shared/                      # 共享模型、套餐徽章、图标绘制

scripts/package_release.sh       # 构建 release .app 与 dmg
```

* * *

## 打包

本地生成可分发 release：

```bash
./scripts/package_release.sh
```

这个打包过程也会重新生成 app iconset 和 `AppIcon.icns`，确保最终分发包使用当前这版更接近 macOS 应用图标规格的图标资源。

输出：

- `dist/ccSwitch.app`
- `dist/ccSwitch-macos-unsigned.dmg`

* * *

## 限制说明

- 应用控制的是本地 `auth.json`，不保证已经运行中的 Codex 进程一定会立刻重载凭证
- 自动切换依赖最近一次成功获取到的 usage 数据
- 在未 notarize 的前提下，macOS 首次打开会有额外安全提示

* * *

## 许可证

[MIT](LICENSE) © 2026 eiis
