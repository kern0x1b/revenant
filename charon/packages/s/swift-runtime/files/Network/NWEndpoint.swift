import Foundation

public enum NWEndpoint: Hashable, CustomDebugStringConvertible {
    case hostPort(host: Host, port: Port)
    case service(name: String, type: String, domain: String, interface: NWInterface?)
    case unix(path: String)
    case url(URL)

    public var interface: NWInterface? {
        switch self {
        case .hostPort(let host, _):
            return host.interface
        case .service(_, _, _, let interface):
            return interface
        case .unix, .url:
            return nil
        }
    }

    public var debugDescription: String {
        switch self {
        case .hostPort(let host, let port):
            var separator = ":"
            if case .ipv6 = host {
                separator = "."
            }
            return host.debugDescription + separator + port.debugDescription
        case .service(let name, let type, let domain, let interface):
            return NWEndpoint.serviceText(name: name, type: type, domain: domain) + (interface.map { "%" + $0.name } ?? "")
        case .unix(let path):
            return path
        case .url(let url):
            return url.absoluteString
        }
    }

    private static func serviceText(name: String, type: String, domain: String) -> String {
        let dnsSD = type.hasPrefix("_")
        var text = name.isEmpty && dnsSD && !domain.isEmpty ? "" : name + "."
        text += type
        if dnsSD && !domain.isEmpty {
            if !type.hasSuffix(".") {
                text += "."
            }
            text += domain
            if !domain.hasSuffix(".") {
                text += "."
            }
        } else {
            text += domain
        }
        return text
    }

    public enum Host: Hashable, ExpressibleByStringLiteral, CustomDebugStringConvertible {
        case name(String, NWInterface?)
        case ipv4(IPv4Address)
        case ipv6(IPv6Address)

        public init(_ string: String) {
            if let address = IPv4Address(string) {
                self = .ipv4(address)
            } else if let address = IPv6Address(string) {
                if address.isIPv4Mapped, let mapped = address.asIPv4 {
                    self = .ipv4(mapped)
                } else {
                    self = .ipv6(address)
                }
            } else {
                self = Host.named(string)
            }
        }

        public init(stringLiteral value: String) {
            self.init(value)
        }

        public var interface: NWInterface? {
            switch self {
            case .name(_, let interface):
                return interface
            case .ipv4(let address):
                return address.interface
            case .ipv6(let address):
                return address.interface
            }
        }

        public var debugDescription: String {
            switch self {
            case .name(let name, let interface):
                return interface.map { name + "%" + $0.name } ?? name
            case .ipv4(let address):
                return address.debugDescription
            case .ipv6(let address):
                return address.debugDescription
            }
        }

        private static func named(_ string: String) -> Host {
            if string.isEmpty {
                return .name(".", nil)
            }
            if let percent = string.lastIndex(of: "%"), let interface = NWInterface(named: String(string[string.index(after: percent)...])) {
                return .name(String(string[..<percent]), interface)
            }
            return .name(string, nil)
        }
    }

    public struct Port: Hashable, ExpressibleByIntegerLiteral, CustomDebugStringConvertible {
        public typealias RawValue = UInt16
        public typealias IntegerLiteralType = UInt16

        public let rawValue: UInt16

        public init?(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public init(integerLiteral value: UInt16) {
            self.rawValue = value
        }

        public init?(_ string: String) {
            if let number = Port.number(string) {
                self.rawValue = number
            } else if let entry = getservbyname(string, nil) {
                self.rawValue = UInt16(bigEndian: UInt16(truncatingIfNeeded: entry.pointee.s_port))
            } else {
                return nil
            }
        }

        public var debugDescription: String {
            String(rawValue)
        }

        public static let any: Port = 0
        public static let ssh: Port = 22
        public static let smtp: Port = 25
        public static let http: Port = 80
        public static let pop: Port = 110
        public static let imap: Port = 143
        public static let https: Port = 443
        public static let imaps: Port = 993
        public static let socks: Port = 1080

        private static func number(_ string: String) -> UInt16? {
            let bytes = Array(string.utf8)
            var position = 0
            while position < bytes.count, [0x20, 0x09, 0x0a, 0x0b, 0x0c, 0x0d].contains(bytes[position]) {
                position += 1
            }
            var negative = false
            if position < bytes.count, bytes[position] == 0x2d || bytes[position] == 0x2b {
                negative = bytes[position] == 0x2d
                position += 1
            }
            let digits = bytes[position...]
            guard !digits.isEmpty, digits.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else {
                return nil
            }
            var value: UInt32 = 0
            for digit in digits {
                value = value * 10 + UInt32(digit - 0x30)
                if value > 0xffff {
                    return nil
                }
            }
            if negative && value != 0 {
                return nil
            }
            return UInt16(value)
        }
    }
}
