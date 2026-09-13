# Codex Model Switcher（macOS MVP）

一个原生菜单栏工具，在 OpenAI、DeepSeek V4 Flash、DeepSeek V4 Pro 与 SiliconFlow 网关配置之间切换。

## 安全与配置保护

- API Key 存在 macOS 钥匙串，服务名为 `com.codex-model-switcher.api-key`。
- `config.toml` 只包含通过 `/usr/bin/security` 读取令牌的 `auth.command`，不包含明文密钥。
- 切换只替换顶层模型字段以及本工具管理的 provider 段；MCP、插件、项目权限与桌面设置保持原样。
- 每次切换前完整备份 `config.toml` 与 `models.json` 到 `~/.codex/model-switcher/last-backup/`，菜单可一键恢复。
- 写入采用原子操作；DeepSeek 模型目录写入前会检查 JSON。

## 直接使用（推荐）

请从 GitHub Releases 下载对应版本的 ZIP，解压后双击 `Codex Model Switcher.app`。这是不依赖 Xcode 的轻量 GUI 版本。

第一次选择 DeepSeek 或 SiliconFlow 时输入一次 API Key；以后只需双击应用并选择模型。每次切换后完全退出并重新打开 Codex。

## 从源码重新构建

直接版要求 macOS 12+。Swift 菜单栏源码要求 macOS 13+ 与 Xcode Command Line Tools。

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

## 开发验证

```bash
swift test
```

测试使用内存中的示例配置，不会改动真实的 `~/.codex`。
