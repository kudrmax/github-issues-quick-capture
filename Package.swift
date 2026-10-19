// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IssueBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "IssueBar", targets: ["IssueBar"]),
    ],
    targets: [
        .target(name: "IssueBarCore"),
        .executableTarget(name: "IssueBar", dependencies: ["IssueBarCore"]),
        .testTarget(name: "IssueBarCoreTests", dependencies: ["IssueBarCore"]),
        .testTarget(name: "IssueBarTests", dependencies: ["IssueBar", "IssueBarCore"]),
    ]
)
