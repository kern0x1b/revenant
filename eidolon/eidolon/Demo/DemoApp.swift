@_spi(Probe) import SwiftUI
import UIKit

func logProbe(_ line: String) { probe(line) }

func probe(_ line: String) {
    let text = "[probe] \(line)\n"
    print(text, terminator: "")
    let path = "/tmp/eidolon-demo.log"
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
            .navigationTitle("Eidolon")
        }
        .environmentObject(library)
        .onAppear {
            probe("content appeared books=\(library.books.count)")
            if FileManager.default.fileExists(atPath: "/var/charon/perf.on") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { runPerf() }
            }
            if snapshotRun != nil {
                let folder = "/var/charon/eidolon-snapshots"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { writeSnapshots(to: folder) }
            }
        }
    }
}

func loadBackports() {
    probe("backports: UISwipeActionsConfiguration \(NSClassFromString("UISwipeActionsConfiguration") != nil ? "present" : "absent")")
}

/// What the run renders: the scenarios, one of them only, and whether each is drawn as an image. A key
/// of the bundle's own Info.plist says it, which is how the emulator's image says it - the snapshot
/// bundle is the same program built as another application, and xmake emulate launch starts that one, and
/// holds the guest until this process is gone (until-exit). /var/charon says it on a phone, where the
/// files are put there by hand and the application stays up afterwards. nil is no snapshot run.
let snapshotRun: (only: String?, images: Bool, fromBundle: Bool)? = {
    let fromBundle = Bundle.main.object(forInfoDictionaryKey: "EidolonSnapshots") != nil
    guard fromBundle || FileManager.default.fileExists(atPath: "/var/charon/snapshots.on") else {
        return nil
    }
    let only = (try? String(contentsOfFile: "/var/charon/snapshots.only", encoding: .utf8))
        ?? (Bundle.main.object(forInfoDictionaryKey: "EidolonSnapshotOnly") as? String)
    let name = only?.trimmingCharacters(in: .whitespacesAndNewlines)
    let images = Bundle.main.object(forInfoDictionaryKey: "EidolonSnapshotImages") != nil
        || FileManager.default.fileExists(atPath: "/var/charon/snapshots.png")
    return (name?.isEmpty == false ? name : nil, images, fromBundle)
}()

// /var/charon/gesture names a scenario whose real touches are run once it is on screen (a phone only).
func runDeviceGesture(_ name: String) {
    probe("swipe bridge: \(_Probe.swipeBridgeState())")
    probe("table recognisers: \(_Probe.tableRecognizers(in: UIApplication.shared.keyWindow ?? UIView()))")
    guard gesture_ready() else { probe("gesture: no HID client"); return }
    switch name {
    case "swipe-real":
        // a drag from the right edge to the left over the first row opens its trailing actions; a tap on the first action runs it
        let width = UIScreen.main.bounds.size.width
        gesture_drag({ CGPoint(x: width - 20, y: 42) }, { CGPoint(x: width - 230, y: 42) }, 12, 0.6)
        gesture_step(6.0) { probe("gesture: opened") }
        gesture_tap({ CGPoint(x: width - 45, y: 42) }, 0.5)
        gesture_step(0.5) { probe("gesture: log \(swipeLog) \(_Probe.swipeBridgeState())") }
    default: break
    }
    gesture_run { probe("gesture: done") }
}

@main
struct DemoApp: App {
    init() { loadBackports() }

    var body: some Scene {
        WindowGroup {
            // /var/charon/show names a scenario to keep on screen, so that a picture of the real screen can be taken
            if let name = try? String(contentsOfFile: "/var/charon/show", encoding: .utf8),
               let scenario = snapshotCases().first(where: { $0.name == name.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                AnyView(scenario.view).onAppear {
                    if let gesture = try? String(contentsOfFile: "/var/charon/gesture", encoding: .utf8) {
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
