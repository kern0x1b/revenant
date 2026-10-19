# The two result-builder families, and the shape check that reads all seven rows

**The declarations were already in the tree** — `IntentItemSectionBuilder` with its two
`buildBlock` overloads, `IntentItemBuilder` with its four, and the `Builder` typealiases the earlier
`Items.swift` commit added. What was missing was a **check**, so the pieces here are the check and
its result, not new declarations: six of the seven rows had nothing to commit, and saying otherwise
would be a commit whose subject claims work it does not contain.

**The check**, the builder shape check (removed with the appintents Python tests), reads the framework's own interface
from the machine's `charon@iphoneos-sdk` 26.2 install and, for each row, asserts that the declaration
exists here as a `static func` on the right type, inside a `@resultBuilder` type, **with the row's own
label**. The label is the part that matters and the part a name-only search gets wrong:
`buildBlock()` and `buildBlock(_:)` are one name with two spellings, and a search on the name alone
finds the first for both -- which is what the first version of the checker did, and it reported the
one-argument row as having no labels.

**The result**, from a run on 2026-09-28 (`exit 0`, 7 rows, 0 failures):

ok  IntentItemSection.Builder                    the type: a typealias to IntentItemBuilder, and the interface nests an enum named Builder
ok  IntentItemSection.Builder.buildBlock()       public static func buildBlock() -> [IntentItem<Value>] { return [] }
ok  IntentItemSection.Builder.buildBlock(_:)     public static func buildBlock(_ item: IntentItem<Value>) -> [IntentItem<Value>] { return [item] }
ok  IntentItem.Builder.buildExpression(_:)       public static func buildExpression(_ expression: IntentItem<Value>) -> IntentItem<Value> { return expression }
ok  IntentItem.Builder.buildArray(_:)            public static func buildArray(_ items: [IntentItem<Value>]) -> [IntentItem<Value>] { return items }
ok  IntentItem.Builder.buildBlock()              public static func buildBlock() -> [IntentItem<Value>] { return [] }
ok  IntentItem.Builder.buildBlock(_:)            public static func buildBlock(_ item: IntentItem<Value>) -> [IntentItem<Value>] { return [item] }
checked 7 row(s), 0 failure(s)

**What this check is and is not.** It is the *shape*: that each row is declared, statically, on a
result-builder type, with the framework's labels, against the interface of the release the rows are
written against. It is not the *behaviour*: the digester prints a `@resultBuilder` type's members not
at all, and the call-site typecheck that would place the rows needs a module built from this tree —
the one in the store predates the `IntentItemSection.Builder` typealias, so it answers
`type 'IntentItemSection<String>' has no member 'Builder'`. That is the next thing when a slow slot is
free, and it is a device compile, not a macro build.
