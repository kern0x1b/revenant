import SwiftUI

struct Row: Identifiable {
    let id: Int
    let title: String
}

struct Consumer: View {
    @State private var rows = [Row(id: 1, title: "one"), Row(id: 2, title: "two")]
    @State private var width: CGFloat = 20
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SwiftUI from a package")
                .font(.body)
                .foregroundColor(scheme == .dark ? .white : .black)
            ForEach(rows) { row in
                HStack {
                    Text(row.title)
                    Spacer()
                    Text("\\(row.id)")
                }
                .frame(width: width, height: 20)
            }
            Button("wider") { width += 10 }
                .buttonStyle(.bordered)
        }
        .padding(8)
    }
}

let made: AnyView = AnyView(Consumer())
print("consumer took \(type(of: made))")
