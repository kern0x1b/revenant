import UIKit
import Foundation

@_spi(Probe) public enum _Unsupported {
    nonisolated(unsafe) static var reported: Set<String> = []
    nonisolated(unsafe) static var pending: Set<String> = []

    public static var used: [String] { reported.sorted() }
    public static var notImplemented: [String] { pending.sorted() }

    nonisolated(unsafe) static var reasons: [String: String] = [:]

    public static var reportPath: String? {
        if let path = ProcessInfo.processInfo.environment["EIDOLON_REPORT"] { return path }
        if FileManager.default.fileExists(atPath: "/var/charon") { return "/var/charon/swiftui-ignored.txt" }
        return nil
    }

    static func note(_ api: String, _ reason: String) {
        guard !reported.contains(api) else { return }
        reported.insert(api)
        reasons[api] = reason
        let line = "[SwiftUI] \(api) ignored on iOS 6: \(reason)\n"
        fputs(line, stderr)   // not FileHandle: that raises when an app has no stderr, as one started by SpringBoard has not
        NSLog("%@", "[SwiftUI] \(api) ignored on iOS 6: \(reason)")
        writeReport()
    }

    static func pendingNote(_ api: String) {
        guard !pending.contains(api) else { return }
        pending.insert(api)
        let line = "[SwiftUI] \(api) is declared but not implemented yet\n"
        fputs(line, stderr)
        NSLog("%@", line)
        writeReport()
    }

    public static func writeReport() {
        guard let path = reportPath else { return }
        var lines = used.map { "ignored\t\($0)\t\(reasons[$0] ?? "")" }
        lines += notImplemented.map { "unimplemented\t\($0)\tnot implemented in Eidolon yet" }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
}

func ignored<V: View>(_ view: V, _ api: String, _ reason: String) -> V {
    if !api.isEmpty { _Unsupported.note(api, reason) }
    return view
}

func unimplemented<V: View>(_ view: V, _ api: String) -> V {
    _Unsupported.pendingNote(api)
    return view
}
