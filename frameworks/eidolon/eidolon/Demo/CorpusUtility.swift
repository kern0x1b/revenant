import SwiftUI

struct CalculatorKey: View {
    let title: String
    var tint: Color = Color(white: 0.85)
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(tint)
                .foregroundColor(tint == Color(white: 0.85) ? .black : .white)
                .cornerRadius(10)
        }
    }
}

struct CalculatorView: View {
    @State private var display = "0"
    @State private var stored: Double?
    @State private var pending: String?
    private let rows = [["7", "8", "9", "÷"], ["4", "5", "6", "×"], ["1", "2", "3", "−"], ["0", ".", "=", "+"]]

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(display)
                .font(.system(size: 52, weight: .light))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal)
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        CalculatorKey(title: key, tint: "÷×−+=".contains(key) ? .orange : Color(white: 0.85)) { press(key) }
                    }
                }
            }
            CalculatorKey(title: "C", tint: .gray) { display = "0"; stored = nil; pending = nil }
        }
        .padding()
    }

    private func press(_ key: String) {
        switch key {
        case "0"..."9", ".": display = display == "0" ? key : display + key
        case "=": if let stored, let pending, let value = Double(display) { display = String(apply(pending, stored, value)); self.stored = nil }
        default: stored = Double(display); pending = key; display = "0"
        }
    }

    private func apply(_ op: String, _ a: Double, _ b: Double) -> Double {
        switch op { case "+": return a + b; case "−": return a - b; case "×": return a * b; default: return b == 0 ? 0 : a / b }
    }
}

struct TimerView: View {
    @State private var seconds = 0
    @State private var running = false
    @State private var laps: [Int] = []
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                .font(.system(size: 64, design: .monospaced))
            HStack(spacing: 30) {
                Button(running ? "Pause" : "Start") { running.toggle() }
                    .buttonStyle(.borderedProminent)
                Button("Lap") { laps.append(seconds) }.disabled(!running)
                Button("Reset") { seconds = 0; laps = []; running = false }
            }
            List(Array(laps.enumerated()), id: \.offset) { index, lap in
                HStack { Text("Lap \(index + 1)"); Spacer(); Text("\(lap)s").foregroundColor(.secondary) }
            }
            .listStyle(.plain)
        }
        .padding()
        .onReceive(ticker) { _ in if running { seconds += 1 } }
    }
}

struct UtilityTabs: View {
    var body: some View {
        TabView {
            CalculatorView().tabItem { Label("Calc", systemImage: "plus.slash.minus") }
            TimerView().tabItem { Label("Timer", systemImage: "timer") }
        }
    }
}

let symbolGalleryNames = ["plus", "minus", "xmark", "checkmark", "chevron.right", "chevron.left", "chevron.up", "chevron.down", "chevron.up.chevron.down",
    "arrow.right", "arrow.left", "arrow.up", "arrow.down", "arrow.clockwise", "magnifyingglass", "heart", "heart.fill", "star", "star.fill",
    "house", "house.fill", "person", "person.fill", "person.2", "gearshape", "trash", "trash.fill", "pencil", "square.and.pencil", "square.and.arrow.up",
    "paperplane", "paperplane.fill", "bubble.left", "bubble.right", "bell", "bell.fill", "envelope", "camera", "photo", "calendar", "clock", "timer",
    "ellipsis", "line.3.horizontal", "list.bullet", "folder", "folder.fill", "doc", "lock", "lock.fill", "eye", "bookmark", "bookmark.fill", "cart",
    "info.circle", "exclamationmark.triangle", "plus.circle", "plus.circle.fill", "xmark.circle", "xmark.circle.fill", "checkmark.circle",
    "checkmark.circle.fill", "checkmark.square", "checkmark.square.fill", "play.fill", "pause.fill", "stop.fill", "forward.fill", "backward.fill",
    "globe", "location", "location.fill", "mic", "wifi", "circle", "circle.fill", "square", "square.fill", "square.grid.2x2", "sun.max", "moon", "bolt", "bolt.fill",
    "link", "slider.horizontal.3", "speaker", "speaker.wave.1", "speaker.wave.2", "speaker.wave.3", "music.note", "not.a.symbol"]

struct SymbolGallery: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 6) {
            ForEach(symbolGalleryNames, id: \.self) { name in
                Image(systemName: name).font(.system(size: 28)).frame(width: 40, height: 40)
            }
        }
        .padding(6)
    }
}
