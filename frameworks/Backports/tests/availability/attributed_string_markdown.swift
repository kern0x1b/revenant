import Foundation

enum AttributedStringMarkdownUse {
    @available(iOS 15.0, *)
    static func page(data: Data, base: URL?) throws -> NSAttributedString {
        return try NSAttributedString(
            markdown: Data(data),
            options: .init(),
            baseURL: base
        )
    }

    @available(iOS 15.0, *)
    static func inline(_ text: String) throws -> NSAttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        options.allowsExtendedAttributes = true
        options.languageCode = "en"
        return try NSAttributedString(markdown: text, options: options, baseURL: nil)
    }

    @available(iOS 15.0, *)
    static func file(_ url: URL) throws -> NSAttributedString {
        return try NSAttributedString(contentsOf: url, options: .init(), baseURL: url.deletingLastPathComponent())
    }

    @available(iOS 15.0, *)
    static func value(_ text: String) throws -> NSAttributedString {
        let parsed = try AttributedString(markdown: text)
        return NSAttributedString(parsed)
    }

    @available(iOS 16.0, *)
    static func range(_ position: AttributedString.MarkdownSourcePosition, in text: String) -> Range<String.Index>? {
        return Range(position, in: text)
    }
}
