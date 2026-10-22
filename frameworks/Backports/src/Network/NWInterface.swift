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

    internal init?(named name: String) {
        let index = Int(if_nametoindex(name))
        guard index != 0 else {
            return nil
        }
        self.name = name
        self.index = index
    }

    public var type: InterfaceType {
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
