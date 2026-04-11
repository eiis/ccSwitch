# ccSwitchboard Mac

`ccSwitchboard Mac` 是一个本地 macOS 菜单栏应用，用来管理和切换多个 Codex / ChatGPT 账号。

它直接读写本机的 `~/.codex/auth.json`，不会依赖云端同步，也不会把账号信息上传到第三方服务。

## 功能

- 导入当前本机 `Codex` 登录态
- 通过 OpenAI 登录新增账号
- 保存多个账号并一键切换
- 查看账号 5 小时 / 7 天额度使用情况
- 当前账号额度耗尽时自动切换到下一个可用账号
- 手动切换前先校验额度，避免切到已耗尽账号
- 菜单栏和管理窗口都能快速查看账号状态

## 运行要求

- macOS 13 或更高
- 本机已安装 `Codex`，并存在 `~/.codex/auth.json`
- 构建环境需要 Xcode Command Line Tools 或完整 Xcode

## 本地开发

```bash
swift build
swift run ccSwitchboardMac
```

## Release 打包

仓库提供了一个无开发者账号也能用的打包脚本：

```bash
./scripts/package_release.sh
```

执行后会生成：

- `dist/ccSwitchboardMac.app`
- `dist/ccSwitchboardMac-macos-unsigned.zip`

## 用户如何直接使用

因为没有 Apple Developer 账号，这个 release 包是：

- 未上架
- 未 notarize
- 使用 ad-hoc 签名

这意味着用户下载后第一次打开时，macOS 可能提示“无法验证开发者”。

可用方式：

1. 把 `ccSwitchboardMac.app` 拖到 `Applications`
2. 右键应用，选择“打开”
3. 再次确认打开

如果系统仍然拦截，可以执行：

```bash
xattr -dr com.apple.quarantine /Applications/ccSwitchboardMac.app
```

## 账号与数据存储

- 本地账号列表保存在应用自己的本地存储文件中
- 当前激活账号通过覆盖 `~/.codex/auth.json` 实现
- 应用不会替你托管账号，也不会替你同步到别的机器

## 当前已实现的额度切换逻辑

- 应用启动后会自动刷新所有账号 usage
- 后台会周期性静默刷新 usage
- 手动切换账号前会先检查目标账号 usage
- 如果当前账号额度耗尽，并且存在其他可用账号，会自动切换

## 限制说明

- 它控制的是本机 `auth.json`
- 如果某个正在运行的 Codex 进程已经缓存了旧凭证，是否立刻生效取决于 Codex 本身的实现
- 未 notarize 的 macOS 应用首次打开体验不如正式签名应用

## 目录说明

- `Sources/ccSwitchboardMac`：应用源码
- `scripts/package_release.sh`：构建并打包 release
- `dist/`：输出目录

