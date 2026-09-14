# Codex Model Switcher（macOS MVP）

> v3.1.4：兼容 macOS 13 及以上系统，提供 Apple Silicon 与 Intel 通用版本；启动时自动检查 GitHub 最新版本并自动更新。

一个原生轻量工具，在 OpenAI、DeepSeek V4 Flash、DeepSeek V4 Pro 与 SiliconFlow 网关配置之间切换。v3 新增“独立 Codex 窗口”：选模型、选项目，然后直接启动，不修改全局配置。

## v3 双模式

- **当前 Codex 切换（默认）**：选择 GPT-5.6 或 DeepSeek，保留当前 Codex 的配置、MCP、插件和权限。原有 OpenAI 聊天会继续显示，但第三方 Provider 不保证能够续写 OpenAI 历史；建议使用 DeepSeek 新建聊天并打开同一项目文件夹。
- **新开独立 Codex 窗口**：选择 GPT-5.6 或 DeepSeek、选择任意项目，在 Terminal 启动一个独立新会话。独立窗口不会显示桌面端已有聊天。
- **安全 Worktree**：对 Git 项目建立独立工作副本，适合 GPT-5.6 和 DeepSeek 同时推进同一项目。
- **共享原目录**：两个窗口直接操作同一批文件；只建议用于任务明确分区的情况。

独立窗口会复用你现有的 MCP、插件、Skills 和项目权限，但把模型配置放在 `~/.codex/model-switcher/sessions/`，因此不会相互抢占全局 `config.toml`。每次打开工具时会从 GitHub 检查最新 DMG；发现新版本会自动下载、备份旧 App 并启动新版本。离线时会继续打开当前版本。

## 安全与配置保护

- API Key 存在 macOS 钥匙串，服务名为 `com.codex-model-switcher.api-key`。
- `config.toml` 只包含通过 `/usr/bin/security` 读取令牌的 `auth.command`，不包含明文密钥。
- 切换只替换顶层模型字段以及本工具管理的 provider 段；MCP、插件、项目权限与桌面设置保持原样。
- 每次切换前完整备份 `config.toml` 与 `models.json` 到 `~/.codex/model-switcher/last-backup/`，菜单可一键恢复。
- 写入采用原子操作；DeepSeek 模型目录写入前会检查 JSON。

## 直接使用（推荐）

请从 GitHub Releases 的 Assets 下载对应版本的 DMG，将 `Codex Model Switcher.app` 拖入“应用程序”后再双击打开。这是不依赖 Xcode 的轻量 GUI 版本。

第一次选择 DeepSeek 或 SiliconFlow 时输入一次 API Key；以后只需双击应用并选择模型。每次切换后完全退出并重新打开 Codex。

## 从源码重新构建

直接版和 Swift 菜单栏源码均要求 macOS 13+；发布的 App 是同时支持 Apple Silicon 与 Intel 的 Universal App。macOS 14.3 已包含在支持范围内。

如果系统提示 Swift 与 SDK 版本不匹配，请先在“系统设置 → 通用 → 软件更新”更新 Xcode Command Line Tools，或安装完整 Xcode 后重新构建。

```bash
chmod +x scripts/build-app.sh
./native/build-direct-app.sh
open "outputs/Codex Model Switcher.app"
```

应用没有 Dock 图标。启动后点击菜单栏的循环箭头图标：

1. 先选择“保存 DeepSeek API Key…”或“保存 SiliconFlow API Key…”。
2. 点击目标模型。
3. 完全退出并重新启动 Codex/ChatGPT 桌面端，使新配置生效。
4. 如需回退，点击“恢复切换前配置”，然后再次重启 Codex。

OpenAI MVP 默认模型为 `gpt-5.6-sol`，可在 `Profile.openAI` 中修改。DeepSeek 官方当前将 V4 Flash 的 Codex slug 命名为 `deepseek-flash`；界面仍显示“DeepSeek V4 Flash”。

## SiliconFlow 说明

截至 2026-09-14，SiliconFlow 公共文档展示的是 `/chat/completions`，而当前 Codex 自定义 provider 只支持 Responses wire protocol。选择 SiliconFlow 后，应用会检测 CC Switch；若缺少，会从 `farion1231/cc-switch` 官方 GitHub 下载最新 DMG 并安装到 `~/Applications`，随后通过 CC Switch 官方深链接导入 SiliconFlow 配置。出于 CC Switch 自身的安全确认机制，首次导入仍需在其预览页点击一次“导入/确认”，并确认路由总开关及 Codex 路由已开启。

v3.1 不再写死 SiliconFlow 模型。应用会使用钥匙串中的 API Key 读取 `https://api.siliconflow.cn/v1/models`，显示账户可用的完整模型 ID，也可手动粘贴模型广场中的 ID。API Key 不会写入模型文件或 Git 仓库。

## DMG 安装

请在 GitHub Release 的 **Assets** 中下载 `Codex-Model-Switcher-macOS-v3.1.4.dmg`。不要下载 GitHub 自动生成的 `Source code (zip)`；它只是源码，不是安装包。

## 开发验证

```bash
swift test
```

测试使用内存中的示例配置，不会改动真实的 `~/.codex`。
