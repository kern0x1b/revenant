import Foundation
import Network

let ipv4Strings = [
    "1", "1.2", "1.2.3", "1.2.3.4", "4294967295", "4294967296", "256", "1.256", "1.2.65536", "1.2.65535", "1.2.3.256",
    "0", "0.0.0", "0.0.0.0.", ".1.2.3", "1.2.3.", "1.2..3", "08.1.1.1", "09.1.1.1", "0x", "0xff.0.0.1", "0XFF.0.0.1",
    "0x1.2.3.4", "1.0x2.3.4", "1.2.3.4%", "1.2.3.4%%x", "1.2.3.4%en0%x", "1.2.3.4%x y", "+1.2.3.4", "1.2.3.4\n",
    "1.2.3.4a", "1e2.1.1.1", "1 .2.3.4", "00000000001.2.3.4", "1.2.3.00000000000000000000004",
    "0x.0", "0x.", "0x0", "0X", "0x1g", "0x1.0x", "0x1.0x.1", "0x.0x.0x.0x", "0.", "0.0x", "1.0x", "1.0x1",
    "00x1", "0x00000000000000000000001", "0xffffffffffffffffffff", "0x100000000", "0x100000000.1", "1.0xffffff",
    "00", "000000000000000000000000000000000000000000000000000000000001", "1.2.3.4.", "1.2.3.4.5",
    "1.0", "1.0.0", "0.0.0.0", "255.0.0.0", "256.0.0.0", "1.2.3.0x100", "1.2.3.0xff", "1.2.3.0x1ff",
    "169.254.1.1%en0", "224.0.0.1%en0", "224.0.0.1", "169.254.1.1", "255.255.255.255%en0", "0xG.0.0.1",
    "0x.1.1.1", "1.2.3.4%en0 ", "1.2.3.4%EN0", "1.2.3.4%en0%", "0.0.0.0%en0", "0x7f.0.0.1%en0", "1.2.3.4%en0\n",
    "4294967297", "5000000000", "18446744073709551617", "1.16777216", "1.16777217", "1.2.3.4%bogus0", "1.2.3.4%en0",
    "127.0.0.1%en0", "1.2.3.4%en0", "10.0.0.1%en0", "1.2.3.4%1", "1.2.3.4%14", "1.2.3.4%999999",
    "1.4294967297", "1.18446744073709551617", "1.2.4294967297", "1.0x100000000", "1.0x1000000", "1.4294967296",
    "0x1.0x100000000", "127.1.2.3", "127.255.255.255", "128.0.0.0", "126.255.255.255", "169.254.0.0", "169.254.255.255",
    "169.253.255.255", "169.255.0.0", "223.255.255.255", "224.0.0.0", "239.255.255.255", "240.0.0.0", "0.0.0.0", "255.255.255.255",
    "127.0.0.1%en0", "127.0.0.1%bogus0", "1.2.3.4%en0"
]

func ipv4Describe(_ address: IPv4Address?) -> String {
    guard let address = address else {
        return "nil"
    }
    let raw = [UInt8](address.rawValue).map { String($0) }.joined(separator: ".")
    let interface = address.interface.map { "\($0.name)/\($0.index)/\($0.type)" } ?? "nil"
    return "\(address.debugDescription) raw=\(raw) iface=\(interface) lo=\(address.isLoopback) ll=\(address.isLinkLocal) mc=\(address.isMulticast)"
}

func ipv4Report() {
    for text in ipv4Strings {
        print("parse\t\(text.debugDescription)\t\(ipv4Describe(IPv4Address(text)))")
    }
    for count in [0, 1, 3, 4, 5] {
        let data = Data((0..<count).map { UInt8(10 + $0) })
        print("data\(count)\t\(ipv4Describe(IPv4Address(data)))")
    }
    let en0 = IPv4Address("1.2.3.4%en0")?.interface
    print("data loopback on en0\t\(ipv4Describe(IPv4Address(Data([127, 0, 0, 1]), en0)))")
    print("data 10/8 on en0\t\(ipv4Describe(IPv4Address(Data([10, 0, 0, 1]), en0)))")
    print("data 127 on nil\t\(ipv4Describe(IPv4Address(Data([127, 1, 2, 3]), nil)))")
    print("any\t\(ipv4Describe(IPv4Address.any))")
    print("broadcast\t\(ipv4Describe(IPv4Address.broadcast))")
    print("loopback\t\(ipv4Describe(IPv4Address.loopback))")
    print("allHostsGroup\t\(ipv4Describe(IPv4Address.allHostsGroup))")
    print("allRoutersGroup\t\(ipv4Describe(IPv4Address.allRoutersGroup))")
    print("allReportsGroup\t\(ipv4Describe(IPv4Address.allReportsGroup))")
    print("mdnsGroup\t\(ipv4Describe(IPv4Address.mdnsGroup))")
    let pairs = [("1.2.3.4", "0x1.2.3.4"), ("1.2.3.4", "1.2.3.4%en0"), ("1.2.3.4%en0", "1.2.3.4%en0"),
                 ("1.2.3.4%en0", "1.2.3.4%en0"), ("127.0.0.1%en0", "127.0.0.1%en0"), ("1.2.3.4", "1.2.3.5")]
    for (left, right) in pairs {
        let a = IPv4Address(left)!, b = IPv4Address(right)!
        print("equal\t\(left) \(right)\t\(a == b)\thash=\(a.hashValue == b.hashValue)")
    }
}
