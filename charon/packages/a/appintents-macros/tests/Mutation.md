# The mutant, and what the "test" actually checks today

**The review is right and the answer is the second option: the test cannot go red on any mutation,
because it is not a test.** `tests/Expansions.swift` contains **no assertion** — it is a hand-written
reference expansion plus a user type that does not compile (its own header says so), because the
plugin's entry point does not exist yet. So the series' only test checks **nothing executable**; its
value is documentary, and a mutation to a macro would be caught by *nothing* today.

**The mutant, written and committed so the first build can go red on it.** The change is to
`ComputedPropertyMacro`'s accessor role in `Sources/AppIntentsMacros/main.swift`:

```diff
     static func expansion(
         of node: AttributeSyntax,
         providingAccessorsOf declaration: some DeclSyntaxProtocol,
         in context: some MacroExpansionContext
     ) throws -> [AccessorDeclSyntax] {
         let property = try namedProperty(declaration, "accessor")
         let storage = "_" + property.name
         return [
             "get { return \(raw: storage) }",
-            "set { \(raw: storage) = newValue }",
+            "set { \(raw: storage) = self.init() }",
         ]
     }
```

`EntityPropertyMacro` and `DeferredPropertyMacro` both delegate to that one function, so a single
mutation is a mutation of **all three** macros' accessor roles — which is the point: the reference in
`Expansions.swift` names `get`/`set` and nothing else, from
`arm64e-apple-macos.swiftinterface:3954` (`@attached(accessor, names: named(get), named(set))`).

**The assertion that must go red, in the harness that does not exist yet.** The shape is
`SwiftSyntaxMacrosTestSupport`'s `assertMacroExpansion`, which the toolchain does not ship here (see
`facts/AppIntents/Macros.md`: it pulls `_SwiftSyntaxTestSupport`, which imports XCTest, and this
machine's Command Line Tools have none). The check the harness has to make, written out so it is not
a matter of taste:

| expansion | expected | the mutation's answer |
| --- | --- | --- |
| `@ComputedProperty() var rating: String = "unset"` | `private var _rating: String = "unset"`, `var $rating: String { get set }`, and accessors `get { return _rating }` / `set { _rating = newValue }` | `set { _rating = self.init() }` — **diff, and the harness is red** |
| `@DeferredProperty() var comment: String?` | the same two peers and the same two accessors | the same red |
| a title or key-path spelling | the same peers, the title in the storage's initialiser | unchanged, and must be |

**Why no red line is quoted here.** The plugin cannot be built on this machine yet: the addon's
`rules/swift` claims `.swift` files by extension, so a host plugin target is a Swift target to it
whatever rules the target sets, and its `on_load` refuses a project with no runtime — measured, with
`set_rules("macro")` and `{defaults = false}` both tried. The rule ships in the next addon release cut
from main, and this harness runs in that release. **The mutant is here so that the first build in that
release is the one that goes red, not the one that discovers the gap.**
