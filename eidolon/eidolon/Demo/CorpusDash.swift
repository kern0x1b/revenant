import SwiftUI

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.96)))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct RingView: View {
    var progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.3), lineWidth: 10)
            Circle().trim(from: 0, to: progress)
                .stroke(AngularGradient(gradient: Gradient(colors: [.blue, .purple]), center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            Text("\(Int(progress * 100))%").font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .frame(width: 100, height: 100)
    }
}

struct DashboardView: View {
    @State private var progress = 0.3
    @State private var expanded = false
    @State private var tab = 0
    @GestureState private var pressing = false
    let columns = [GridItem(.adaptive(minimum: 80), spacing: 12)]

    var body: some View {
        TabView(selection: $tab) {
            ScrollView {
                VStack(spacing: 16) {
                    Card(title: "Progress") { RingView(progress: progress) }
                    Card(title: "Tiles") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<8) { index in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hue: Double(index) / 8, saturation: 0.6, brightness: 0.9))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(Text("\(index)").foregroundColor(.white))
                            }
                        }
                    }
                    DisclosureGroup("More", isExpanded: $expanded) {
                        Text("Details").padding(.top, 4)
                    }
                    Button("Advance") { withAnimation { progress = min(1, progress + 0.1) } }
                        .buttonStyle(.borderedProminent)
                    GeometryReader { proxy in
                        Capsule().fill(Color.green).frame(width: proxy.size.width * progress, height: 8)
                    }
                    .frame(height: 8)
                    Text("Hold")
                        .scaleEffect(pressing ? 1.2 : 1)
                        .gesture(LongPressGesture(minimumDuration: 0.3).updating($pressing) { value, state, _ in state = value })
                }
                .padding()
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)
            Text("Other").tabItem { Label("Other", systemImage: "star") }.tag(1)
        }
    }
}
