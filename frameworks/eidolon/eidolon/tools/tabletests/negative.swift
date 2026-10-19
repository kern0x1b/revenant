import SwiftUI

struct Row: Identifiable { let id: Int }

func aTextCannotBeARow() {
    let bad = Table(of: Row.self) {
        TableColumn("id") { (row: Row) in Text("\(row.id)") }
    } rows: {
        Text("not a row")
    }
    _ = bad
}
