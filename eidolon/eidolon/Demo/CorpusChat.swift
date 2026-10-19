import SwiftUI

struct Message: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var mine: Bool
    var date = Date()
}

struct Bubble: View {
    let message: Message
    var body: some View {
        HStack {
            if message.mine { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(message.mine ? Color.blue : Color(white: 0.9))
                .foregroundColor(message.mine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contextMenu {
                    Button { UIPasteboard.general.string = message.text } label: { Label("Copy", systemImage: "doc.on.doc") }
                }
            if !message.mine { Spacer(minLength: 40) }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ChatView: View {
    @State private var messages = [Message(text: "Hi", mine: false)]
    @State private var draft = ""
    @Namespace private var bottom

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(messages) { message in Bubble(message: message).id(message.id) }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }
            Divider()
            HStack {
                TextField("Message", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button(action: send) { Image(systemName: "paperplane.fill") }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
        }
        .navigationTitle("Chat")
        .background(Color.white.ignoresSafeArea())
    }

    private func send() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.append(Message(text: draft, mine: true))
        }
        draft = ""
    }
}

struct Inbox: View {
    @State private var items = (1...20).map { "Conversation \($0)" }
    @State private var search = ""
    @State private var selection: String?
    var filtered: [String] { search.isEmpty ? items : items.filter { $0.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                ForEach(filtered, id: \.self) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading) {
                            Text(item).font(.headline)
                            Text("Last message").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { items.removeAll { $0 == item } } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                .onDelete { items.remove(atOffsets: $0) }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: "Search")
            .refreshable { try? await Task.sleep(nanoseconds: 100_000_000) }
            .navigationTitle("Inbox")
            .navigationDestination(for: String.self) { _ in ChatView() }
            .toolbar { EditButton() }
        }
    }
}
