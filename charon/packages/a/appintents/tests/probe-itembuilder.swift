// `IntentItemSection.Builder`'s three rows, in the callers' shapes: an empty list, a list of
// sections, and a list of the items inside one -- the three overloads the framework declares for a
// section builder (`arm64e-apple-ios.swiftinterface:5004-5006`), two of them variadic.
import Foundation
import AppIntents

let x = IntentItem<String>("x")
let y = IntentItem<String>("y")

let empty: [IntentItemSection<String>] = IntentItemSection<String>.Builder.buildBlock()
let items: [IntentItemSection<String>] = IntentItemSection<String>.Builder.buildBlock(x, y)
let section = IntentItemSection<String>(items: [x, y])
let sections: [IntentItemSection<String>] = IntentItemSection<String>.Builder.buildBlock(section)
print(empty.count, items.count, sections.count)
