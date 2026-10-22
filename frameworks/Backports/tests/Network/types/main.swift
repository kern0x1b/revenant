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
expect(revenantInterfaceType(linkType: 0xff, flags: 0) == .cellular, "IFT_CELLULAR is cellular")
expect(revenantInterfaceType(linkType: 0x06, flags: 0) == .wifi, "an Ethernet link is Wi-Fi on iOS")
expect(revenantInterfaceType(linkType: 0x01, flags: 0) == .other, "IFT_OTHER is other")
expect(revenantInterfaceType(linkType: 0x06, flags: 0x8) == .loopback, "IFF_LOOPBACK is loopback whatever the link type")
expect(revenantInterfaceType(named: "lo0") == .loopback, "lo0 is loopback by its link type")
expect(revenantInterfaceType(named: "pdp_ip9") == .cellular, "an interface with no link address falls back to its name")
print("network interface types ok")
