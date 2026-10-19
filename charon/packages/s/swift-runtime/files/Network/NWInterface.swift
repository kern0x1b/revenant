//===--- NWInterface.swift - a network interface a path reports ---------===//
//
// The interface is the C API's `nw_interface_t`, which the backports carry (Network/nw13-path.m, registry/Network/ios12.json).
// Name, index and type are read from it by the same calls the backports answer with, so the Swift value says what the C
// object says. Equality is by index and name: measured on the host, the same interface compares equal across two paths
// and to itself, and a second listing of en0 in one path compares equal to the first.

@_implementationOnly import CharonNetworkSeam

/// A network interface of the device, as a network path lists it.
public struct NWInterface: Hashable, CustomDebugStringConvertible {
    /// The kind of an interface.
    public enum InterfaceType: Hashable {
        /// Any other kind of interface.
        case other
        /// A Wi-Fi interface.
        case wifi
        /// A cellular interface.
        case cellular
        /// A wired Ethernet interface.
        case wiredEthernet
        /// The loopback interface.
        case loopback
    }

    /// The interface the C API hands out.
    internal let interface: nw_interface_t

    internal init(_ interface: nw_interface_t) {
        self.interface = interface
    }

    /// The interface of a name, nil when the kernel has none of that name. An address zone names one: `en0` in `fe80::1%en0`.
    internal init?(named name: String) {
        guard let interface = name.withCString({ charon_interface_named($0) }) else {
            return nil
        }
        self.init(interface)
    }

    /// The name of the interface, en0 for Wi-Fi.
    public var name: String {
        String(cString: nw_interface_get_name(interface))
    }

    /// The index of the interface.
    public var index: Int {
        Int(nw_interface_get_index(interface))
    }

    /// The kind of the interface.
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

    /// The name of the interface, which is what it prints as.
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
