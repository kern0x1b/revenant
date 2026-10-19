// The hand-checked expansion of every macro in this plugin, against the framework's own contract
// printed in `arm64e-apple-macos.swiftinterface`:
//
//   @attached(peer, names: prefixed(`$`), prefixed(`_`))
//   @attached(accessor, names: named(get), named(set))
//   public macro ComputedProperty() = #externalMacro(module: "AppIntentsMacros",
//                                                    type: "EntityPropertyMacro")
//
// so `@ComputedProperty()` on `var rating: String = "x"` must produce exactly the two peers and the
// two accessors below, and nothing else -- no other name, no other member. Apple's own plugin is not
// on this machine to diff against, so this file *is* the reference.
//
// IT DOES NOT COMPILE YET, and the two errors are its own, not findings:
//   * the user type's `displayRepresentation` wants the module's `LocalizedStringResource`, whose
//     `CharonLocalized` helper is internal to `charon@appintents` -- a port names the type, and the
//     test has to as well, so it needs the same probe the recipe runs;
//   * `@ComputedProperty()` cannot expand, because the plugin's entry point does not exist yet (see
//     Sources/AppIntentsMacros/main.swift) -- the compiler says exactly that: "external macro
//     implementation type 'AppIntentsMacros.ComputedPropertyMacro' could not be found for macro
//     'ComputedProperty()'; plugin for module 'AppIntentsMacros' not found", which also confirms the
//     wiring: the port's declaration names that type, and the compiler looks for that name.
// The expansion's writable half below is hand-writable and is the part a test can check today.
import AppIntents

/// The user type a port writes, with the macro on one property and without it on another.
public struct Thing: AppEntity {
    public static var displayRepresentation: DisplayRepresentation = DisplayRepresentation(title: "Thing")
    public var id: String

    @ComputedProperty()
    public var rating: String = "unset"

    // what the two roles above expand to, written out:
    //
    //     private var _rating: String = "unset"
    //     var $rating: String { get { return _rating } set { _rating = newValue } }
    //     // and the accessors the property gets, in place of its own:
    //     //     get { return _rating }
    //     //     set { _rating = newValue }
    //
    //     private var _comment: String? = nil
    //     var $comment: String? { get { return _comment } set { _comment = newValue } }

    public init(id: String) { self.id = id }
}

/// The expansion's *writable* half, spelled out as a type, so the reference is compiled and not only
/// described. The `$` projection is not here and cannot be: Swift reserves that prefix for the
/// compiler's own synthesised projections and refuses a hand-written one ("cannot declare entity
/// named '$rating'; the '$' prefix is reserved for implicitly-synthesized declarations", measured
/// while writing this file), which is also why the expansion has to come *out of the plugin* rather
/// than be written by hand as a second type.
public struct ThingExpanded {
    public var rating: String = "unset"
    private var _rating: String = "unset"
    public var comment: String?
    private var _comment: String?
}
