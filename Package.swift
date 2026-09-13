// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexModelSwitcher",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexModelSwitcher", targets: ["CodexModelSwitcher"])],
    targets: [
        .executableTarget(
            name: "CodexModelSwitcher",
            resources: [.copy("deepseek-models.json")],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("Security")]
        ),
        .testTarget(name: "CodexModelSwitcherTests", dependencies: ["CodexModelSwitcher"])
    ]
)
