import PackageDescription

let package = Package(
    name: "surftool",
    dependencies: [.package(path: "swift-syntax")],
    targets: [.executableTarget(name: "surftool", dependencies: [
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
    ])]
)
