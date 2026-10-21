import Foundation
import AppIntents

let x = IntentItem<String>("x")
let y = IntentItem<String>("y")

let empty: [IntentItemSection<String>] = IntentItemSection<String>.Builder.buildBlock()
let items: [IntentItemSection<String>] = IntentItemSection<String>.Builder.buildBlock(x, y)
let section = IntentItemSection<String>(items: [x, y])
let sections: [IntentItemSection<String>] = IntentItemSection<String>.Builder.buildBlock(section)
print(empty.count, items.count, sections.count)
