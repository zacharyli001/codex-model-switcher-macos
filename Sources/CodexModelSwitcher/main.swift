import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let fm = FileManager.default
    private var codexDir: URL { fm.homeDirectoryForCurrentUser.appendingPathComponent(".codex") }
    private var configURL: URL { codexDir.appendingPathComponent("config.toml") }
    private var modelsURL: URL { codexDir.appendingPathComponent("models.json") }
    private var stateDir: URL { codexDir.appendingPathComponent("model-switcher") }
    private var backupDir: URL { stateDir.appendingPathComponent("last-backup") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle", accessibilityDescription: "Codex 模型切换")
        rebuildMenu()
    }

    private func rebuildMenu(message: String? = nil) {
        let menu = NSMenu()
        let currentText = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let current = ConfigEngine.detectedProfile(in: currentText)
        let heading = NSMenuItem(title: message ?? "当前：\(current?.title ?? "自定义配置")", action: nil, keyEquivalent: "")
        heading.isEnabled = false; menu.addItem(heading); menu.addItem(.separator())
        for profile in Profile.all {
            let item = NSMenuItem(title: profile.title, action: #selector(selectProfile(_:)), keyEquivalent: "")
            item.representedObject = profile.id; item.target = self; item.state = current == profile ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let deepKey = NSMenuItem(title: "保存 DeepSeek API Key…", action: #selector(saveDeepSeekKey), keyEquivalent: ""); deepKey.target = self; menu.addItem(deepKey)
        let sfKey = NSMenuItem(title: "保存 SiliconFlow API Key…", action: #selector(saveSiliconFlowKey), keyEquivalent: ""); sfKey.target = self; menu.addItem(sfKey)
        menu.addItem(.separator())
        let restore = NSMenuItem(title: "恢复切换前配置", action: #selector(restoreBackup), keyEquivalent: "r"); restore.target = self; restore.isEnabled = fm.fileExists(atPath: backupDir.path); menu.addItem(restore)
        let open = NSMenuItem(title: "打开配置目录", action: #selector(openConfig), keyEquivalent: ""); open.target = self; menu.addItem(open)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let profile = Profile.all.first(where: { $0.id == id }) else { return }
        if let account = profile.keyAccount, !Keychain.has(account: account) { showError(SwitcherError.missingKey(profile.title)); return }
        if !profile.compatible {
            let alert = NSAlert(); alert.messageText = "SiliconFlow 需要 Responses 兼容网关"; alert.informativeText = "当前公开接口仍是 Chat Completions。此项默认连接本机 http://127.0.0.1:3456/v1，请先运行 CC Switch 或同类网关。"; alert.addButton(withTitle: "继续切换"); alert.addButton(withTitle: "取消")
            if alert.runModal() != .alertFirstButtonReturn { return }
        }
        do { try switchTo(profile); rebuildMenu(message: "已切换：\(profile.title)（重启 Codex 生效）") } catch { showError(error) }
    }

    private func switchTo(_ profile: Profile) throws {
        try fm.createDirectory(at: codexDir, withIntermediateDirectories: true)
        try makeBackup()
        let original = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let updated = ConfigEngine.applying(profile, to: original)
        guard updated.contains("model = \"\(profile.model)\"") else { throw SwitcherError.invalidConfig("模型字段未生成") }
        if profile.catalogRequired {
            guard let source = Bundle.main.url(forResource: "deepseek-models", withExtension: "json") else { throw SwitcherError.missingResource }
            let data = try Data(contentsOf: source); _ = try JSONSerialization.jsonObject(with: data)
            try data.write(to: modelsURL, options: .atomic)
        }
        try updated.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func makeBackup() throws {
        try fm.createDirectory(at: stateDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: backupDir.path) { try fm.removeItem(at: backupDir) }
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: configURL.path) { try fm.copyItem(at: configURL, to: backupDir.appendingPathComponent("config.toml")) }
        if fm.fileExists(atPath: modelsURL.path) { try fm.copyItem(at: modelsURL, to: backupDir.appendingPathComponent("models.json")) }
        let manifest = "config=\(fm.fileExists(atPath: configURL.path))\nmodels=\(fm.fileExists(atPath: modelsURL.path))\n"
        try manifest.write(to: backupDir.appendingPathComponent("manifest"), atomically: true, encoding: .utf8)
    }

    @objc private func restoreBackup() {
        do {
            let manifest = try String(contentsOf: backupDir.appendingPathComponent("manifest"), encoding: .utf8)
            try restoreOne("config.toml", existed: manifest.contains("config=true"), destination: configURL)
            try restoreOne("models.json", existed: manifest.contains("models=true"), destination: modelsURL)
            rebuildMenu(message: "已恢复切换前配置（重启 Codex 生效）")
        } catch { showError(error) }
    }

    private func restoreOne(_ name: String, existed: Bool, destination: URL) throws {
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        if existed { try fm.copyItem(at: backupDir.appendingPathComponent(name), to: destination) }
    }

    @objc private func saveDeepSeekKey() { promptForKey(account: "deepseek", title: "DeepSeek API Key") }
    @objc private func saveSiliconFlowKey() { promptForKey(account: "siliconflow", title: "SiliconFlow API Key") }
    private func promptForKey(account: String, title: String) {
        let alert = NSAlert(); alert.messageText = "保存 \(title)"; alert.informativeText = "密钥只保存到 macOS 钥匙串，不会写入 Codex 配置或项目。"
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24)); field.placeholderString = "sk-…"; alert.accessoryView = field; alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return }
        do { try Keychain.save(field.stringValue, account: account); rebuildMenu(message: "已安全保存 \(title)") } catch { showError(error) }
    }

    @objc private func openConfig() { NSWorkspace.shared.open(codexDir) }
    private func showError(_ error: Error) { let alert = NSAlert(error: error); alert.runModal() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
