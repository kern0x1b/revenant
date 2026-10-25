import Foundation

public struct NWInterface: Hashable, CustomDebugStringConvertible {
    public enum InterfaceType: Hashable {
        case other
        case wifi
        case cellular
        case wiredEthernet
        case loopback
    }

    public let name: String
    public let index: Int
    public let type: InterfaceType

    internal init(name: String, index: Int, type: InterfaceType) {
        self.name = name
        self.index = index
        self.type = type
    }

    internal init?(named name: String) {
        self.init(named: name, kernelType: nil)
    }

    internal init?(named name: String, kernelType: UInt8?) {
        let index = Int(if_nametoindex(name))
        guard index != 0 else {
            return nil
        }
        self.type = NWInterface.interfaceType(name: name, kernelType: kernelType)
        self.name = name
        self.index = index
    }

    private static func interfaceType(name: String, kernelType: UInt8?) -> InterfaceType {
        switch kernelType {
        case UInt8(IFT_LOOP):
            return .loopback
        case UInt8(IFT_CELLULAR):
            return .cellular
        case UInt8(IFT_ETHER):
            return isWiFiInterface(name) ? .wifi : .wiredEthernet
        default:
            break
        }
        if name.hasPrefix("lo") {
            return .loopback
        }
        if name.hasPrefix("pdp_ip") {
            return .cellular
        }
        if name.hasPrefix("en") {
            return .wifi
        }
        return .other
    }

    public var debugDescription: String {
        name
    }

    public static func == (lhs: NWInterface, rhs: NWInterface) -> Bool {
        lhs.index == rhs.index && lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(index)
        hasher.combine(name)
    }
}

#if os(macOS)
import SystemConfiguration

private func isWiFiInterface(_ name: String) -> Bool {
    guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
        return false
    }
    return interfaces.contains { interface in
        (SCNetworkInterfaceGetBSDName(interface) as String?) == name
            && (SCNetworkInterfaceGetInterfaceType(interface) as String?) == (kSCNetworkInterfaceTypeIEEE80211 as String)
    }
}
#else
private func isWiFiInterface(_ name: String) -> Bool {
    name.hasPrefix("en")
}
#endif
