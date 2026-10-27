@_spi(Probe) import SwiftUI
import UIKit

func logProbe(_ line: String) { probe(line) }

func probe(_ line: String) {
    let text = "[probe] \(line)\n"
    print(text, terminator: "")
    let path = "/tmp/swiftui-demo.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile(); handle.write(text.data(using: .utf8)!); handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: text.data(using: .utf8), attributes: nil)
    }
}

final class Library: ObservableObject {
    @Published var books: [Book] = [
        Book(id: 1, title: "Moby-Dick", author: "Herman Melville"),
        Book(id: 2, title: "War and Peace", author: "Leo Tolstoy"),
        Book(id: 3, title: "The Master and Margarita", author: "Mikhail Bulgakov"),
    ]
    @Published var favorites: Set<Int> = []
}

struct Book: Identifiable {
    let id: Int
    let title: String
    let author: String
}

struct CounterCard: View {
    @State private var count = 0
    @State private var enabled = true
    @State private var name = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Count: \(count)")
                .font(.title)
            HStack {
                Button("−") { count -= 1; probe("tap minus count=\(count)") }
                Spacer()
                Button("+") { count += 1; probe("tap plus count=\(count)") }
            }
            Toggle("Counting enabled", isOn: $enabled)
            if !enabled {
                Text("Counting is paused").foregroundColor(.red)
            }
            TextField("Your name", text: $name)
                .onAppear { probe("counter card appeared") }
            Text(name.isEmpty ? "Hello, stranger" : "Hello, \(name)")
        }
        .padding(16)
    }
}

struct BookRow: View {
    let book: Book
    @EnvironmentObject var library: Library

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title).font(.headline)
                Text(book.author).font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            if library.favorites.contains(book.id) {
                Text("★").foregroundColor(.orange)
            }
        }
    }
}

struct BookDetail: View {
    let book: Book
    @EnvironmentObject var library: Library
    @State private var showingNote = false
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 16) {
            Text(book.title).font(.title)
            Text("by \(book.author)")
            Button("About this book") { showingNote = true; probe("sheet requested") }
            Button("Forget it") { confirming = true; probe("alert requested") }
            Button(library.favorites.contains(book.id) ? "Remove from favorites" : "Add to favorites") {
                if library.favorites.contains(book.id) { library.favorites.remove(book.id) } else { library.favorites.insert(book.id) }
                probe("favorites=\(library.favorites.sorted())")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dumpWindow("after-favorite") }
            }
        }
        .padding()
        .navigationTitle(book.author)
        .sheet(isPresented: $showingNote) {
            VStack(spacing: 12) {
                Text(book.title).font(.headline)
                Text("A note about this book, shown in a sheet.")
                Button("Close") { showingNote = false; probe("sheet closed") }
            }
            .padding()
        }
        .alert(isPresented: $confirming) {
            Alert(title: Text("Forget \(book.title)?"),
                  message: Text("It stays in the list either way."),
                  primaryButton: .cancel(Text("Keep")) { probe("alert kept") },
                  secondaryButton: .destructive(Text("Forget")) { probe("alert forgot") })
        }
        .onAppear { probe("detail appeared \(book.title)") }
    }
}

struct ContentView: View {
    @StateObject private var library = Library()

    var body: some View {
        NavigationView {
            List {
                CounterCard()
                ForEach(library.books) { book in
                    NavigationLink(destination: BookDetail(book: book)) {
                        BookRow(book: book)
                    }
                }
            }
            .navigationTitle("SwiftUI")
        }
        .environmentObject(library)
        .onAppear {
            probe("content appeared books=\(library.books.count)")
            if perfFromBundle || FileManager.default.fileExists(atPath: "/var/revenant/perf.on") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { runPerf() }
            }
            if snapshotRun != nil {
                let folder = "/var/revenant/swiftui-snapshots"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { writeSnapshots(to: folder) }
            }
        }
    }
}

func loadBackports() {
    probe("backports: UISwipeActionsConfiguration \(NSClassFromString("UISwipeActionsConfiguration") != nil ? "present" : "absent")")
}

let perfFromBundle = Bundle.main.object(forInfoDictionaryKey: "SwiftUIPerf") != nil

let snapshotRun: (only: String?, images: Bool, fromBundle: Bool)? = {
    let fromBundle = Bundle.main.object(forInfoDictionaryKey: "SwiftUISnapshots") != nil
    guard fromBundle || FileManager.default.fileExists(atPath: "/var/revenant/snapshots.on") else {
        return nil
    }
    let only = (try? String(contentsOfFile: "/var/revenant/snapshots.only", encoding: .utf8))
        ?? (Bundle.main.object(forInfoDictionaryKey: "SwiftUISnapshotOnly") as? String)
    let name = only?.trimmingCharacters(in: .whitespacesAndNewlines)
    let images = Bundle.main.object(forInfoDictionaryKey: "SwiftUISnapshotImages") != nil
        || FileManager.default.fileExists(atPath: "/var/revenant/snapshots.png")
    return (name?.isEmpty == false ? name : nil, images, fromBundle)
}()

// Shows a scenario on the phone the way the snapshot run builds it: a probe hosts the view, and the scenario's action
// (search activated, a row tapped) runs on it before the screen is marked ready for its picture.
func showLive(_ scenario: SnapshotCase) {
    guard let action = scenario.action else {
        probe("live: \(scenario.name) ready")
        return
    }
    guard let window = UIApplication.shared.keyWindow else {
        probe("live: \(scenario.name) no key window")
        return
    }
    let size = UIScreen.main.bounds.size
    let host = _Probe(scenario.view, width: size.width, height: size.height)
    window.addSubview(host.hostView)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        action(host)
        probe("live: \(scenario.name) ready")
    }
}

func runDeviceGesture(_ name: String) {
    // The touches of swipe-real come from the phone's revenant-unlock, from outside this process: injecting them from
    // inside the demo quits the demo mid-drag (measured on the iPad). This script only waits for them and reports.
    switch name {
    case "swipe-real":
        probe("gesture: waiting for the swipe")
    default: break
    }
    gesture_run { probe("gesture: done") }
}

@main
struct DemoApp: App {
    init() { loadBackports() }

    var body: some Scene {
        WindowGroup {
            if let name = try? String(contentsOfFile: "/var/revenant/show", encoding: .utf8),
               let scenario = snapshotCases().first(where: { $0.name == name.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                AnyView(scenario.action == nil ? AnyView(scenario.view) : AnyView(Text(""))).onAppear {
                    showLive(scenario)
                    if let gesture = try? String(contentsOfFile: "/var/revenant/gesture", encoding: .utf8) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { runDeviceGesture(gesture.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    }
                }
            } else {
                ContentView()
            }
        }
    }
}

func dumpWindow(_ tag: String) {
    guard let window = UIApplication.shared.keyWindow else { probe("\(tag): no key window"); return }
    var lines: [String] = []
    func walk(_ v: UIView, _ depth: Int) {
        let f = v.frame
        var extra = ""
        if let l = v as? UILabel { extra = " text=\"\(l.text ?? "")\"" }
        if let b = v as? UIButton { extra = " title=\"\(b.title(for: .normal) ?? "")\"" }
        if let s = v as? UISwitch { extra = " on=\(s.isOn)" }
        if let n = v as? UINavigationBar { extra = " items=\(n.items?.map { $0.title ?? "" } ?? [])" }
        if v.isHidden { extra += " hidden" }
        lines.append(String(repeating: "  ", count: depth) + "\(type(of: v)) (\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.size.width)),\(Int(f.size.height)))" + extra)
        for sub in v.subviews { walk(sub, depth + 1) }
    }
    walk(window, 0)
    probe("\(tag):\n" + lines.joined(separator: "\n"))
}

final class Flag: ObservableObject {
    @Published var paused = false
}

struct CondTest: View {
    @ObservedObject var flag: Flag
    var body: some View {
        VStack(spacing: 4) {
            Text("a")
            if flag.paused {
                Text("paused").foregroundColor(.red)
            }
            Color.blue.frame(height: 6)
            if flag.paused {
                Color.orange.frame(height: 6)
            }
            Text("b")
        }
    }
}

func runConditionalProbe() {
    let flag = Flag()
    let probe = _Probe(CondTest(flag: flag), width: 200, height: 200)
    logProbe("cond before:\n" + probe0(probe))
    flag.paused = true
    probe.flush()
    logProbe("cond after:\n" + probe0(probe))
}

func probe0(_ p: _Probe) -> String { p.dump() }
