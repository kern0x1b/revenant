import SwiftUI

struct Item: Identifiable {
    let id: Int
    let title: String
}

final class Store: ObservableObject {
    @Published var items: [Item] = [Item(id: 1, title: "one"), Item(id: 2, title: "two")]
    @Published var on = false
}

struct ContentView: View {
    @StateObject private var store = Store()
    @State private var count = 0

    var body: some View {
        NavigationView {
            List {
                Text("Count: \(count)")
                Button("bump") { count += 1 }
                Toggle("flag", isOn: $store.on)
                ForEach(store.items) { item in
                    NavigationLink(destination: Text(item.title)) {
                        HStack {
                            Text(item.title)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("demo")
        }
    }
}

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
