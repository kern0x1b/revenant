import Foundation
import backport

func covered(_ kind: backport.PresentationIntent.Kind) -> Int {
    switch kind {
    case .paragraph, .header, .orderedList, .unorderedList, .listItem: return 0
    case .codeBlock, .blockQuote, .thematicBreak: return 1
    case .table, .tableHeaderRow, .tableRow, .tableCell: return 2
    }
}

print(covered(.tableCell(columnIndex: 0)))
