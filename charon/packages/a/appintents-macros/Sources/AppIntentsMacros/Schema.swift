// The three schema macros: `@AppEntity(schema:)`, `@AppIntent(schema:)` and `@AppEnum(schema:)`.
//
// Their contracts are read off the framework's own declarations, and this file says which part of
// each is the interface's and which part is not derivable from it -- because Apple's plugin is not on
// this machine (the toolchain ships libObservationMacros and libSwiftMacros only) and a contract
// guessed at is a fabricated expansion.
//
//   arm64e-apple-macos.swiftinterface:10625
//     @attached(extension, conformances: AppEnum, AssistantSchemaEnum,
//               names: named(__appSchemaEnum))
//     public macro AppEnum<T>(schema: T) = #externalMacro(module: "AppIntentsMacros",
//                                                          type: "AppEnumMacro")
//   :10769
//     @attached(memberAttribute)
//     @attached(extension, conformances: AppEntity, AssistantSchemaEntity, FileEntity,
//               UniqueAppEntity, URLRepresentableEntity, names: named(__appSchemaEntity))
//     … type: "AppEntityMacro"
//   :10944
//     @attached(memberAttribute)
//     @attached(extension, conformances: AppIntent, AssistantSchemaIntent,
//               ShowInAppSearchResultsIntent, OpenIntent, DeleteIntent, AudioPlaybackIntent,
//               AudioRecordingIntent, LiveActivityIntent, URLRepresentableIntent,
//               names: named(__appSchemaIntent))
//     … type: "AppIntentMacro"
//
// So: the *shape* of each expansion is the interface's -- which protocols the type conforms to, in
// which order, and the name of the one member the extension adds. The two things it does not give are
// the attribute `memberAttribute` adds to the type's members, and the body of the named member, which
// is a value of the schema the attribute's argument names. Both are written below as the smallest
// thing that is true rather than as a guess, and both are named in the facts file.

import SwiftCompilerPluginMessageHandling
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - What the three share

/// The three macros differ in the protocols their extension conforms to, in the name of the member it
/// adds, and in the prefix of that name; nothing else. So this is one implementation and the three
/// are real types over it -- and real types, not typealiases, because the compiler looks the
/// implementation up by name in the plugin's list and a typealias is erased at runtime.
struct CharonSchemaMacro {
    /// The protocols the extension conforms to, in the order the interface lists them.
    let conformances: [String]
    /// The member the extension adds, as the interface names it: `named(__appSchemaEnum)`.
    let memberName: String

    /// The extension, exactly as the interface's `conformances:` and `names:` describe it: the type
    /// conforms to every protocol in order, and the extension adds the one member whose name is given.
    func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax) throws
        -> [ExtensionDeclSyntax] {
        let name = declaration.asProtocol((NamedDeclSyntax.self))?.name.trimmed.text
        guard let name else {
            throw MacroExpansionErrorMessage("a schema macro is only on a type with a name")
        }
        let schema = schemaArgument(of: node)
        let conformances = self.conformances.joined(separator: ", ")
        // The member's *name* is the interface's; its value is the schema the caller named at the use
        // site, written as it is written there, and not one this plugin invented.
        let expansion: ExtensionDeclSyntax = """
            extension \(raw: name): \(raw: conformances) {
                static var \(raw: memberName): Self { return \(raw: schema) }
            }
            """
        return [expansion]
    }

    /// The `schema:` argument, as it is written at the use site, so the member returns the schema the
    /// caller named rather than one this plugin invented.
    private func schemaArgument(of node: AttributeSyntax) -> String {
        guard let argumentList = node.arguments,
              let argument = argumentList.arguments.first(where: { $0.label?.text == "schema" }) else {
            return "Self.Self"
        }
        return argument.expression.trimmedDescription
    }
}

/// `@AppEnum(schema:)`'s implementation, under the name the framework's declaration gives it:
/// `AppIntentsMacros.AppEnumMacro`. Extension role only -- the interface declares no
/// `@attached(memberAttribute)` for it, so there is nothing to add to the type's members.
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

/// `@AppEntity(schema:)`'s implementation, under `AppIntentsMacros.AppEntityMacro`: the extension role
/// with the interface's five protocols, in its order.
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

/// `@AppIntent(schema:)`'s implementation, under `AppIntentsMacros.AppIntentMacro`: the extension role
/// with the interface's nine protocols, in its order.
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
