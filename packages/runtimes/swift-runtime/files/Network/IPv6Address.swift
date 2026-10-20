import Foundation

public struct IPv6Address: Hashable, CustomDebugStringConvertible {
    public enum Scope: UInt8 {
        case nodeLocal = 1
        case linkLocal = 2
        case siteLocal = 5
        case organizationLocal = 8
        case global = 14
    }

    private let bytes: [UInt8]

    public let interface: NWInterface?

    private init(bytes: [UInt8], interface: NWInterface?) {
        self.bytes = bytes
        self.interface = interface
    }

    private init(groups: [UInt16], interface: NWInterface? = nil) {
        self.init(bytes: groups.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xff)] }, interface: interface)
    }

    public static let any = IPv6Address(groups: [0, 0, 0, 0, 0, 0, 0, 0])
    public static let broadcast = IPv6Address(groups: [0, 0, 0, 0, 0, 0, 0, 0])
    public static let loopback = IPv6Address(groups: [0, 0, 0, 0, 0, 0, 0, 1])
    public static let nodeLocalNodes = IPv6Address(groups: [0xff01, 0, 0, 0, 0, 0, 0, 1])
    public static let linkLocalNodes = IPv6Address(groups: [0xff02, 0, 0, 0, 0, 0, 0, 1])
    public static let linkLocalRouters = IPv6Address(groups: [0xff02, 0, 0, 0, 0, 0, 0, 2])

    public var rawValue: Data {
        Data(bytes)
    }

    public var isAny: Bool {
        bytes.allSatisfy { $0 == 0 }
    }

    public var isLoopback: Bool {
        bytes == IPv6Address.loopback.bytes
    }

    public var isIPv4Compatabile: Bool {
        leadingZeros(12) && tail > 1
    }

    public var isIPv4Mapped: Bool {
        leadingZeros(10) && bytes[10] == 0xff && bytes[11] == 0xff
    }

    public var asIPv4: IPv4Address? {
        guard isIPv4Mapped || isIPv4Compatabile else {
            return nil
        }
        return IPv4Address(Data(bytes[12..<16]), interface)
    }

    public var is6to4: Bool {
        bytes[0] == 0x20 && bytes[1] == 0x02
    }

    public var isLinkLocal: Bool {
        bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80
    }

    public var isMulticast: Bool {
        bytes[0] == 0xff
    }

    public var multicastScope: Scope? {
        guard isMulticast else {
            return nil
        }
        return Scope(rawValue: bytes[1] & 0x0f)
    }

    public var isUniqueLocal: Bool {
        bytes[0] & 0xfe == 0xfc
    }

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

    public init?(_ data: Data, _ interface: NWInterface? = nil) {
        guard data.count == 16 else {
            return nil
        }
        self.init(bytes: [UInt8](data), interface: interface)
    }

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

    private func leadingZeros(_ count: Int) -> Bool {
        bytes[0..<count].allSatisfy { $0 == 0 }
    }

    private var tail: UInt32 {
        bytes[12..<16].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

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
