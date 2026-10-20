import Foundation
import AppIntents

let a = IntentItem<String>("a")
let b = IntentItem<String>("b")
let c = IntentItem<String>("c")

let empty: [IntentItem<String>] = IntentItem<String>.Builder.buildBlock()
let three: [IntentItem<String>] = IntentItem<String>.Builder.buildBlock(a, b, c)
let one: [IntentItem<String>] = IntentItem<String>.Builder.buildExpression(a)
let array: [IntentItem<String>] = IntentItem<String>.Builder.buildArray([a, b, c])
print(empty.count, three.count, one.count, array.count)
