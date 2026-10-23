import Foundation

let kinds: [String] = [
    #"["paragraph"]"#, #"["header",1]"#, #"["orderedList"]"#, #"["unorderedList"]"#, #"["listItem",1]"#,
    #"["codeBlock","swift"]"#, #"["codeBlock",null]"#, #"["blockQuote"]"#, #"["thematicBreak"]"#,
    #"["table",[{"alignment":0},{"alignment":2}]]"#, #"["tableHeaderRow"]"#, #"["tableRow",1]"#, #"["tableCell",0]"#,
]

func component(_ kind: String, _ identity: Int) -> String {
    return #"{"identity":\#(identity),"kind":\#(kind)}"#
}

func json(_ chain: [String]) -> String {
    return #"{"components":["# + chain.enumerated().map { component($0.element, $0.offset + 1) }.joined(separator: ",") + "]}"
}

func enumerated(depth: Int) -> [[String]] {
    var chains: [[String]] = [[]]
    for _ in 0..<depth {
        chains = chains.flatMap { chain in kinds.map { chain + [$0] } }
    }
    return chains
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

var failures = 0
for depth in 1...3 {
    for chain in enumerated(depth: depth) {
        let text = json(chain)
        guard let intent = try? JSONDecoder().decode(PresentationIntent.self, from: Data(text.utf8)) else {
            print("decode-failed", text)
            failures += 1
            continue
        }
        let described = intent.components.map { $0.debugDescription }.joined(separator: " <- ")
        let again = (try? encoder.encode(intent)).map { String(decoding: $0, as: UTF8.self) } ?? "encode-failed"
        print(depth, intent.count, intent.isValid, intent.indentationLevel, described, again)
    }
}
print("decode failures", failures)

let first = try! JSONDecoder().decode(PresentationIntent.self, from: Data(json([kinds[0], kinds[4]]).utf8))
let same = try! JSONDecoder().decode(PresentationIntent.self, from: Data(json([kinds[0], kinds[4]]).utf8))
let other = try! JSONDecoder().decode(PresentationIntent.self, from: Data(json([kinds[0], kinds[2]]).utf8))
print("equal", first == same, "unequal", first == other, "hash", first.hashValue == same.hashValue)
print("debug", first.debugDescription)

var bridgeFailures = 0
for depth in 1...3 {
    for chain in enumerated(depth: depth) {
        let text = json(chain)
        let value = try! JSONDecoder().decode(PresentationIntent.self, from: Data(text.utf8))
        guard let object = value as Any as? __NSPresentationIntent else {
            print("not-bridged", text)
            bridgeFailures += 1
            continue
        }
        if (object as Any as? PresentationIntent) != value {
            print("round-trip-differs", text)
            bridgeFailures += 1
        }
    }
}
print("bridge failures", bridgeFailures)

let list = __NSPresentationIntent.orderedListIntent(withIdentity: 1, nestedInside: nil)
let listItem = __NSPresentationIntent.listItemIntent(withIdentity: 2, ordinal: 3, nestedInside: list)
let paragraph = __NSPresentationIntent.paragraphIntent(withIdentity: 4, nestedInside: listItem)
let fromObject = paragraph as Any as? PresentationIntent
print("object", fromObject?.debugDescription ?? "nil", fromObject?.isValid ?? false, fromObject?.indentationLevel ?? -1)
let table = __NSPresentationIntent.tableIntent(withIdentity: 7, columnCount: 2, alignments: [NSNumber(value: 0), NSNumber(value: 2)], nestedInside: nil)
let cell = __NSPresentationIntent.tableCellIntent(withIdentity: 9, column: 1, nestedInside: __NSPresentationIntent.tableRowIntent(withIdentity: 8, row: 4, nestedInside: table))
let fromTable = cell as Any as? PresentationIntent
print("table object", fromTable?.debugDescription ?? "nil", fromTable?.isValid ?? false, fromTable?.count ?? -1)
print("object back", (fromTable as Any) as? __NSPresentationIntent != nil, (fromObject as Any) as? __NSPresentationIntent != nil)
