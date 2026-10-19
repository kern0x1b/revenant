// swift-tools-version:5.5

import PackageDescription

// This list should be updated whenever SwiftPM adds support for a new platform.
// See: https://bugs.swift.org/browse/SR-13814
let supportedPlatforms: [Platform] = [
    .macOS,
    .macCatalyst,
    .iOS,
    .watchOS,
    .tvOS,
    .driverKit,
    .linux,
    .android,
    .windows,
    .wasi,
]

let package = Package(
    name: "Combine",
    products: [
        // A single module named `Combine`, matching Apple's own framework, so
        // code written against system Combine builds unchanged where no system
        // Combine exists (legacy iOS, Linux, WASI). It bundles the core, the
        // Dispatch scheduler and the Foundation integration (Timer, RunLoop,
        // OperationQueue, NotificationCenter) in one module.
        .library(name: "Combine", targets: ["Combine"]),
    ],
    targets: [
        .target(name: "CombineHelpers"),
        .target(
            name: "Combine",
            dependencies: [
                .target(name: "CombineHelpers",
                        condition: .when(platforms: supportedPlatforms.except([.wasi])))
            ],
            exclude: [
                "RootProtocols.swift.gyb",
                "Concurrency/Publisher+Concurrency.swift.gyb",
                "Publishers/Publishers.Encode.swift.gyb",
                "Publishers/Publishers.MapKeyPath.swift.gyb",
                "Publishers/Publishers.Catch.swift.gyb"
            ],
            swiftSettings: [.define("WASI", .when(platforms: [.wasi]))]
        ),
        // The upstream regression suite. It runs where no system Combine
        // shadows our module (Linux, WASI, or a legacy-iOS target); on a modern
        // Apple host `import Combine` resolves to the system framework instead.
        .testTarget(
            name: "OpenCombineTests",
            dependencies: ["Combine"],
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("WASI", .when(platforms: [.wasi]))
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)

// MARK: Helpers

extension Array where Element == Platform {
    func except(_ exceptions: [Platform]) -> [Platform] {
        return filter { !exceptions.contains($0) }
    }
}
