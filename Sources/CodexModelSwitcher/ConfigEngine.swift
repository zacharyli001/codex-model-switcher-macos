import Foundation

struct Profile: Equatable {
    let id: String
    let title: String
    let provider: String
    let model: String
    let baseURL: String?
    let keyAccount: String?
    let catalogRequired: Bool
    let compatible: Bool

    static let openAI = Profile(id: "openai", title: "OpenAI", provider: "openai", model: "gpt-5.6-sol", baseURL: nil, keyAccount: nil, catalogRequired: false, compatible: true)
    static let deepSeekFlash = Profile(id: "deepseek-flash", title: "DeepSeek V4 Flash", provider: "deepseek", model: "deepseek-flash", baseURL: "https://api.deepseek.com/", keyAccount: "deepseek", catalogRequired: true, compatible: true)
    static let deepSeekPro = Profile(id: "deepseek-v4-pro", title: "DeepSeek V4 Pro", provider: "deepseek", model: "deepseek-v4-pro", baseURL: "https://api.deepseek.com/", keyAccount: "deepseek", catalogRequired: true, compatible: true)
    static let siliconFlow = Profile(id: "siliconflow", title: "SiliconFlow（兼容网关）", provider: "siliconflow", model: "deepseek-ai/DeepSeek-V4-Flash", baseURL: "http://127.0.0.1:3456/v1", keyAccount: "siliconflow", catalogRequired: false, compatible: false)
    static let all = [openAI, deepSeekFlash, deepSeekPro, siliconFlow]
}

enum SwitcherError: LocalizedError {
    case invalidConfig(String), missingKey(String), missingResource
    var errorDescription: String? {
        switch self {
        case .invalidConfig(let value): return "配置检查失败：\(value)"
        case .missingKey(let value): return "请先保存 \(value) API Key"
        case .missingResource: return "应用内缺少 DeepSeek 模型目录"
        }
    }
}

struct ConfigEngine {
    static let managedKeys = ["model", "model_provider", "preferred_auth_method", "forced_login_method", "model_reasoning_effort", "web_search", "model_catalog_json"]

    static func detectedProfile(in text: String) -> Profile? {
        let values = topLevelValues(in: text)
        return Profile.all.first { $0.provider == (values["model_provider"] ?? "openai") && $0.model == values["model"] }
    }

    static func topLevelValues(in text: String) -> [String: String] {
        var result: [String: String] = [:]
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") { break }
            guard !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\"") && value.hasSuffix("\"") { value.removeFirst(); value.removeLast() }
            result[key] = value
        }
        return result
    }

    static func applying(_ profile: Profile, to original: String) -> String {
        var lines = original.components(separatedBy: .newlines)
        let firstSection = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") } ?? lines.count
        let keyPattern = "^(" + managedKeys.joined(separator: "|") + ")\\s*="
        let regex = try! NSRegularExpression(pattern: keyPattern)
        var head = Array(lines[..<firstSection]).filter { line in
            regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) == nil
        }
        while head.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { head.removeLast() }
        var overlay = ["model = \"\(profile.model)\"", "model_provider = \"\(profile.provider)\""]
        if profile.provider != "openai" {
            overlay += ["preferred_auth_method = \"apikey\"", "forced_login_method = \"api\"", "model_reasoning_effort = \"high\"", "web_search = \"disabled\""]
        }
        if profile.catalogRequired { overlay.append("model_catalog_json = \"~/.codex/models.json\"") }
        head = overlay + (head.isEmpty ? [] : [""]) + head
        lines = head + Array(lines[firstSection...])
        var result = lines.joined(separator: "\n")
        if let baseURL = profile.baseURL, let account = profile.keyAccount {
            result = replacingSection("model_providers.\(profile.provider)", in: result, with: """
            [model_providers.\(profile.provider)]
            name = "\(profile.title)"
            base_url = "\(baseURL)"
            wire_api = "responses"

            [model_providers.\(profile.provider).auth]
            command = "/usr/bin/security"
            args = ["find-generic-password", "-s", "com.codex-model-switcher.api-key", "-a", "\(account)", "-w"]
            timeout_ms = 5000
            refresh_interval_ms = 0
            """)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    static func replacingSection(_ name: String, in text: String, with replacement: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var output: [String] = []
        var skipping = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[\(name)]" || trimmed == "[\(name).auth]" { skipping = true; continue }
            if skipping && trimmed.hasPrefix("[") {
                if trimmed.hasPrefix("[\(name).") { continue }
                skipping = false
            }
            if !skipping { output.append(line) }
        }
        while output.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { output.removeLast() }
        output.append("")
        output.append(replacement)
        return output.joined(separator: "\n")
    }
}
