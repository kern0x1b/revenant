import Foundation

let sources: [(String, String)] = [
    ("plain", "plain text"),
    ("heading", "# Title\n\nParagraph with *emphasis*, **strong**, `code`, ~~gone~~ and a [link](https://example.com/a?b=1).\n"),
    ("lists", "- one\n- two\n  - nested\n\n1. first\n2. second\n"),
    ("blocks", "> quote\n\n```swift\nlet x = 1\n```\n\n---\n"),
    ("table", "| a | b |\n|---|:-:|\n| 1 | 2 |\n"),
    ("image", "![alt text](pic.png \"title\") and [relative](docs/a.md)"),
    ("breaks", "line one\nline two  \nhard\\\nbreak"),
    ("html", "<b>html</b> and <span>inline</span>"),
    ("empty", ""),
    ("spaces", "multi   space  \n\n\n  indented"),
    ("unicode", "caf\u{e9} \u{1F600} **\u{4E2D}\u{6587}** \u{05E9}\u{05DC}\u{05D5}\u{05DD}"),
    ("extended", "^[extended](key: value)"),
]

func optionSets() -> [(String, AttributedString.MarkdownParsingOptions)] {
    var sets: [(String, AttributedString.MarkdownParsingOptions)] = []
    sets.append(("default", .init()))
    sets.append(("inline", .init(interpretedSyntax: .inlineOnly)))
    sets.append(("inlinePreserving", .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
    sets.append(("extended", .init(allowsExtendedAttributes: true)))
    sets.append(("partial", .init(failurePolicy: .returnPartiallyParsedIfPossible)))
    sets.append(("language", .init(languageCode: "fr")))
    sets.append(("positions", .init(appliesSourcePositionAttributes: true)))
    sets.append(("all", .init(allowsExtendedAttributes: true, interpretedSyntax: .inlineOnly, failurePolicy: .returnPartiallyParsedIfPossible, languageCode: "de", appliesSourcePositionAttributes: true)))
    return sets
}

func describe(_ value: Any) -> String {
    if let intent = value as? PresentationIntent {
        return "intent(" + intent.components.map { $0.debugDescription }.joined(separator: " <- ") + ")"
    }
    if let inline = value as? InlinePresentationIntent {
        return "inline(\(inline.rawValue))"
    }
    if let url = value as? URL {
        return "url(\(url.absoluteString))"
    }
    if let position = value as? AttributedString.MarkdownSourcePosition {
        return "position(\(position.startLine):\(position.startColumn)-\(position.endLine):\(position.endColumn))"
    }
    return String(describing: value)
}

func dump(_ text: NSAttributedString) -> String {
    var lines: [String] = []
    text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, range, _ in
        let piece = (text.string as NSString).substring(with: range)
        let items = attributes.keys.map { $0.rawValue }.sorted().map { key in
            "\(key)=\(describe(attributes[NSAttributedString.Key(key)]!))"
        }
        lines.append("  \(range.location),\(range.length) \(piece.debugDescription) {\(items.joined(separator: "; "))}")
    }
    return "length=\(text.length)\n" + lines.joined(separator: "\n")
}

func outcome(_ make: () throws -> NSAttributedString) -> String {
    do {
        return dump(try make())
    } catch {
        let nsError = error as NSError
        return "error \(nsError.domain) \(nsError.code)"
    }
}

func plain(_ make: () throws -> AttributedString) -> String {
    do {
        return NSAttributedString(try make()).string.debugDescription
    } catch {
        let nsError = error as NSError
        return "error \(nsError.domain) \(nsError.code)"
    }
}

let base = URL(string: "https://base.example/docs/")

for (setName, options) in optionSets() {
    for (name, source) in sources {
        print("== \(setName) \(name)")
        print("data", outcome { try NSAttributedString(markdown: Data(source.utf8), options: options, baseURL: base) })
        print("string", outcome { try NSAttributedString(markdown: source, options: options, baseURL: nil) })
        if setName == "extended" && name == "extended" {
            continue
        }
        print("value", plain { try AttributedString(markdown: source, options: options, baseURL: base) })
        print("valueData", plain { try AttributedString(markdown: Data(source.utf8), options: options, baseURL: nil) })
    }
}

let folder = NSTemporaryDirectory() + "attributed-string-markdown"
try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
let file = URL(fileURLWithPath: folder + "/page.md")
try? "# From a file\n\n[link](other.md)\n".write(to: file, atomically: true, encoding: .utf8)
let missing = URL(fileURLWithPath: folder + "/missing.md")
print("file", outcome { try NSAttributedString(contentsOf: file, options: .init(), baseURL: file.deletingLastPathComponent()) })
print("fileValue", plain { try AttributedString(contentsOf: file) })
print("missing", outcome { try NSAttributedString(contentsOf: missing, options: .init(), baseURL: nil) })
print("missingValue", plain { try AttributedString(contentsOf: missing) })
try? FileManager.default.removeItem(atPath: folder)

let invalid = Data([0xFF, 0xFE, 0x41, 0x80, 0x0A])
for (setName, options) in optionSets() {
    print("invalid", setName, outcome { try NSAttributedString(markdown: invalid, options: options, baseURL: nil) })
    print("invalidValue", setName, plain { try AttributedString(markdown: invalid, options: options, baseURL: nil) })
}

for (setName, options) in optionSets() {
    let bridged = options._bridgeToObjectiveC()
    var back: AttributedString.MarkdownParsingOptions?
    AttributedString.MarkdownParsingOptions._forceBridgeFromObjectiveC(bridged, result: &back)
    let restored = back!
    print("bridge", setName, bridged.allowsExtendedAttributes, bridged.interpretedSyntax.rawValue, bridged.failurePolicy.rawValue, bridged.languageCode ?? "nil", bridged.appliesSourcePositionAttributes,
          restored.allowsExtendedAttributes, restored.interpretedSyntax.rawValue, restored.failurePolicy.rawValue, restored.languageCode ?? "nil", restored.appliesSourcePositionAttributes)
}

let positionSource = "caf\u{e9} **bold** \u{1F600} tail\nsecond line"
let positions: [AttributedString.MarkdownSourcePosition] = [
    .init(startLine: 1, startColumn: 1, endLine: 1, endColumn: 5),
    .init(startLine: 1, startColumn: 7, endLine: 1, endColumn: 15),
    .init(startLine: 2, startColumn: 1, endLine: 2, endColumn: 12),
    .init(startLine: 1, startColumn: 1, endLine: 2, endColumn: 12),
    .init(startLine: 9, startColumn: 1, endLine: 9, endColumn: 2),
    .init(startLine: 0, startColumn: 0, endLine: 0, endColumn: 0),
]
for position in positions {
    let swiftRange = Range(position, in: positionSource).map { positionSource.utf16.distance(from: positionSource.startIndex, to: $0.lowerBound) ..< positionSource.utf16.distance(from: positionSource.startIndex, to: $0.upperBound) }
    let bridged = position._bridgeToObjectiveC()
    print("position", position.startLine, position.startColumn, position.endLine, position.endColumn,
          swiftRange.map { "\($0.lowerBound)..<\($0.upperBound)" } ?? "nil",
          bridged.startLine, bridged.endColumn, position == positions[0], position.hashValue == AttributedString.MarkdownSourcePosition(startLine: position.startLine, startColumn: position.startColumn, endLine: position.endLine, endColumn: position.endColumn).hashValue)
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
print("codable", String(decoding: try encoder.encode(positions[1]), as: UTF8.self))
let decoded = try JSONDecoder().decode(AttributedString.MarkdownSourcePosition.self, from: Data(#"{"startLine":3,"startColumn":4,"endLine":5,"endColumn":6}"#.utf8))
print("decoded", decoded.startLine, decoded.startColumn, decoded.endLine, decoded.endColumn)

let first = try AttributedString(markdown: "same *text*")
let second = try AttributedString(markdown: "same *text*")
let third = try AttributedString(markdown: "same text")
print("equality", first == second, first == third, first.hashValue == second.hashValue, AttributedString("x") == AttributedString("x"), AttributedString("x") == AttributedString("y"), AttributedString() == AttributedString(""))
print("roundTrip", NSAttributedString(AttributedString(NSAttributedString(string: "round trip"))).string)
