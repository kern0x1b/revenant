// swift-tools-version:5.9
import PackageDescription

// surftool: the surface of a `.swiftinterface`, read with swift-syntax's SwiftParser.
//   surface-swiftui.sh <SDK26> > apple-26-surface.tsv
// swift-syntax is Apache-2.0 (https://github.com/swiftlang/swift-syntax), taken by path so the gate
// it is a generation step, not something api-invented.lua runs.
let package = Package(
    name: "surftool",
    dependencies: [.package(path: "swift-syntax")],
    targets: [.executableTarget(name: "surftool", dependencies: [
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
    ])]
)
