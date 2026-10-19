// AppIntentsMacros: the plugin that expands the macros Apple's own AppIntentsMacros expands, built
// for the host against `charon@swift-syntax` -- the Apache-2.0 upstream at the tag that matches the
// fleet's 6.4 toolchain. Not the toolchain's own copy: that one exports every macro role and *no*
// `CompilerPlugin`, which sits behind `@_spi(PluginMessage)` in `SwiftCompilerPluginMessageHandling`
// (kits r3), so a `-load-plugin-executable` has nothing to conform to.
//
// Every role here is written against the framework's own @attached declaration, printed in
// `arm64e-apple-macos.swiftinterface`:
//
//   @attached(peer, names: prefixed(`$`), prefixed(`_`))
//   @attached(accessor, names: named(get), named(set))
//   public macro ComputedProperty() = #externalMacro(module: "AppIntentsMacros",
//                                                    type: "EntityPropertyMacro")
//
// Apple's plugin is not on this machine to diff against -- the toolchain ships libObservationMacros
// and libSwiftMacros and nothing else -- so the reference is the interface, and
// packages/a/appintents/facts/AppIntents/Macros.md says so rather than implying a diff happened.

import SwiftCompilerPluginMessageHandling
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - What the roles are given

/// The property's name and type, read from the declaration the attribute is on. Anything but a
/// named property is refused rather than guessed at, so a misuse is an error at the use and not a
/// wrong expansion.
private func namedProperty(_ declaration: some DeclSyntaxProtocol,
                           _ role: String) throws -> (name: String, type: String) {
    guard let property = declaration.as(VariableDeclSyntax.self),
          let binding = property.bindings.first,
          let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed else {
        throw MacroExpansionErrorMessage("#ComputedProperty's \(role) is only on a property with a name")
    }
    let type = binding.typeAnnotation?.type.trimmedDescription ?? "Any"
    return (name.text, type)
}

/// The initialiser a property wrote, as it is written, so the storage it is copied to starts where
/// the property does. Nothing is invented when the property had none: the storage is then an
/// implicitly-unwrapped optional, so a property the framework has not been given a value for reads as
/// none instead of trapping.
private func bindingAccessor(_ declaration: some DeclSyntaxProtocol) -> String {
    guard let binding = declaration.as(VariableDeclSyntax.self)?.bindings.first,
          let value = binding.initializer?.value else { return "?" }
    return " = \(value.trimmedDescription)"
}

// MARK: - The entity property, in the two roles the declaration names

/// The peer and the accessor of an entity's property: the `_` storage and the `$` projection, and the
/// `get`/`set` pair that reads and writes that storage. One implementation for both `@ComputedProperty`
/// and `@DeferredProperty`, because the framework's declarations give them the same two roles.
struct CharonEntityProperty: PeerMacro, AccessorMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let property = try namedProperty(declaration, "peer")
        let storage = "_" + property.name
        let projection = "$" + property.name
        let initialValue = bindingAccessor(declaration)
        return [
            """
            private var \(raw: storage): \(raw: property.type)\(raw: initialValue)
            """,
            """
            var \(raw: projection): \(raw: property.type) {
                get { return \(raw: storage) }
                set { \(raw: storage) = newValue }
            }
            """,
        ]
    }

    static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let property = try namedProperty(declaration, "accessor")
        let storage = "_" + property.name
        return [
            "get { return \(raw: storage) }",
            "set { \(raw: storage) = newValue }",
        ]
    }
}

/// `#ComputedProperty()`'s implementation, under the name the framework's own declaration gives it:
/// `#externalMacro(module: "AppIntentsMacros", type: "EntityPropertyMacro")`. The same two roles
/// serve all six of its spellings -- with no argument or a title, with an indexing key path or a
/// custom key -- because what the attribute says is read from the attribute.
///
/// A *type* and not a typealias: the compiler looks the implementation up by name in the plugin's
/// list, and a typealias is erased at runtime, so an alias would answer for one name and not the
/// other.
public struct EntityPropertyMacro: PeerMacro, AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return CharonEntityProperty.expansion(of: node, providingPeersOf: declaration, in: context)
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        return CharonEntityProperty.expansion(of: node, providingAccessorsOf: declaration, in: context)
    }
}

/// `#DeferredProperty()`'s implementation, under its own name. It is the *same* two roles, and the
/// declaration says so: `@attached(peer, names: prefixed(`$`), prefixed(`_`))` and
/// `@attached(accessor, names: named(get), named(set))`, type `AppIntentsMacros.DeferredPropertyMacro`
/// (interface lines 3958-3964, against ComputedProperty's 3954-3972). A deferred property is read
/// from the app only when it is asked for -- a reason to fetch it, not a different shape of
/// declaration -- so it delegates rather than the body being written twice, which is how the two
/// would drift.
public struct DeferredPropertyMacro: PeerMacro, AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return CharonEntityProperty.expansion(of: node, providingPeersOf: declaration, in: context)
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        return CharonEntityProperty.expansion(of: node, providingAccessorsOf: declaration, in: context)
    }
}

// MARK: - The entry point

/// The two macro types the compiler asks this plugin for, under the names the framework's own
/// declarations name, so `Remaining.swift`'s `#externalMacro(module: "AppIntentsMacros", type: …)`
/// finds them and a port that writes `@ComputedProperty()` or `@DeferredProperty()` expands.
@main
struct AppIntentsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EntityPropertyMacro.self,
        DeferredPropertyMacro.self,
        AppEntityMacro.self,
        AppIntentMacro.self,
        AppEnumMacro.self,
    ]
}
