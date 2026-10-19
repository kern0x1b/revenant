import SwiftUI

struct Contact: Identifiable, Hashable {
    let id: Int
    var name: String
    var phone: String
    var favorite = false
}

struct ContactDetail: View {
    @Binding var contact: Contact
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.fill").font(.system(size: 44)).foregroundColor(.white)
                            .frame(width: 84, height: 84).background(Circle().fill(Color.gray))
                        Text(contact.name).font(.title2).bold()
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section(header: Text("Details")) {
                LabeledContent("Phone", value: contact.phone)
                TextField("Name", text: $contact.name)
                Toggle(isOn: $contact.favorite) { Label("Favorite", systemImage: "star") }
            }
            Section {
                NavigationLink(destination: Text("Notes")) { Label("Notes", systemImage: "doc") }
                NavigationLink(destination: Text("History")) { Label("History", systemImage: "clock") }
            }
            Section {
                Button("Call") {}
                Button("Delete Contact", role: .destructive) {}
            }
        }
        .navigationTitle(contact.name)
    }
}

struct ContactsView: View {
    @State private var contacts = (1...12).map { Contact(id: $0, name: ["Alice", "Bob", "Carol", "Dave"][$0 % 4] + " \($0)", phone: "555-01\(String(format: "%02d", $0))", favorite: $0 % 5 == 0) }
    @State private var filter = "All"

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Favorites")) {
                    ForEach($contacts.filter { $0.wrappedValue.favorite }) { $contact in
                        NavigationLink(destination: ContactDetail(contact: $contact)) { Text(contact.name) }
                    }
                }
                Section(header: Text("All contacts")) {
                    ForEach($contacts) { $contact in
                        NavigationLink(destination: ContactDetail(contact: $contact)) {
                            HStack {
                                Text(contact.name)
                                Spacer()
                                if contact.favorite { Image(systemName: "star.fill").foregroundColor(.orange) }
                            }
                        }
                    }
                    .onDelete { contacts.remove(atOffsets: $0) }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) { Button { } label: { Image(systemName: "plus") } }
            }
        }
    }
}

final class StackModel: ObservableObject { @Published var path: [Int] = [] }

struct PathStackCase: View {
    @ObservedObject var model: StackModel
    var body: some View {
        NavigationStack(path: $model.path) {
            VStack {
                NavigationLink("One", value: 1)
                NavigationLink("Two", value: 2)
            }
            .navigationTitle("Root")
            .navigationDestination(for: Int.self) { number in
                VStack {
                    Text("Detail \(number)")
                    NavigationLink("Deeper", value: number + 10)
                }
                .navigationTitle("Detail \(number)")
            }
        }
    }
}

struct FilterToken: Identifiable, Hashable { let id: String; var name: String { id } }

struct TokenSearchCase: View {
    @State private var query = ""
    @State private var tokens = [FilterToken(id: "Unread"), FilterToken(id: "Starred")]
    @State private var suggested = [FilterToken(id: "Today"), FilterToken(id: "Mine")]
    var body: some View {
        NavigationView {
            List(1...6, id: \.self) { Text("Message \($0)") }
                .navigationTitle("Mail")
                .searchable(text: $query, tokens: $tokens, suggestedTokens: $suggested, prompt: "Search") { token in
                    Text(token.name).font(.caption)
                }
        }
    }
}

nonisolated(unsafe) var swipeLog: [String] = []

struct SwipeRealCase: View {
    var body: some View {
        List {
            ForEach(1...5, id: \.self) { row in
                Text("Row \(row)")
                    .swipeActions(edge: .trailing) {
                        Button("Archive") { swipeLog.append("archive \(row)"); probe("swipe: archive \(row)") }.tint(.blue)
                        Button("Delete", role: .destructive) { swipeLog.append("delete \(row)"); probe("swipe: delete \(row)") }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Pin") { probe("swipe: pin \(row)") }.tint(.orange)
                    }
            }
        }
    }
}

struct EmptyStateCase: View {
    @State private var items: [String] = []
    var body: some View {
        NavigationView {
            List {
                if items.isEmpty {
                    Section(footer: Text("Nothing here yet. Tap Add to create the first item.")) {
                        Text("No items").foregroundColor(.secondary)
                    }
                } else {
                    ForEach(items, id: \.self) { Text($0) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Items")
            .toolbar { Button("Add") { items.append("Item \(items.count + 1)") } }
        }
    }
}
