// `IntentItem.Builder`'s four rows, in the callers' shapes: a list is written as several items,
// because the framework's overload is variadic
// (`arm64e-apple-ios.swiftinterface:4954` -- `buildBlock(_ items: AppIntents::IntentItem<Value>...)`),
// and an empty list is the no-argument overload. The port's took a single item; the two-sided check
// in the two-sided builder check (since removed) found that, and this is the call site that pins it.
import Foundation
import AppIntents

let a = IntentItem<String>("a")
let b = IntentItem<String>("b")
let c = IntentItem<String>("c")

// the empty call
let empty: [IntentItem<String>] = IntentItem<String>.Builder.buildBlock()
// the variadic call: three items, which is how a list is written
let three: [IntentItem<String>] = IntentItem<String>.Builder.buildBlock(a, b, c)
// the other two rows, still bound to their signatures
let one: [IntentItem<String>] = IntentItem<String>.Builder.buildExpression(a)
let array: [IntentItem<String>] = IntentItem<String>.Builder.buildArray([a, b, c])
print(empty.count, three.count, one.count, array.count)
