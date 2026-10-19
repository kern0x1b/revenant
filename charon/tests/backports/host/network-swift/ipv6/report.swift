import Foundation
import Network

let ipv6Strings = [
    "::", "::1", "1::", "1:2:3:4:5:6:7:8", "1:2:3:4:5:6:7::", "::2:3:4:5:6:7:8", "1::8", "1:2:3:4:5:6:1.2.3.4",
    "::ffff:1.2.3.4", "::1.2.3.4", "1:2:3:4:5:6:7:8:9", "1:2:3:4:5:6:7", "1::2::3", ":::", "1:::2", ":1::", "::1:",
    "1:", ":1", "12345::", "1ffff::", "G::", "fe80::1%en0", "fe80::1%bogus", "::FFFF:1.2.3.4",
    "0:0:0:0:0:0:0:0", "0000::0001", "1.2.3.4", "::1.2.3", "::01.2.3.4", "::1.2.3.256", "::1.2.3.04", "::1.2.3.0x4",
    "::1.2.3.4%en0", "FE80::1", "fe80::1%en0%x", "[::1]", "::1%", "::%en0", "1:2:3:4:5:6:7:8%en0",
    "1:2:3:4:5:6:1.2.3.4%en0", "::ffff:0:1.2.3.4", "1::1.2.3.4", "1:2:3:4:5:6:7:1.2.3.4", "0:0:0:0:0:0:0:1.2",
    "ff02::1%en0", "ff02::1", "ff01::1", "ff05::1", "ff08::1", "ff0e::1", "ff03::1", "ff00::1", "ff0f::1", "ff0a::1",
    "::1.2.3.4.5", "::.1.2.3", "::1.2..3", "::1.2.3.", "::0x1.2.3.4", "::1.2.3.4a", "1:2:3:4:5:6:7:8:", "12345:0::",
    "0:0:0:0:0:0:0:0:0", "::ffff:1.2.3.4%en0", "1:2:3:4:5:6:7:8%", "2002:0102:0304::1", "2002::1", "fe80::", "fc00::1",
    "fd12:3456::1", "fe00::1", "fbff::1", "::1%en0", "::ffff:0:0", "1::1.2.3.4%en0",
    "fe80::1%14", "fe80::1%0", "fe80::1%999999", "fe80::1%1x", "fe80::1%-1", "fe80::1%+1", "febf::1", "fec0::1",
    "00000::", "1:0:0:2:0:0:3:4", "1:0:2:0:3:4:5:6", "::0.0.0.2", "::2", "::0.0.0.0", "::0.0.0.1", "1:1.2.3.4:1",
    "::ffff:1.2.3.4:1", "::1.2.3.4%", "1::%en0", "::1%bogus", "FE80::1%EN0", "ff02::1%en0%x",
    "1::1.2.3.04%en0", "::1:2:3:4:5:6:7", "1:2:3:4:5:6:7:0", "::ffff:0:0:0", "fe80::1%bogus0", "2002::", "fc00::", "fdff::1",
    "::0.0.0.5", "::0.0.1.0", "::0.1.0.0", "::1.0.0.0", "::0.0.0.255", "::0.0.0.256", "::0.1.2.3", "::0.0.0.3%en0",
    "::0.0.1.0%en0", "::ffff:0.0.0.5", "::1%%", "::2%en0", "fe80::1%%", "ff12::1", "ff1e::1", "ff1e::1%en0",
    "1:2:3:4:5:6:7:8::", "1:2:3:4:5:6::7:8", "1:2:3:4:5:6:7::8", "1:2:3:4:5:6::", "1:2:3:4:5:6:7:8:0000"
]

func ipv6Describe(_ address: IPv6Address?) -> String {
    guard let address = address else {
        return "nil"
    }
    let raw = [UInt8](address.rawValue).map { String($0) }.joined(separator: ".")
    let interface = address.interface.map { "\($0.name)/\($0.index)/\($0.type)" } ?? "nil"
    let v4 = address.asIPv4.map { $0.debugDescription } ?? "nil"
    let scope = address.multicastScope.map { "\($0.rawValue)" } ?? "nil"
    return "\(address.debugDescription) raw=\(raw) iface=\(interface) any=\(address.isAny) lo=\(address.isLoopback) "
        + "compat=\(address.isIPv4Compatabile) mapped=\(address.isIPv4Mapped) v4=\(v4) 6to4=\(address.is6to4) "
        + "ll=\(address.isLinkLocal) mc=\(address.isMulticast) scope=\(scope) ula=\(address.isUniqueLocal)"
}

func ipv6Report() {
    for text in ipv6Strings {
        print("parse\t\(text.debugDescription)\t\(ipv6Describe(IPv6Address(text)))")
    }
    for count in [0, 1, 15, 16, 17] {
        let data = Data((0..<count).map { UInt8(0x20 + $0) })
        print("data\(count)\t\(ipv6Describe(IPv6Address(data)))")
    }
    let en0 = IPv6Address("fe80::1%en0")?.interface
    print("data on en0\t\(ipv6Describe(IPv6Address(Data([0xfe, 0x80] + [UInt8](repeating: 0, count: 13) + [1]), en0)))")
    for raw in 0...16 {
        let scope = IPv6Address.Scope(rawValue: UInt8(raw))
        print("scope\(raw)\t\(scope.map { "\($0.rawValue)" } ?? "nil")")
    }
    print("scopes\t\(IPv6Address.Scope.nodeLocal.rawValue) \(IPv6Address.Scope.linkLocal.rawValue) \(IPv6Address.Scope.siteLocal.rawValue) \(IPv6Address.Scope.organizationLocal.rawValue) \(IPv6Address.Scope.global.rawValue)")
    print("any\t\(ipv6Describe(IPv6Address.any))")
    print("broadcast\t\(ipv6Describe(IPv6Address.broadcast))")
    print("loopback\t\(ipv6Describe(IPv6Address.loopback))")
    print("nodeLocalNodes\t\(ipv6Describe(IPv6Address.nodeLocalNodes))")
    print("linkLocalNodes\t\(ipv6Describe(IPv6Address.linkLocalNodes))")
    print("linkLocalRouters\t\(ipv6Describe(IPv6Address.linkLocalRouters))")
    let pairs = [("::1", "0:0:0:0:0:0:0:1"), ("fe80::1%en0", "fe80::1%en0"), ("fe80::1%en0", "fe80::1"), ("::1", "::2")]
    for (left, right) in pairs {
        let a = IPv6Address(left)!, b = IPv6Address(right)!
        print("equal\t\(left) \(right)\t\(a == b)\thash=\(a.hashValue == b.hashValue)")
    }
}
