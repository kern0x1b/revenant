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

@frozen public struct OSLogPrivacy {
    public enum Mask {
        case hash
        case none
        @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
        case _mailName
        @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
        case _mailAddress
        @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
        case _mailSubject
        @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
        case _mailSummary
        @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
        case _mailAccount
        @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
        case _mailbox
        @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
        case _mailboxPath
        @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
        case _mailAttachmentFileName
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public enum _MailMask {
        case name
        case address
        case subject
        case summary
        case account
        case mailbox
        case mailboxPath
        case attachmentFileName
    }

    @usableFromInline
    internal enum PrivacyOption {
        case `private`
        case `public`
        case sensitive
        case auto
    }

    @usableFromInline
    internal let privacy: PrivacyOption
    @usableFromInline
    internal let mask: Mask

    @usableFromInline
    internal init(privacy: PrivacyOption, mask: Mask) {
        self.privacy = privacy
        self.mask = mask
    }

    public static var `public`: OSLogPrivacy {
        return OSLogPrivacy(privacy: .public, mask: .none)
    }

    public static var `private`: OSLogPrivacy {
        return OSLogPrivacy(privacy: .private, mask: .none)
    }

    public static func `private`(mask: Mask) -> OSLogPrivacy {
        return OSLogPrivacy(privacy: .private, mask: mask)
    }

    public static var sensitive: OSLogPrivacy {
        return OSLogPrivacy(privacy: .sensitive, mask: .none)
    }

    public static func sensitive(mask: Mask) -> OSLogPrivacy {
        return OSLogPrivacy(privacy: .sensitive, mask: mask)
    }

    public static var auto: OSLogPrivacy {
        return OSLogPrivacy(privacy: .auto, mask: .none)
    }

    public static func auto(mask: Mask) -> OSLogPrivacy {
        return OSLogPrivacy(privacy: .auto, mask: mask)
    }

    fileprivate var privacySpecifier: String? {
        var hasMask = true
        if case .none = mask {
            hasMask = false
        }
        var isAuto = false
        if case .auto = privacy {
            isAuto = true
        }
        if isAuto && !hasMask {
            return nil
        }
        var specifier: String
        switch privacy {
        case .public:
            specifier = "public"
        case .private:
            specifier = "private"
        case .sensitive:
            specifier = "sensitive"
        case .auto:
            specifier = ""
        }
        if hasMask {
            if !isAuto {
                specifier += ","
            }
            specifier += "mask." + maskSpecifier
        }
        return specifier
    }

    private var maskSpecifier: String {
        if case .hash = mask {
            return "hash"
        }
        if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
            return OSLogPrivacy.mailSpecifier(mask)
        }
        return "hash"
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    private static func mailSpecifier(_ mask: Mask) -> String {
        switch mask {
        case ._mailName:
            return "mailname"
        case ._mailAddress:
            return "mailaddr"
        case ._mailSubject:
            return "mailsubj"
        case ._mailSummary:
            return "mailsumm"
        case ._mailAccount:
            return "mailacco"
        case ._mailbox:
            return "mailbox"
        case ._mailboxPath:
            return "mailmbup"
        case ._mailAttachmentFileName:
            return "mailatta"
        default:
            return "hash"
        }
    }
}

public struct OSLogMessage: ExpressibleByStringInterpolation {
    fileprivate var segments: [Segment]

    fileprivate enum Segment {
        case literal(String)
        case value(String, specifier: String?)
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
            case .value(let text, let specifier):
                if let specifier {
                    format += "%{" + specifier + "}s"
                } else {
                    format += "%s"
                }
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
        segments.append(.value(value, specifier: privacy.privacySpecifier))
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
        segments.append(.value(value.description, specifier: privacy.privacySpecifier))
    }

    private mutating func appendScalar<Value: CustomStringConvertible>(_ value: Value, privacy: OSLogPrivacy) {
        segments.append(.value(value.description, specifier: privacy.privacySpecifier ?? "public"))
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
