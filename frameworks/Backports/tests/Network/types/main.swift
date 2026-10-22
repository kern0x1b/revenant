import Foundation
import SystemConfiguration

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAILED: \(message)")
        exit(1)
    }
}

expect(revenantInterfaceTypes([]).isEmpty, "an unreachable path has no interface type")
expect(revenantInterfaceTypes([.reachable]) == [.wifi], "a reachable path not on WWAN is wifi")
expect(revenantInterfaceTypes([.reachable, .isLocalAddress]) == [.loopback], "a loopback endpoint is loopback")
#if os(iOS)
expect(revenantInterfaceTypes([.reachable, .isWWAN]) == [.cellular], "a reachable path on WWAN is cellular")
#endif

let loopback = revenantPath(for: [.reachable, .isLocalAddress])
expect(loopback.usesInterfaceType(.loopback), "a loopback path uses the loopback interface")
expect(!loopback.usesInterfaceType(.wifi), "a loopback path does not use wifi")
expect(!revenantPath(for: []).usesInterfaceType(.loopback), "an unreachable path uses no interface")
print("network interface types ok")
