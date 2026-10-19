import SwiftUI

struct TabRow: Identifiable { let id: Int }

// A tab with its value written in it is tab content, and a TabView takes it, with and without a
// selection, and through a ForEach of them.
func tabsReachATabView() {
    let tab = Tab("Inbox", systemImage: "envelope", value: 1) { Color.gray }
    let bar = TabView {
        Tab("Inbox", systemImage: "envelope", value: 1) { Color.gray }
        Tab("Sent", systemImage: "paperplane", value: 2) { Color.white }
    }
    let chosen = TabView(selection: Binding<Int?>.constant(1)) {
        Tab("Inbox", systemImage: "envelope", value: 1) { Color.gray }
        Tab("Sent", systemImage: "paperplane", value: 2) { Color.white }
    }
    let nothing = TabView(selection: Binding<Int?>.constant(nil)) {
        Tab("Inbox", systemImage: "envelope", value: 1) { Color.gray }
    }
    let rows = [TabRow(id: 1), TabRow(id: 2)]
    let each = TabView(selection: Binding<Int>.constant(1)) {
        ForEach<[TabRow], Int, Tab<Int, Color, DefaultTabLabel>>(rows) { row in
            Tab("row", value: row.id) { Color.gray }
        }
    }
    _ = (tab, bar, chosen, nothing, each)
}

// A container's children are a collection an app can hand to Group(subviews:).
func groupTakesAContainersChildren() {
    let rows = Group { Color.red; Color.green }
    _ = Group(subviews: rows) { children in Text("\\(children.count)") }
}
