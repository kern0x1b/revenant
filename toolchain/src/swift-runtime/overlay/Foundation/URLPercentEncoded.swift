import Foundation

private struct Reference {
    let user: String?
    let password: String?
    let host: String?
    let port: String?
    let path: String
    let query: String?
    let fragment: String?

    init(_ text: String) {
        var rest = Substring(text)
        var fragment: String?
        if let mark = rest.firstIndex(of: "#") {
            fragment = String(rest[rest.index(after: mark)...])
            rest = rest[..<mark]
        }
        var query: String?
        if let mark = rest.firstIndex(of: "?") {
            query = String(rest[rest.index(after: mark)...])
            rest = rest[..<mark]
        }
        if let end = Reference.schemeEnd(rest) {
            rest = rest[rest.index(after: end)...]
        }
        var user: String?
        var password: String?
        var host: String?
        var port: String?
        if rest.hasPrefix("//") {
            rest = rest.dropFirst(2)
            let end = rest.firstIndex(of: "/") ?? rest.endIndex
            var authority = rest[..<end]
            rest = rest[end...]
            if let at = authority.lastIndex(of: "@") {
                let information = authority[..<at]
                authority = authority[authority.index(after: at)...]
                if let colon = information.firstIndex(of: ":") {
                    user = String(information[..<colon])
                    password = String(information[information.index(after: colon)...])
                } else {
                    user = String(information)
                }
            }
            let tail: Substring
            if authority.hasPrefix("["), let close = authority.firstIndex(of: "]") {
                host = String(authority[authority.index(after: authority.startIndex)..<close])
                tail = authority[authority.index(after: close)...]
            } else if let colon = authority.lastIndex(of: ":") {
                host = String(authority[..<colon])
                tail = authority[colon...]
            } else {
                host = String(authority)
                tail = ""
            }
            if tail.hasPrefix(":") {
                port = String(tail.dropFirst())
            }
        }
        self.user = user
        self.password = password
        self.host = host
        self.port = port
        self.path = String(rest)
        self.query = query
        self.fragment = fragment
    }

    private static func schemeEnd(_ text: Substring) -> Substring.Index? {
        guard let first = text.first, first.isASCII, first.isLetter else {
            return nil
        }
        for index in text.indices {
            let character = text[index]
            if character == ":" {
                return index
            }
            if !(character.isASCII && (character.isLetter || character.isNumber || "+-.".contains(character))) {
                return nil
            }
        }
        return nil
    }
}

private func digitValue(_ byte: UInt8) -> UInt8? {
    switch byte {
    case 0x30 ... 0x39:
        return byte - 0x30
    case 0x41 ... 0x46:
        return byte - 0x41 + 10
    case 0x61 ... 0x66:
        return byte - 0x61 + 10
    default:
        return nil
    }
}

private func decoded(_ text: String) -> String? {
    let source = Array(text.utf8)
    guard source.contains(0x25) else {
        return text
    }
    var bytes: [UInt8] = []
    var index = 0
    while index < source.count {
        if source[index] == 0x25, index + 2 < source.count, let high = digitValue(source[index + 1]), let low = digitValue(source[index + 2]) {
            bytes.append(high << 4 | low)
            index += 3
        } else {
            bytes.append(source[index])
            index += 1
        }
    }
    return String(bytes: bytes, encoding: .utf8)
}

extension URL {
    private var reference: Reference {
        return Reference(absoluteURL.absoluteString)
    }

    public func host(percentEncoded: Bool = true) -> String? {
        let reference = self.reference
        guard let host = reference.host, !host.isEmpty || reference.user != nil || reference.password != nil || reference.port != nil else {
            return nil
        }
        return percentEncoded ? host : decoded(host)
    }

    public func user(percentEncoded: Bool = true) -> String? {
        guard let user = reference.user else {
            return nil
        }
        return percentEncoded ? user : decoded(user)
    }

    public func password(percentEncoded: Bool = true) -> String? {
        guard let password = reference.password else {
            return nil
        }
        return percentEncoded ? password : decoded(password)
    }

    public func path(percentEncoded: Bool = true) -> String {
        let path = reference.path
        return percentEncoded ? path : decoded(path) ?? ""
    }

    public func query(percentEncoded: Bool = true) -> String? {
        guard let query = reference.query else {
            return nil
        }
        return percentEncoded ? query : decoded(query)
    }

    public func fragment(percentEncoded: Bool = true) -> String? {
        guard let fragment = reference.fragment else {
            return nil
        }
        return percentEncoded ? fragment : decoded(fragment)
    }

    public enum DirectoryHint: Sendable {
        case isDirectory
        case notDirectory
        case checkFileSystem
        case inferFromPath
    }

    public init(filePath path: String, directoryHint: DirectoryHint = .inferFromPath, relativeTo base: URL? = nil) {
        var text = path
        var directory: Bool
        if text.isEmpty {
            text = "./"
            directory = true
        } else {
            switch directoryHint {
            case .isDirectory:
                directory = true
            case .notDirectory:
                directory = false
            case .inferFromPath:
                directory = text.hasSuffix("/")
            case .checkFileSystem:
                var status = stat()
                if lstat(text, &status) == 0 {
                    directory = status.st_mode & S_IFMT == S_IFDIR
                } else {
                    directory = text.hasSuffix("/")
                }
            }
        }
        while text.count > 1 && text.hasSuffix("/") {
            text.removeLast()
        }
        let anchor = base ?? (text.hasPrefix("/") ? nil : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        let location = NSURL(fileURLWithPath: text, isDirectory: directory, relativeTo: anchor)
        self = location as URL
    }
}
