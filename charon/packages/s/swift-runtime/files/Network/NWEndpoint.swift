//===--- NWEndpoint.swift - an endpoint: a host and port, a service, a path, or a URL ---===//
//
// The host and the port of an endpoint, read from a string by the rules the measured host Network applies (the differential is
// tests/backports/host/network-swift/endpoint, which compares the corpus). A host is an IPv4 address, or an IPv6 address that
// is not mapped (a mapped one is the IPv4 address it carries), or else a name, which keeps its text and takes the interface
// of a trailing zone that names one. A port is a decimal number, read the way strtol reads one, or a service name the
// services database has.

import Foundation

/// An endpoint of a connection, which the rest of Network's connections are made to.
public enum NWEndpoint: Hashable, CustomDebugStringConvertible {
    /// A host and a port.
    case hostPort(host: Host, port: Port)
    /// A service of the local network: its name, its type and its domain, and the interface it is found on, if it is one.
    case service(name: String, type: String, domain: String, interface: NWInterface?)
    /// A socket of this device, at its path.
    case unix(path: String)
    /// A URL.
    case url(URL)

    /// The interface the endpoint is on, nil when it names none. A service and a host and port answer with the host's or the
    /// service's; a path and a URL name none.
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

    /// The endpoint as it prints: host and port joined by a colon (by a dot for an IPv6 host), a service as its name, type and
    /// domain joined as DNS-SD does, a path as it is, and a URL as it is written.
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

    /// The name, type and domain of a service joined the way the host joins them. A DNS-SD type (one that starts with an
    /// underscore) has its dots set around a domain; any other type is joined to its domain as it is.
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

    /// The host of an endpoint: a name, or an address.
    public enum Host: Hashable, ExpressibleByStringLiteral, CustomDebugStringConvertible {
        /// A host name, with the interface its zone named, if it named one.
        case name(String, NWInterface?)
        /// An IPv4 address.
        case ipv4(IPv4Address)
        /// An IPv6 address that is not IPv4-mapped.
        case ipv6(IPv6Address)

        /// Reads a host from its text: an IPv4 address, an IPv6 address (a mapped one is read as the IPv4 address), or a name.
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

        /// The interface the host is on, nil when it names none.
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

        /// The host as it prints: its name or address, and its zone.
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

        /// A name, which the zone after its last % names an interface for when the zone is one; otherwise it is the whole text.
        /// The empty name is the root, which is what the host reads it as.
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

    /// The port of an endpoint.
    public struct Port: Hashable, ExpressibleByIntegerLiteral, CustomDebugStringConvertible {
        /// The number of the port.
        public typealias RawValue = UInt16
        /// The integer a port is written as.
        public typealias IntegerLiteralType = UInt16

        /// The number of the port.
        public let rawValue: UInt16

        /// The port of a number.
        public init?(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public init(integerLiteral value: UInt16) {
            self.rawValue = value
        }

        /// Reads a port from its text: a number the way strtol reads one, with leading white space and a sign, or the name of a
        /// service the services database has. Nil when it is neither.
        public init?(_ string: String) {
            if let number = Port.number(string) {
                self.rawValue = number
            } else if let entry = getservbyname(string, nil) {
                self.rawValue = UInt16(bigEndian: UInt16(truncatingIfNeeded: entry.pointee.s_port))
            } else {
                return nil
            }
        }

        /// The port as its number.
        public var debugDescription: String {
            String(rawValue)
        }

        /// Port 0.
        public static let any: Port = 0
        /// Port 22.
        public static let ssh: Port = 22
        /// Port 25.
        public static let smtp: Port = 25
        /// Port 80.
        public static let http: Port = 80
        /// Port 110.
        public static let pop: Port = 110
        /// Port 143.
        public static let imap: Port = 143
        /// Port 443.
        public static let https: Port = 443
        /// Port 993.
        public static let imaps: Port = 993
        /// Port 1080.
        public static let socks: Port = 1080

        /// The number of the text when all of it is a number that strtol reads: leading white space, a sign, decimal digits.
        /// Nil when it is not one, or when it is out of the range of a port.
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
