import SwiftUI

struct Row: Identifiable { let id: Int }

// A Text is not table content, so this must not compile.
func aTextCannotBeARow() {
    let bad = Table(of: Row.self) {
        TableColumn("id") { (row: Row) in Text("\(row.id)") }
    } rows: {
        Text("not a row")
    }
    _ = bad
}
