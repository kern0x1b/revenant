//===--- IPv6Address.swift - an IPv6 address, with the interface it is on ---===//
//
// The address is sixteen bytes, read from a string by the rules the measured host Network applies (the differential is
// tests/backports/host/network-swift/ipv6, which compares the corpus): eight hexadecimal groups of at most four value digits,
// one "::" for zeros, and a dotted IPv4 tail in the last two groups. A zone (`%en0`) names an interface by its name or its
// index, and a zone that names none leaves the address on no interface rather than failing the string. The text printed is the
// one RFC 5952 gives, and an IPv4-mapped or -compatible address prints its tail dotted.

import Foundation

/// An IPv6 address, and the interface it is on when it names one.
public struct IPv6Address: Hashable, CustomDebugStringConvertible {
    /// The scope of a multicast address, the low nibble of its second byte.
    public enum Scope: UInt8 {
        /// Node-local multicast, ff01::/16.
        case nodeLocal = 1
        /// Link-local multicast, ff02::/16.
        case linkLocal = 2
        /// Site-local multicast, ff05::/16.
        case siteLocal = 5
        /// Organization-local multicast, ff08::/16.
        case organizationLocal = 8
        /// Global multicast, ff0e::/16.
        case global = 14
    }

    /// The sixteen bytes of the address, most significant first.
    private let bytes: [UInt8]

    /// The interface the address is on, nil when it names none.
    public let interface: NWInterface?

    private init(bytes: [UInt8], interface: NWInterface?) {
        self.bytes = bytes
        self.interface = interface
    }

    private init(groups: [UInt16], interface: NWInterface? = nil) {
        self.init(bytes: groups.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xff)] }, interface: interface)
    }

    /// The unspecified address ::.
    public static let any = IPv6Address(groups: [0, 0, 0, 0, 0, 0, 0, 0])
    /// Apple's broadcast address, which the host measures as the same address as any.
    public static let broadcast = IPv6Address(groups: [0, 0, 0, 0, 0, 0, 0, 0])
    /// The address ::1.
    public static let loopback = IPv6Address(groups: [0, 0, 0, 0, 0, 0, 0, 1])
    /// The group ff01::1, every node on the interface.
    public static let nodeLocalNodes = IPv6Address(groups: [0xff01, 0, 0, 0, 0, 0, 0, 1])
    /// The group ff02::1, every node on the link.
    public static let linkLocalNodes = IPv6Address(groups: [0xff02, 0, 0, 0, 0, 0, 0, 1])
    /// The group ff02::2, every router on the link.
    public static let linkLocalRouters = IPv6Address(groups: [0xff02, 0, 0, 0, 0, 0, 0, 2])

    /// The sixteen bytes of the address.
    public var rawValue: Data {
        Data(bytes)
    }

    /// Whether the address is the unspecified address ::.
    public var isAny: Bool {
        bytes.allSatisfy { $0 == 0 }
    }

    /// Whether the address is ::1, with or without a zone.
    public var isLoopback: Bool {
        bytes == IPv6Address.loopback.bytes
    }

    /// Whether the address is an IPv4-compatible address, ::a.b.c.d, other than :: and ::1.
    public var isIPv4Compatabile: Bool {
        leadingZeros(12) && tail > 1
    }

    /// Whether the address is an IPv4-mapped address, ::ffff:a.b.c.d.
    public var isIPv4Mapped: Bool {
        leadingZeros(10) && bytes[10] == 0xff && bytes[11] == 0xff
    }

    /// The IPv4 address the mapped or compatible address carries, on the same interface.
    public var asIPv4: IPv4Address? {
        guard isIPv4Mapped || isIPv4Compatabile else {
            return nil
        }
        return IPv4Address(Data(bytes[12..<16]), interface)
    }

    /// Whether the address is in 2002::/16.
    public var is6to4: Bool {
        bytes[0] == 0x20 && bytes[1] == 0x02
    }

    /// Whether the address is in fe80::/10.
    public var isLinkLocal: Bool {
        bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80
    }

    /// Whether the address is in ff00::/8.
    public var isMulticast: Bool {
        bytes[0] == 0xff
    }

    /// The scope of a multicast address, nil for a scope that is not one of the cases of Scope.
    public var multicastScope: Scope? {
        guard isMulticast else {
            return nil
        }
        return Scope(rawValue: bytes[1] & 0x0f)
    }

    /// Whether the address is in fc00::/7.
    public var isUniqueLocal: Bool {
        bytes[0] & 0xfe == 0xfc
    }

    /// Reads an address from its text: eight groups or one "::", an optional dotted IPv4 tail, and an optional zone after one
    /// %. Nil when the text is malformed. A zone that names no interface leaves the address on none.
    public init?(_ string: String) {
        var address = Substring(string)
        var interface: NWInterface?
        if let percent = string.firstIndex(of: "%") {
            address = string[..<percent]
            let zone = string[string.index(after: percent)...]
            if zone.contains("%") {
                return nil
            }
            interface = zone.isEmpty ? nil : IPv6Address.zoneInterface(zone)
        }
        guard let groups = IPv6Address.groups(of: address) else {
            return nil
        }
        self.init(groups: groups, interface: interface)
    }

    /// Reads an address from its sixteen bytes, on the interface given, which is nil for an address that names none. Nil when
    /// the data is not sixteen bytes.
    public init?(_ data: Data, _ interface: NWInterface? = nil) {
        guard data.count == 16 else {
            return nil
        }
        self.init(bytes: [UInt8](data), interface: interface)
    }

    /// The address as RFC 5952 writes it, with the tail of a mapped or compatible address dotted, and its zone.
    public var debugDescription: String {
        let groups = (0..<8).map { UInt16(bytes[2 * $0]) << 8 | UInt16(bytes[2 * $0 + 1]) }
        let dotted = isIPv4Mapped || (isIPv4Compatabile && groups[6] != 0)
        let count = dotted ? 6 : 8
        var start = -1
        var length = 0
        var position = 0
        while position < count {
            var end = position
            while end < count && groups[end] == 0 {
                end += 1
            }
            if end - position >= 2 && end - position > length {
                start = position
                length = end - position
            }
            position = max(end, position + 1)
        }
        var text: String
        if start < 0 {
            text = groups.map { String($0, radix: 16) }.joined(separator: ":")
        } else {
            let head = groups[0..<start].map { String($0, radix: 16) }
            var tail = groups[(start + length)..<count].map { String($0, radix: 16) }
            if dotted {
                tail.append(bytes[12..<16].map { String($0) }.joined(separator: "."))
            }
            text = head.joined(separator: ":") + "::" + tail.joined(separator: ":")
        }
        guard let interface = interface else {
            return text
        }
        return text + "%" + interface.name
    }

    public static func == (lhs: IPv6Address, rhs: IPv6Address) -> Bool {
        lhs.bytes == rhs.bytes && lhs.interface == rhs.interface
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes)
        hasher.combine(interface)
    }

    /// Whether the first count bytes are zero.
    private func leadingZeros(_ count: Int) -> Bool {
        bytes[0..<count].allSatisfy { $0 == 0 }
    }

    /// The last four bytes as a number.
    private var tail: UInt32 {
        bytes[12..<16].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    /// The interface a zone names: a name, or a number that is the index of one. A zone of digits is read as an index.
    private static func zoneInterface(_ zone: Substring) -> NWInterface? {
        guard zone.allSatisfy({ ("0"..."9").contains($0) }) else {
            return NWInterface(named: String(zone))
        }
        var buffer = [CChar](repeating: 0, count: 64)
        guard let index = UInt32(zone), if_indextoname(index, &buffer) != nil else {
            return nil
        }
        return NWInterface(named: String(cString: buffer))
    }

    /// The sixteen-bit groups of the text, nil when it is malformed. A "::" stands for at least one group.
    private static func groups(of text: Substring) -> [UInt16]? {
        let pieces = String(text).components(separatedBy: "::")
        guard pieces.count <= 2, let head = fields(pieces[0], dotted: pieces.count == 1) else {
            return nil
        }
        if pieces.count == 1 {
            return head.count == 8 ? head : nil
        }
        guard let tail = fields(pieces[1], dotted: true), head.count + tail.count <= 7 else {
            return nil
        }
        return head + [UInt16](repeating: 0, count: 8 - head.count - tail.count) + tail
    }

    /// The groups of one piece of the text, with a dotted IPv4 tail as its last two groups where that is allowed.
    private static func fields(_ piece: String, dotted: Bool) -> [UInt16]? {
        if piece.isEmpty {
            return []
        }
        let tokens = piece.components(separatedBy: ":")
        var groups: [UInt16] = []
        for (position, token) in tokens.enumerated() {
            if token.contains(".") {
                guard dotted, position == tokens.count - 1, let value = dottedValue(token) else {
                    return nil
                }
                groups += [UInt16(value >> 16), UInt16(value & 0xffff)]
            } else {
                guard let group = hexValue(token) else {
                    return nil
                }
                groups.append(group)
            }
        }
        return groups
    }

    /// A group of one to four value digits, nil when it is empty, not hexadecimal, or too large. Leading zeros do not count.
    private static func hexValue(_ token: String) -> UInt16? {
        guard !token.isEmpty else {
            return nil
        }
        var value: UInt32 = 0
        for character in token {
            guard let digit = character.hexDigitValue else {
                return nil
            }
            value = value * 16 + UInt32(digit)
            if value > 0xffff {
                return nil
            }
        }
        return UInt16(value)
    }

    /// The four decimal fields of a dotted IPv4 tail as one number, nil when they are not four fields of at most 255.
    private static func dottedValue(_ token: String) -> UInt32? {
        let fields = token.components(separatedBy: ".")
        guard fields.count == 4 else {
            return nil
        }
        var value: UInt32 = 0
        for field in fields {
            guard !field.isEmpty, field.allSatisfy({ ("0"..."9").contains($0) }) else {
                return nil
            }
            var octet: UInt32 = 0
            for character in field {
                octet = octet * 10 + UInt32(character.wholeNumberValue ?? 0)
                if octet > 255 {
                    return nil
                }
            }
            value = value << 8 | octet
        }
        return value
    }
}
