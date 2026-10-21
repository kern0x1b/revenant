@_implementationOnly import RevenantNetworkSeam

public struct NWInterface: Hashable, CustomDebugStringConvertible {
    public enum InterfaceType: Hashable {
        case other
        case wifi
        case cellular
        case wiredEthernet
        case loopback
    }

    internal let interface: nw_interface_t

    internal init(_ interface: nw_interface_t) {
        self.interface = interface
    }

    internal init?(named name: String) {
        guard let interface = name.withCString({ revenant_interface_named($0) }) else {
            return nil
        }
        self.init(interface)
    }

    public var name: String {
        String(cString: nw_interface_get_name(interface))
    }

    public var index: Int {
        Int(nw_interface_get_index(interface))
    }

    public var type: InterfaceType {
        switch nw_interface_get_type(interface) {
        case nw_interface_type_wifi:
            return .wifi
        case nw_interface_type_cellular:
            return .cellular
        case nw_interface_type_wired:
            return .wiredEthernet
        case nw_interface_type_loopback:
            return .loopback
        default:
            return .other
        }
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
