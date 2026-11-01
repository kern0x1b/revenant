import _SwiftRevenantOSOverlayShims
import Darwin

public struct OSLogType: Hashable, RawRepresentable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let `default` = OSLogType(rawValue: 0x00)
    public static let info = OSLogType(rawValue: 0x01)
    public static let debug = OSLogType(rawValue: 0x02)
    public static let error = OSLogType(rawValue: 0x10)
    public static let fault = OSLogType(rawValue: 0x11)
}

public struct OSLog {
    fileprivate let handle: UnsafeMutableRawPointer?

    public init(subsystem: String, category: String) {
        self.handle = revenant_os_log_linked() != 0 ? revenant_os_log_named(subsystem, category) : nil
    }

    public static let `default` = OSLog(subsystem: "", category: "default")
}

public func os_log(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, log: OSLog = .default, type: OSLogType = .default,
                   _ args: CVarArg...) {
    emit(formatBytes(message), log: log, type: type, args)
}

public func os_log(_ type: OSLogType, dso: UnsafeRawPointer? = #dsohandle, log: OSLog = .default, _ message: StaticString,
                   _ args: CVarArg...) {
    emit(formatBytes(message), log: log, type: type, args)
}

public enum OSLogPrivacy {
    case auto
    case `public`
    case `private`
    case sensitive
}

public struct OSLogMessage: ExpressibleByStringInterpolation {
    fileprivate var segments: [Segment]

    fileprivate enum Segment {
        case literal(String)
        case value(String, isPublic: Bool)
    }

    public init(stringLiteral value: String) {
        segments = [.literal(value)]
    }

    public init(stringInterpolation: OSLogInterpolation) {
        segments = stringInterpolation.segments
    }

    fileprivate func rendered() -> (format: [CChar], arguments: [CVarArg], strings: [UnsafeMutablePointer<CChar>]) {
        var format = ""
        var arguments: [CVarArg] = []
        var strings: [UnsafeMutablePointer<CChar>] = []
        for segment in segments {
            switch segment {
            case .literal(let text):
                for character in text {
                    format += character == "%" ? "%%" : String(character)
                }
            case .value(let text, let isPublic):
                format += isPublic ? "%{public}s" : "%{private}s"
                let pointer = strdup(text)!
                arguments.append(pointer)
                strings.append(pointer)
            }
        }
        return (Array(format.utf8CString), arguments, strings)
    }
}

public struct OSLogInterpolation: StringInterpolationProtocol {
    fileprivate var segments: [OSLogMessage.Segment] = []

    public init(literalCapacity: Int, interpolationCount: Int) {}

    public mutating func appendLiteral(_ literal: String) {
        segments.append(.literal(literal))
    }

    public mutating func appendInterpolation(_ value: String, privacy: OSLogPrivacy = .auto) {
        segments.append(.value(value, isPublic: privacy == .public))
    }

    public mutating func appendInterpolation(_ value: Int, privacy: OSLogPrivacy = .auto) {
        appendScalar(value, privacy: privacy)
    }

    public mutating func appendInterpolation(_ value: Int32, privacy: OSLogPrivacy = .auto) {
        appendScalar(value, privacy: privacy)
    }

    public mutating func appendInterpolation(_ value: Int64, privacy: OSLogPrivacy = .auto) {
        appendScalar(value, privacy: privacy)
    }

    public mutating func appendInterpolation(_ value: UInt, privacy: OSLogPrivacy = .auto) {
        appendScalar(value, privacy: privacy)
    }

    public mutating func appendInterpolation(_ value: UInt32, privacy: OSLogPrivacy = .auto) {
        appendScalar(value, privacy: privacy)
    }

    public mutating func appendInterpolation(_ value: UInt64, privacy: OSLogPrivacy = .auto) {
        appendScalar(value, privacy: privacy)
    }

    public mutating func appendInterpolation(_ value: Double, privacy: OSLogPrivacy = .auto) {
        appendScalar(value, privacy: privacy)
    }

    public mutating func appendInterpolation(_ value: Bool, privacy: OSLogPrivacy = .auto) {
        appendScalar(value, privacy: privacy)
    }

    public mutating func appendInterpolation<Value: CustomStringConvertible>(_ value: Value, privacy: OSLogPrivacy = .auto) {
        segments.append(.value(value.description, isPublic: privacy == .public))
    }

    private mutating func appendScalar<Value: CustomStringConvertible>(_ value: Value, privacy: OSLogPrivacy) {
        segments.append(.value(value.description, isPublic: privacy != .private && privacy != .sensitive))
    }
}

@available(iOS 14.0, *)
public struct Logger {
    private let osLog: OSLog

    public init(subsystem: String, category: String) {
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }

    public init() {
        self.osLog = .default
    }

    public func log(level: OSLogType, _ message: OSLogMessage) {
        let rendered = message.rendered()
        defer { rendered.strings.forEach { free($0) } }
        emit(rendered.format, log: osLog, type: level, rendered.arguments)
    }

    public func debug(_ message: OSLogMessage) {
        log(level: .debug, message)
    }

    public func info(_ message: OSLogMessage) {
        log(level: .info, message)
    }

    public func notice(_ message: OSLogMessage) {
        log(level: .default, message)
    }

    public func error(_ message: OSLogMessage) {
        log(level: .error, message)
    }

    public func fault(_ message: OSLogMessage) {
        log(level: .fault, message)
    }
}

private func formatBytes(_ message: StaticString) -> [CChar] {
    return message.withUTF8Buffer { buffer in
        buffer.map { CChar(bitPattern: $0) } + [0]
    }
}

private func emit(_ format: [CChar], log: OSLog, type: OSLogType, _ args: [CVarArg]) {
    let error = revenant_os_log_errno()
    format.withUnsafeBufferPointer { text in
        guard let handle = log.handle else {
            withVaList(args) { arguments in
                revenant_os_log_fallback(type.rawValue, text.baseAddress!, arguments, Int32(args.count), error)
            }
            return
        }
        withVaList(args) { arguments in
            guard revenant_os_log_type_enabled(handle, type.rawValue) != 0 else {
                return
            }
            revenant_os_log_send(handle, type.rawValue, text.baseAddress!, arguments, error)
        }
    }
}
