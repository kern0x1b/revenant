import SwiftCompilerPluginMessageHandling
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct CharonSchemaMacro {
    let conformances: [String]
    let memberName: String

    func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax) throws
        -> [ExtensionDeclSyntax] {
        let name = declaration.asProtocol((NamedDeclSyntax.self))?.name.trimmed.text
        guard let name else {
            throw MacroExpansionErrorMessage("a schema macro is only on a type with a name")
        }
        let schema = schemaArgument(of: node)
        let conformances = self.conformances.joined(separator: ", ")
        let expansion: ExtensionDeclSyntax = """
            extension \(raw: name): \(raw: conformances) {
                static var \(raw: memberName): Self { return \(raw: schema) }
            }
            """
        return [expansion]
    }

    private func schemaArgument(of node: AttributeSyntax) -> String {
        guard let argumentList = node.arguments,
              let argument = argumentList.arguments.first(where: { $0.label?.text == "schema" }) else {
            return "Self.Self"
        }
        return argument.expression.trimmedDescription
    }
}

public struct AppEnumMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        return CharonSchemaMacro(conformances: ["AppEnum", "AssistantSchemaEnum"],
                                 memberName: "__appSchemaEnum").expansion(of: node, attachedTo: declaration)
    }
}

public struct AppEntityMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        return CharonSchemaMacro(conformances: ["AppEntity", "AssistantSchemaEntity", "FileEntity",
                                                 "UniqueAppEntity", "URLRepresentableEntity"],
                                 memberName: "__appSchemaEntity").expansion(of: node, attachedTo: declaration)
    }
}

public struct AppIntentMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        return CharonSchemaMacro(
            conformances: ["AppIntent", "AssistantSchemaIntent", "ShowInAppSearchResultsIntent",
                           "OpenIntent", "DeleteIntent", "AudioPlaybackIntent",
                           "AudioRecordingIntent", "LiveActivityIntent", "URLRepresentableIntent"],
            memberName: "__appSchemaIntent").expansion(of: node, attachedTo: declaration)
    }
}
