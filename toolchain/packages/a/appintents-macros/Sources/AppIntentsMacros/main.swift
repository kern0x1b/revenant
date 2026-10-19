import SwiftCompilerPluginMessageHandling
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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

private func bindingAccessor(_ declaration: some DeclSyntaxProtocol) -> String {
    guard let binding = declaration.as(VariableDeclSyntax.self)?.bindings.first,
          let value = binding.initializer?.value else { return "?" }
    return " = \(value.trimmedDescription)"
}

struct RevenantEntityProperty: PeerMacro, AccessorMacro {
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

public struct EntityPropertyMacro: PeerMacro, AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return RevenantEntityProperty.expansion(of: node, providingPeersOf: declaration, in: context)
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        return RevenantEntityProperty.expansion(of: node, providingAccessorsOf: declaration, in: context)
    }
}

public struct DeferredPropertyMacro: PeerMacro, AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return RevenantEntityProperty.expansion(of: node, providingPeersOf: declaration, in: context)
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        return RevenantEntityProperty.expansion(of: node, providingAccessorsOf: declaration, in: context)
    }
}

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
