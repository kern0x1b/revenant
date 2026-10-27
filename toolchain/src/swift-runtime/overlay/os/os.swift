import _SwiftRevenantOSOverlayShims

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
    fileprivate let handle: UnsafeMutableRawPointer

    public init(subsystem: String, category: String) {
        self.handle = revenant_os_log_named(subsystem, category)
    }

    public static let `default` = OSLog(subsystem: "", category: "default")
}

public func os_log(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, log: OSLog = .default, type: OSLogType = .default,
                   _ args: CVarArg...) {
    emit(message, log: log, type: type, args)
}

public func os_log(_ type: OSLogType, dso: UnsafeRawPointer? = #dsohandle, log: OSLog = .default, _ message: StaticString,
                   _ args: CVarArg...) {
    emit(message, log: log, type: type, args)
}

private func emit(_ message: StaticString, log: OSLog, type: OSLogType, _ args: [CVarArg]) {
    let error = revenant_os_log_errno()
    guard revenant_os_log_type_enabled(log.handle, type.rawValue) != 0 else {
        return
    }
    let format = message.withUTF8Buffer { buffer in
        buffer.map { CChar(bitPattern: $0) } + [0]
    }
    format.withUnsafeBufferPointer { text in
        withVaList(args) { arguments in
            revenant_os_log_send(log.handle, type.rawValue, text.baseAddress!, arguments, error)
        }
    }
}
