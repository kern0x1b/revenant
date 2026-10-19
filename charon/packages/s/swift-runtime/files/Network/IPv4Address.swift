import Foundation

public struct IPv4Address: Hashable, CustomDebugStringConvertible {
    private let value: UInt32

    public let interface: NWInterface?

    private init(value: UInt32, interface: NWInterface?) {
        self.value = value
        self.interface = interface
    }

    public static let any = IPv4Address(value: 0x0000_0000, interface: nil)
    public static let broadcast = IPv4Address(value: 0xffff_ffff, interface: nil)
    public static let loopback = IPv4Address(value: 0x7f00_0001, interface: nil)
    public static let allHostsGroup = IPv4Address(value: 0xe000_0001, interface: nil)
    public static let allRoutersGroup = IPv4Address(value: 0xe000_0002, interface: nil)
    public static let allReportsGroup = IPv4Address(value: 0xe000_0016, interface: nil)
    public static let mdnsGroup = IPv4Address(value: 0xe000_00fb, interface: nil)

    public var rawValue: Data {
        Data([UInt8(value >> 24), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
    }

    public var isLoopback: Bool {
        interface == nil && value == 0x7f00_0001
    }

    public var isLinkLocal: Bool {
        value >> 16 == 0xa9fe
    }

    public var isMulticast: Bool {
        value >> 28 == 0xe
    }

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

    public init?(_ data: Data, _ interface: NWInterface? = nil) {
        guard data.count == 4 else {
            return nil
        }
        let bytes = [UInt8](data)
        let value = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        self.init(value: value, interface: interface)
    }

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
