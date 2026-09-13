import XCTest
@testable import CodexModelSwitcher

final class ConfigEngineTests: XCTestCase {
    func testPreservesUnrelatedSectionsAndReplacesManagedKeys() {
        let input = """
        notify = ["x"]
        model = "old"

        [mcp_servers.demo]
        command = "demo"

        [projects."/tmp/demo"]
        trust_level = "trusted"
        """
        let output = ConfigEngine.applying(.deepSeekFlash, to: input)
        XCTAssertTrue(output.contains("notify = [\"x\"]"))
        XCTAssertTrue(output.contains("[mcp_servers.demo]"))
        XCTAssertTrue(output.contains("[projects.\"/tmp/demo\"]"))
        XCTAssertEqual(output.components(separatedBy: "model =").count - 1, 1)
        XCTAssertTrue(output.contains("command = \"/usr/bin/security\""))
        XCTAssertFalse(output.contains("experimental_bearer_token"))
    }

    func testSwitchingProviderDoesNotDuplicateManagedSection() {
        let once = ConfigEngine.applying(.deepSeekFlash, to: "model = \"x\"\n")
        let twice = ConfigEngine.applying(.deepSeekPro, to: once)
        XCTAssertEqual(twice.components(separatedBy: "[model_providers.deepseek]").count - 1, 1)
        XCTAssertEqual(twice.components(separatedBy: "[model_providers.deepseek.auth]").count - 1, 1)
    }
}
