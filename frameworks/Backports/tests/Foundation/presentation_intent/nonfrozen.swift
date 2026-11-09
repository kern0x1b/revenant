import Foundation
import backport

func sorted(_ kind: backport.PresentationIntent.Kind) -> Int {
    switch kind {
    case .paragraph: return 0
    case .header: return 1
    case .orderedList, .unorderedList, .listItem: return 2
    case .codeBlock, .blockQuote, .thematicBreak: return 3
    case .table, .tableHeaderRow, .tableRow, .tableCell: return 4
    default: return 5
    }
}

func sortedUnknown(_ kind: backport.PresentationIntent.Kind) -> Int {
    switch kind {
    case .paragraph, .header, .orderedList, .unorderedList, .listItem: return 0
    case .codeBlock, .blockQuote, .thematicBreak: return 1
    case .table, .tableHeaderRow, .tableRow, .tableCell: return 2
    @unknown default: return 3
    }
}

func covered(_ kind: backport.PresentationIntent.Kind) -> Int {
    switch kind {
    case .paragraph, .header, .orderedList, .unorderedList, .listItem: return 0
    case .codeBlock, .blockQuote, .thematicBreak: return 1
    case .table, .tableHeaderRow, .tableRow, .tableCell: return 2
    }
}

print(sorted(.paragraph), sortedUnknown(.thematicBreak), covered(.tableCell(columnIndex: 0)))
