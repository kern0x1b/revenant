import Foundation

public struct AttributedString: Hashable {
    fileprivate let storage: NSAttributedString

    public init() {
        self.storage = NSAttributedString()
    }

    public init(_ string: String) {
        self.storage = NSAttributedString(string: string)
    }

    public init(_ nsStr: NSAttributedString) {
        self.storage = NSAttributedString(attributedString: nsStr)
    }

    public static func == (lhs: AttributedString, rhs: AttributedString) -> Bool {
        return lhs.storage.isEqual(to: rhs.storage)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage.string)
    }
}

extension AttributedString: @unchecked Sendable {
}

extension NSAttributedString {
    public convenience init(_ attrStr: AttributedString) {
        self.init(attributedString: attrStr.storage)
    }
}

extension AttributedString {
    public struct MarkdownParsingOptions: Sendable {
        public enum FailurePolicy: Int, Sendable {
            case throwError
            case returnPartiallyParsedIfPossible
        }

        public enum InterpretedSyntax: Int, Sendable {
            case full
            case inlineOnly
            case inlineOnlyPreservingWhitespace
        }

        public var allowsExtendedAttributes: Bool
        public var interpretedSyntax: InterpretedSyntax
        public var failurePolicy: FailurePolicy
        public var languageCode: String?
        public var appliesSourcePositionAttributes: Bool

        public init(allowsExtendedAttributes: Bool = false, interpretedSyntax: InterpretedSyntax = .full, failurePolicy: FailurePolicy = .throwError, languageCode: String? = nil, appliesSourcePositionAttributes: Bool = false) {
            self.allowsExtendedAttributes = allowsExtendedAttributes
            self.interpretedSyntax = interpretedSyntax
            self.failurePolicy = failurePolicy
            self.languageCode = languageCode
            self.appliesSourcePositionAttributes = appliesSourcePositionAttributes
        }
    }

    public struct MarkdownSourcePosition: Hashable, Codable, Sendable {
        public let startLine: Int
        public let startColumn: Int
        public let endLine: Int
        public let endColumn: Int

        public init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
            self.startLine = startLine
            self.startColumn = startColumn
            self.endLine = endLine
            self.endColumn = endColumn
        }
    }

    public init(markdown: String, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
        self.storage = try NSAttributedString(markdown: Data(markdown.utf8), options: options, baseURL: baseURL)
    }

    public init(markdown: Data, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
        self.storage = try NSAttributedString(markdown: markdown, options: options, baseURL: baseURL)
    }

    public init(contentsOf url: URL, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
        self.storage = try NSAttributedString(contentsOf: url, options: options, baseURL: baseURL)
    }
}

extension NSAttributedString {
    public convenience init(markdown: Data, options: AttributedString.MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
        try self.init(__markdown: markdown, options: options._bridgeToObjectiveC(), baseURL: baseURL)
    }

    public convenience init(markdown: String, options: AttributedString.MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
        try self.init(__markdownString: markdown, options: options._bridgeToObjectiveC(), baseURL: baseURL)
    }

    public convenience init(contentsOf url: URL, options: AttributedString.MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
        try self.init(__contentsOfMarkdownFileAt: url, options: options._bridgeToObjectiveC(), baseURL: baseURL)
    }
}

extension AttributedString.MarkdownParsingOptions: _ObjectiveCBridgeable {
    public typealias _ObjectiveCType = __NSAttributedStringMarkdownParsingOptions

    public func _bridgeToObjectiveC() -> __NSAttributedStringMarkdownParsingOptions {
        let result = __NSAttributedStringMarkdownParsingOptions()
        result.allowsExtendedAttributes = allowsExtendedAttributes
        switch interpretedSyntax {
        case .full: result.interpretedSyntax = .full
        case .inlineOnly: result.interpretedSyntax = .inlineOnly
        case .inlineOnlyPreservingWhitespace: result.interpretedSyntax = .inlineOnlyPreservingWhitespace
        }
        switch failurePolicy {
        case .throwError: result.failurePolicy = .returnError
        case .returnPartiallyParsedIfPossible: result.failurePolicy = .returnPartiallyParsedIfPossible
        }
        result.languageCode = languageCode
        result.appliesSourcePositionAttributes = appliesSourcePositionAttributes
        return result
    }

    public static func _forceBridgeFromObjectiveC(_ x: __NSAttributedStringMarkdownParsingOptions, result: inout AttributedString.MarkdownParsingOptions?) {
        result = AttributedString.MarkdownParsingOptions(x)
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: __NSAttributedStringMarkdownParsingOptions, result: inout AttributedString.MarkdownParsingOptions?) -> Bool {
        result = AttributedString.MarkdownParsingOptions(x)
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ source: __NSAttributedStringMarkdownParsingOptions?) -> AttributedString.MarkdownParsingOptions {
        return source.map({ AttributedString.MarkdownParsingOptions($0) }) ?? AttributedString.MarkdownParsingOptions()
    }

    private init(_ source: __NSAttributedStringMarkdownParsingOptions) {
        self.init()
        allowsExtendedAttributes = source.allowsExtendedAttributes
        switch source.interpretedSyntax {
        case .inlineOnly: interpretedSyntax = .inlineOnly
        case .inlineOnlyPreservingWhitespace: interpretedSyntax = .inlineOnlyPreservingWhitespace
        default: interpretedSyntax = .full
        }
        switch source.failurePolicy {
        case .returnPartiallyParsedIfPossible: failurePolicy = .returnPartiallyParsedIfPossible
        default: failurePolicy = .throwError
        }
        languageCode = source.languageCode
        appliesSourcePositionAttributes = source.appliesSourcePositionAttributes
    }
}

extension AttributedString.MarkdownSourcePosition: _ObjectiveCBridgeable {
    public typealias _ObjectiveCType = __NSAttributedStringMarkdownSourcePosition

    public func _bridgeToObjectiveC() -> __NSAttributedStringMarkdownSourcePosition {
        return __NSAttributedStringMarkdownSourcePosition(startLine: startLine, startColumn: startColumn, endLine: endLine, endColumn: endColumn)
    }

    public static func _forceBridgeFromObjectiveC(_ x: __NSAttributedStringMarkdownSourcePosition, result: inout AttributedString.MarkdownSourcePosition?) {
        result = AttributedString.MarkdownSourcePosition(startLine: x.startLine, startColumn: x.startColumn, endLine: x.endLine, endColumn: x.endColumn)
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: __NSAttributedStringMarkdownSourcePosition, result: inout AttributedString.MarkdownSourcePosition?) -> Bool {
        _forceBridgeFromObjectiveC(x, result: &result)
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ source: __NSAttributedStringMarkdownSourcePosition?) -> AttributedString.MarkdownSourcePosition {
        guard let source = source else {
            return AttributedString.MarkdownSourcePosition(startLine: 0, startColumn: 0, endLine: 0, endColumn: 0)
        }
        return AttributedString.MarkdownSourcePosition(startLine: source.startLine, startColumn: source.startColumn, endLine: source.endLine, endColumn: source.endColumn)
    }
}

extension Range where Bound == String.Index {
    public init?<S>(_ markdownSourcePosition: AttributedString.MarkdownSourcePosition, in target: S) where S: StringProtocol {
        let nsRange = markdownSourcePosition._bridgeToObjectiveC().range(in: String(target))
        guard nsRange.location != NSNotFound else {
            return nil
        }
        let units = target.utf16
        let lower = units.index(units.startIndex, offsetBy: nsRange.location)
        let upper = units.index(lower, offsetBy: nsRange.length)
        self = lower..<upper
    }
}
