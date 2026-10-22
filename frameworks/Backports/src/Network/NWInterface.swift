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

    internal init?(named name: String) {
        let index = Int(if_nametoindex(name))
        guard index != 0 else {
            return nil
        }
        self.name = name
        self.index = index
        self.type = revenantInterfaceType(named: name)
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

private let revenantIFTEther: UInt8 = 0x06
private let revenantIFTLoop: UInt8 = 0x18
private let revenantIFTCellular: UInt8 = 0xff

func revenantInterfaceType(linkType: UInt8, flags: Int32) -> NWInterface.InterfaceType {
    if flags & IFF_LOOPBACK != 0 || linkType == revenantIFTLoop {
        return .loopback
    }
    switch linkType {
    case revenantIFTCellular:
        return .cellular
    case revenantIFTEther:
        return .wifi
    default:
        return .other
    }
}

func revenantInterfaceType(named name: String) -> NWInterface.InterfaceType {
    var list: UnsafeMutablePointer<ifaddrs>? = nil
    guard getifaddrs(&list) == 0, let first = list else {
        return revenantNamedType(name)
    }
    defer {
        freeifaddrs(list)
    }
    var entry: UnsafeMutablePointer<ifaddrs>? = first
    while let current = entry {
        if let address = current.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK), String(cString: current.pointee.ifa_name) == name {
            let link = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_dl.self)
            return revenantInterfaceType(linkType: link.pointee.sdl_type, flags: Int32(current.pointee.ifa_flags))
        }
        entry = current.pointee.ifa_next
    }
    return revenantNamedType(name)
}

private func revenantNamedType(_ name: String) -> NWInterface.InterfaceType {
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
