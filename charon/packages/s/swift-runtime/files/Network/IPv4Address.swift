//===--- IPv4Address.swift - an IPv4 address, with the interface it is on ---===//
//
// The address is four bytes, read from a string by the rules the measured host Network applies (the differential is
// tests/backports/host/network-swift, which compares every row of the corpus): dotted decimal or hexadecimal fields with 0x,
// one to four fields, the last field filling the bytes the others leave, a single field taken modulo 2^32. A zone (`%en0`)
// names an interface the kernel has, and the address is then equal only to one on the same interface.

import Foundation

/// An IPv4 address, and the interface it is on when it names one.
public struct IPv4Address: Hashable, CustomDebugStringConvertible {
    /// The address, as its four bytes read as a big-endian number.
    private let value: UInt32

    /// The interface the address is on, nil when it names none.
    public let interface: NWInterface?

    private init(value: UInt32, interface: NWInterface?) {
        self.value = value
        self.interface = interface
    }

    /// The address 0.0.0.0.
    public static let any = IPv4Address(value: 0x0000_0000, interface: nil)
    /// The address 255.255.255.255.
    public static let broadcast = IPv4Address(value: 0xffff_ffff, interface: nil)
    /// The address 127.0.0.1.
    public static let loopback = IPv4Address(value: 0x7f00_0001, interface: nil)
    /// The group 224.0.0.1, every host on the link.
    public static let allHostsGroup = IPv4Address(value: 0xe000_0001, interface: nil)
    /// The group 224.0.0.2, every router on the link.
    public static let allRoutersGroup = IPv4Address(value: 0xe000_0002, interface: nil)
    /// The group 224.0.0.22, every multicast listener report.
    public static let allReportsGroup = IPv4Address(value: 0xe000_0016, interface: nil)
    /// The group 224.0.0.251, multicast DNS.
    public static let mdnsGroup = IPv4Address(value: 0xe000_00fb, interface: nil)

    /// The four bytes of the address, most significant first.
    public var rawValue: Data {
        Data([UInt8(value >> 24), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
    }

    /// Whether the address is 127.0.0.1 and names no interface: an address with a zone is not the loopback.
    public var isLoopback: Bool {
        interface == nil && value == 0x7f00_0001
    }

    /// Whether the address is in 169.254.0.0/16.
    public var isLinkLocal: Bool {
        value >> 16 == 0xa9fe
    }

    /// Whether the address is in 224.0.0.0/4.
    public var isMulticast: Bool {
        value >> 28 == 0xe
    }

    /// Reads an address from dotted decimal or hexadecimal fields, with an optional zone naming an interface (`192.0.2.1%en0`).
    /// Nil when a field is malformed, a field of the address is out of its range, or the zone names no interface.
    public init?(_ string: String) {
        var address = Substring(string)
        var interface: NWInterface?
        if let percent = string.firstIndex(of: "%") {
            address = string[..<percent]
            guard let named = NWInterface(named: String(string[string.index(after: percent)...])) else {
                return nil
            }
            interface = named
        }
        guard let value = IPv4Address.value(of: address) else {
            return nil
        }
        self.init(value: value, interface: interface)
    }

    /// Reads an address from its four bytes, on the interface given, which is nil for an address that names none. Nil when the
    /// data is not four bytes.
    public init?(_ data: Data, _ interface: NWInterface? = nil) {
        guard data.count == 4 else {
            return nil
        }
        let bytes = [UInt8](data)
        let value = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        self.init(value: value, interface: interface)
    }

    /// The address and its zone, as the string it was read from.
    public var debugDescription: String {
        let dotted = [value >> 24, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff].map { String($0) }.joined(separator: ".")
        guard let interface = interface else {
            return dotted
        }
        return dotted + "%" + interface.name
    }

    public static func == (lhs: IPv4Address, rhs: IPv4Address) -> Bool {
        lhs.value == rhs.value && lhs.interface == rhs.interface
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(interface)
    }

    /// The value of the dotted fields, nil when they are not an address. A field is decimal digits, or 0x and hexadecimal digits,
    /// and a field that is 0x alone is 0 unless it is the last. Each field is accumulated modulo 2^64; a single field is taken
    /// modulo 2^32, and with more fields each must fit the bytes it fills.
    private static func value(of text: Substring) -> UInt32? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count) else {
            return nil
        }
        var fields: [UInt64] = []
        for (position, part) in parts.enumerated() {
            guard let field = field(of: part, last: position == parts.count - 1) else {
                return nil
            }
            fields.append(field)
        }
        if fields.count == 1 {
            return UInt32(truncatingIfNeeded: fields[0])
        }
        var value: UInt32 = 0
        for (position, field) in fields.enumerated() {
            let last = position == fields.count - 1
            guard field < (UInt64(1) << (last ? 8 * (5 - fields.count) : 8)) else {
                return nil
            }
            value |= last ? UInt32(field) : UInt32(field) << UInt32(8 * (3 - position))
        }
        return value
    }

    /// One dotted field of an address, nil when it is malformed. The last field may not be empty.
    private static func field(of part: Substring, last: Bool) -> UInt64? {
        let isHex = part.hasPrefix("0x") || part.hasPrefix("0X")
        let digits = isHex ? part.dropFirst(2) : part
        if digits.isEmpty {
            return isHex && !last ? 0 : nil
        }
        let radix: UInt64 = isHex ? 16 : 10
        var field: UInt64 = 0
        for character in digits {
            guard let digit = character.hexDigitValue, UInt64(digit) < radix else {
                return nil
            }
            field = field &* radix &+ UInt64(digit)
        }
        return field
    }
}
