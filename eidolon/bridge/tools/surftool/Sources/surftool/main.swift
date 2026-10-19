// surftool: the public surface of a .swiftinterface, read with swift-syntax's SwiftParser.
//   surftool INTERFACE... > surface.tsv      lines: owner \t member \t labels \t kind
import SwiftParser
import SwiftSyntax
import Foundation

var out: [String] = []

final class Walker: SyntaxVisitor {
    let file: String
    var stack: [String] = []
    var protocolStack: [String] = []
    init(file: String) { self.file = file; super.init(viewMode: .sourceAccurate) }

    private var owner: String { stack.joined(separator: ".") }

    /// A type names itself too, by the path it is nested in: empty for a top-level one.
    private func record(type: String) {
        out.append([stack.dropLast().joined(separator: "."), type, "", "type"].joined(separator: "\t"))
    }
    private var enclosing: String? { stack.isEmpty ? nil : owner }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // `extension SwiftUI.Foo {` and `extension SwiftUI.Foo where Self == SwiftUI.Bar {`: the extended
        // type is the owner of the members, and a `where Self ==` names a type the graph omits entirely
        let base = node.extendedType.trimmedDescription
            .replacingOccurrences(of: "SwiftUI.", with: "")
            .replacingOccurrences(of: "SwiftUICore.", with: "")
        let simple = base.split(separator: ".").last.map(String.init) ?? base
        if let cut = simple.firstIndex(where: { $0.isLetter }) {
            stack = [String(simple[cut...]).trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "{ "))]
            let text = node.trimmedDescription
            for self_ in text.components(separatedBy: "where Self ==").dropFirst() {
                let name = self_.trimmingCharacters(in: CharacterSet(charactersIn: " {}\n\r"))
                    .replacingOccurrences(of: "SwiftUI.", with: "")
                    .replacingOccurrences(of: "SwiftUICore.", with: "")
                let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "{ "))
                if let cut = clean.firstIndex(where: { $0.isLetter }) {
                    out.append("\(clean[cut...].trimmingCharacters(in: CharacterSet(charactersIn: "{ ")))\t#type\t\tconstrained-extension")
                }
            }
        } else {
            stack = []
        }
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) { stack = [] }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        stack.append(node.name.text)
        record(type: node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) { _ = stack.popLast() }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        stack.append(node.name.text)
        record(type: node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) { _ = stack.popLast() }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        stack.append(node.name.text)
        record(type: node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) { _ = stack.popLast() }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        stack.append(node.name.text)
        record(type: node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) { _ = stack.popLast() }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        stack.append(node.name.text)
        record(type: node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: ProtocolDeclSyntax) { _ = stack.popLast() }
    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        // a typealias names a type too, and a top-level one has an empty owner: CGFloat, CGPoint and
        // CGRect are typealiases of the SDK, and the gate compares those names
        out.append([enclosing ?? "", node.name.text, "", "typealias"].joined(separator: "\t"))
        return .skipChildren
    }
    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        for element in node.elements {
            out.append("\(owner)\t\(element.name.text)\t\tenum.case")
        }
        return .skipChildren
    }

    private func labels(of node: ParameterClauseSyntax) -> String {
        node.parameters.map { $0.firstName.text }.joined(separator: ",")
    }


    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let labels = labels(of: node.signature.parameterClause)
        out.append("\(owner)\t\(node.name.text)\t\(labels)\tfunc")
        return .skipChildren
    }
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let labels = labels(of: node.signature.parameterClause)
        out.append("\(owner)\tinit\t\(labels)\tinit")
        return .skipChildren
    }
    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        let labels = labels(of: node.parameterClause)
        out.append("\(owner)\tsubscript\t\(labels)\tsubscript")
        return .skipChildren
    }
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let kind = node.bindingSpecifier.text
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                out.append("\(owner)\t\(pattern.identifier.text)\t\tvar.\(kind)")
            } else {
                out.append("\(owner)\t\(node.trimmedDescription.prefix(40))\t\tvar.\(kind)")
            }
        }
        return .skipChildren
    }
}

// The oracle is every module SwiftUI reaches, which is what its `@_exported import` lines say and not
// a list written here: reading them and following them is the difference between the gate knowing that
// `CGAffineTransform` is Apple's and guessing it.
func exportedModules(in text: String) -> [String] {
    var names: [String] = []
    for line in text.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("@_exported import ") else { continue }
        names.append(trimmed.dropFirst("@_exported import ".count)
            .split(separator: " ").first.map(String.init) ?? "")
    }
    return names.filter { !$0.isEmpty }
}

let arguments = Array(CommandLine.arguments.dropFirst())
let sdkRoot = arguments.first ?? ""
var queue = Array(arguments.dropFirst())
var seen = Set<String>()

while let path = queue.popLast() {
    // the module is the directory an interface sits in, not the interface's own name: two
    // interfaces of one module (two architectures) are the same module, and keying on the file
    // skipped the second of the two entry points
    let name = URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
    guard seen.insert(name).inserted else { continue }
    let url = URL(fileURLWithPath: path)
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
    Walker(file: path).walk(Parser.parse(source: text))
    if !sdkRoot.isEmpty {
        for module in exportedModules(in: text) {
            let found = FileManager.default
                .enumerator(atPath: sdkRoot) as? FileManager.DirectoryEnumerator
            var matches: [String] = []
            // the filter belongs in the body: putting it in the while condition stops the walk at
            // the first path that does not match
            while let relative = found?.nextObject() as? String {
                if relative.hasSuffix("/\(module).swiftmodule") { matches.append(relative) }
            }
            for match in matches {
                let full = sdkRoot + "/" + match
                for interface in (try? FileManager.default.contentsOfDirectory(atPath: full)) ?? [] where interface.hasSuffix(".swiftinterface") {
                    queue.append(full + "/" + interface)
                }
            }
        }
    }
}
print(out.joined(separator: "\n"))
