@_spi(Probe) import SwiftUI
import UIKit
import Foundation

struct SnapshotCase {
    let name: String
    let width: CGFloat
    let height: CGFloat
    let view: any View
    var inWindow = false
    var action: ((_Probe) -> Void)? = nil
    var note: (() -> String)? = nil
}

nonisolated(unsafe) var snapshotTicks = 0

struct TickCase: View {
    let start = Date()
    var body: some View {
        TimelineView(.periodic(from: start, by: 0.1)) { context -> Color in
            snapshotTicks += 1
            return Color.orange
        }
        .frame(width: 30, height: 30)
    }
}

final class SnapshotModel: ObservableObject {
    @Published var on = false
    @Published var rows = [1, 2, 3]
}

struct TypographyCase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Large title").font(.largeTitle)
            Text("Title").font(.title)
            Text("Headline").font(.headline)
            Text("Body text that wraps onto a second line when the width runs out")
            Text("Footnote").font(.footnote).foregroundColor(.gray)
        }
        .padding(12)
    }
}

struct ControlsCase: View {
    @ObservedObject var model: SnapshotModel
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button("Left") {}
                Spacer()
                Button("Right") {}
            }
            Toggle("Switch", isOn: Binding(get: { model.on }, set: { model.on = $0 }))
            TextField("Placeholder", text: .constant("typed text"))
            Divider()
            HStack {
                Color.red.frame(width: 40, height: 20)
                Color.green.frame(width: 40, height: 20)
                Color.blue.frame(width: 40, height: 20)
                Spacer()
            }
        }
        .padding(12)
    }
}

struct LayoutCase: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Color.orange.frame(width: 60, height: 30)
                Spacer()
                Color.orange.frame(width: 30, height: 30)
            }
            HStack(spacing: 4) {
                Text("Leading")
                Spacer()
                Text("Trailing")
            }
            Text("Centered").frame(maxWidth: 300)
            Color.gray.frame(height: 2)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Title").font(.headline)
                    Text("Subtitle").font(.subheadline).foregroundColor(.gray)
                }
                Spacer()
                Text("›").foregroundColor(.gray)
            }
            .padding(8)
            .background(Color(red: 0.93, green: 0.93, blue: 0.95), cornerRadius: 6)
        }
        .padding(12)
    }
}

struct ListCase: View {
    @ObservedObject var model: SnapshotModel
    var body: some View {
        List {
            Section("first") {
                Text("Header row")
            }
            Section("rows") {
                ForEach(model.rows, id: \.self) { row in
                    HStack {
                        Text("Row \(row)")
                        Spacer()
                    if row == 2 {
                        Text("★").foregroundColor(.orange)
                    }
                    }
                }
            }
        }
    }
}

struct BoxButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(configuration.isPressed ? Color.gray : Color(red: 0.85, green: 0.9, blue: 1), cornerRadius: 6)
            .border(Color.blue, width: 1)
    }
}

struct StylesCase: View {
    @ObservedObject var model: SnapshotModel
    var body: some View {
        VStack(spacing: 10) {
            Button("Styled button") {}
                .buttonStyle(BoxButtonStyle())
            HStack(spacing: 8) {
                Circle().fill(Color.orange).frame(width: 24, height: 24)
                RoundedRectangle(cornerRadius: 6).stroke(Color.green, lineWidth: 2).frame(width: 40, height: 24)
                LinearGradient(colors: [.red, .blue], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 60, height: 24)
                    .cornerRadius(4)
            }
            Slider(value: Binding(get: { 0.4 }, set: { _ in }))
            ProgressView(value: 0.6)
            Text("shadowed").padding(6).background(Color.white).shadow(radius: 3)
        }
        .padding(12)
    }
}

struct FeaturesCase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("pi \(3.14159, specifier: "%.3f") count \(42)")
            Text("spaced").kerning(4)
            Text("hidden secret").redacted(reason: .placeholder)
            Grid(horizontalSpacing: 6, verticalSpacing: 2) {
                GridRow { Text("Name"); Text("Value") }
                GridRow { Text("A"); Text("1000") }
                Divider().gridCellUnsizedAxes(.horizontal)
            }
            Text("corner").frame(width: 120, height: 30, alignment: .bottomTrailing).border(Color.gray, width: 1)
            List { Text("Inbox").badge(7) }.frame(height: 60)
            TextField("Search", text: .constant("")).submitLabel(.search)
        }
        .padding(10)
    }
}

struct SearchCase: View {
    @State var scope = 1
    var body: some View {
        VStack(alignment: .leading) {
            Text("Results")
        }
        .searchable(text: .constant("abc"))
        .searchScopes($scope) {
            Text("All").tag(0)
            Text("Mine").tag(1)
        }
    }
}

func allViews<T: UIView>(_ root: UIView, of type: T.Type) -> [T] {
    var found: [T] = []
    func walk(_ view: UIView) {
        if let match = view as? T { found.append(match) }
        view.subviews.forEach(walk)
    }
    walk(root)
    return found
}

final class SuggestionModel: ObservableObject {
    @Published var text = ""
    var searching = false
}

struct SuggestionsCase: View {
    @ObservedObject var model: SuggestionModel
    var body: some View {
        List {
            Text("Apples")
            Text("Pears")
            SearchState(model: model)
        }
        .searchable(text: $model.text, prompt: "Fruit")
        .searchSuggestions {
            Text("Apricots").searchCompletion("Apricots")
            Text("Plums").searchCompletion("Plums")
        }
    }
}

struct SearchState: View {
    let model: SuggestionModel
    @Environment(\.isSearching) var isSearching
    var body: some View {
        let _ = model.searching = isSearching
        Text(isSearching ? "searching" : "idle")
    }
}

nonisolated(unsafe) var primitiveTrigger: (() -> Void)?
nonisolated(unsafe) var primitiveFired = 0

struct SwatchButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let _ = primitiveTrigger = { configuration.trigger() }
        HStack(spacing: 6) {
            Color.purple.frame(width: 33, height: 20)
            configuration.label
            Button(configuration)
        }
    }
}

struct PrimitiveCase: View {
    var body: some View {
        Button("Swatch") { primitiveFired += 1 }
            .buttonStyle(SwatchButtonStyle())
    }
}

struct SplitCase: View {
    @State var chosen: String?
    var body: some View {
        NavigationSplitView {
            List(["Apples", "Pears"], id: \.self, selection: $chosen) { name in Text(name) }
        } detail: {
            Text(chosen.map { "Detail for " + $0 } ?? "Nothing chosen")
        }
    }
}

struct PickersCase: View {
    @State var fruit = "Pear"
    @State var size = 2
    var body: some View {
        NavigationView {
            Form {
                Picker("Fruit", selection: $fruit) {
                    Text("Apple").tag("Apple")
                    Text("Pear").tag("Pear")
                }
                .pickerStyle(.navigationLink)
                Section("Size") {
                    Picker("Size", selection: $size) {
                        Text("Small").tag(1)
                        Text("Large").tag(2)
                    }
                    .pickerStyle(.inline)
                }
            }
        }
    }
}

struct ProgressCase: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView("Loading")
            ProgressView("Copying", value: 0.25)
            ProgressView(value: 0.75) { Text("Upload") } currentValueLabel: { Text("75%") }
        }
        .padding(10)
    }
}

struct CalendarCase: View {
    @State var days: Set<DateComponents> = [DateComponents(year: 2026, month: 2, day: 14)]
    var body: some View {
        MultiDatePicker("Days", selection: $days)._showing(Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 1))!)
    }
}

/// A date picker in each of the three styles, so the label is in the tree for all of them.
struct DatePickerStyleCase: View {
    @State var date = Date(timeIntervalSince1970: 1_260_000_000)
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("Birthday", selection: $date, displayedComponents: .date)
                .datePickerStyle(.field)
            DatePicker("Appointment", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.stepperField)
            DatePicker("Released", selection: $date)
                .datePickerStyle(.wheel)
        }
        .padding(10)
    }
}

struct NavigationCase: View {
    @State var active = true
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: Text("Pushed page"), isActive: $active) { Text("Go") }
            }
            .navigationTitle("Root")
        }
    }
}

final class ToolbarLog { var taps: [String] = [] }
let toolbarLog = ToolbarLog()

struct ToolbarCase: View {
    var body: some View {
        NavigationView {
            Color.gray.frame(height: 40)
                .navigationTitle("Bars")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { toolbarLog.taps.append("cancel") } }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button("Add") { toolbarLog.taps.append("add") }
                        Button { toolbarLog.taps.append("icon") } label: { Color.red.frame(width: 20, height: 20) }
                    }
                    ToolbarItem(placement: .principal) { Color.green.frame(width: 60, height: 20) }
                    ToolbarItem(placement: .bottomBar) { Button("Left") { toolbarLog.taps.append("left") } }
                    ToolbarItem(placement: .bottomBar) { Spacer() }
                    ToolbarItem(placement: .bottomBar) { Button("Right") { toolbarLog.taps.append("right") } }
                    ToolbarItem(id: "hidden", placement: .navigationBarLeading, showsByDefault: false) { Button("Hidden") {} }
                    ToolbarItem(placement: .keyboard) { Button("Done") {} }
                }
        }
    }
}

func pressBarItems(_ probe: _Probe) {
    for button in allViews(probe.hostView, of: UIButton.self) { button.sendActions(for: .touchUpInside) }
    probe.flush()
}

struct DestinationCase: View {
    @State var pushed = true
    var body: some View {
        NavigationView {
            Color.gray.frame(height: 20)
                .navigationTitle("Root")
                .navigationDestination(isPresented: $pushed) { Color.green.frame(width: 50, height: 50) }
        }
    }
}

func activateSearch(_ probe: _Probe) {
    allViews(probe.hostView, of: UISearchBar.self).first?.becomeFirstResponder()
    probe.flush()
    probe.flush()
}

final class InputModel: ObservableObject {
    @Published var amount = 5.0
    @Published var level = 0.25
    @Published var text = ""
    var editing: [Bool] = []
    var committed = 0
}

struct InputCase: View {
    @ObservedObject var model: InputModel
    var body: some View {
        VStack {
            Stepper(value: $model.amount, in: 0...8, step: 2) { Color.red.frame(width: 10, height: 10) }
            Slider(value: $model.level, in: 0...1, step: 0.25) { model.editing.append($0) }
            TextField("Name", text: $model.text, onCommit: { model.committed += 1 })
        }
    }
}

func probeNote(_ m: InputModel) -> String {
    "amount \(m.amount), level \(m.level), text \(m.text), editing \(m.editing), committed \(m.committed)"
}

func driveInput(_ probe: _Probe, _ model: InputModel) {
    if let stepper = allViews(probe.hostView, of: UIStepper.self).first {
        stepper.value = 1
        stepper.sendActions(for: .valueChanged)
        probe.flush()
    }
    if let slider = allViews(probe.hostView, of: UISlider.self).first {
        slider.value = 0.6
        slider.sendActions(for: .valueChanged)
        slider.sendActions(for: .touchDown)
        slider.sendActions(for: .touchUpInside)
        probe.flush()
    }
    if let field = allViews(probe.hostView, of: UITextField.self).first {
        field.text = "hello"
        field.sendActions(for: .editingChanged)
        probe.flush()
        field.sendActions(for: .editingDidEndOnExit)
        model.text += "!"
        probe.flush()
    }
}

func snapshotCases() -> [SnapshotCase] {
    let inputs = InputModel()
    let stackModel = StackModel()
    let model = SnapshotModel()
    let suggesting = SuggestionModel()
    let completing = SuggestionModel()
    return [
        SnapshotCase(name: "styles", width: 320, height: 240, view: StylesCase(model: model)),
        SnapshotCase(name: "typography", width: 320, height: 240, view: TypographyCase()),
        SnapshotCase(name: "controls", width: 320, height: 220, view: ControlsCase(model: model)),
        SnapshotCase(name: "layout", width: 320, height: 240, view: LayoutCase()),
        SnapshotCase(name: "list", width: 320, height: 260, view: ListCase(model: model)),
        SnapshotCase(name: "features", width: 320, height: 300, view: FeaturesCase()),
        SnapshotCase(name: "navigation", width: 320, height: 300, view: NavigationCase(), inWindow: true),
        SnapshotCase(name: "toolbar", width: 320, height: 300, view: ToolbarCase(), inWindow: true,
                     action: pressBarItems, note: { "taps \(toolbarLog.taps.sorted())" }),
        SnapshotCase(name: "destination", width: 320, height: 200, view: DestinationCase(), inWindow: true),
        SnapshotCase(name: "app-settings", width: 320, height: 640, view: SettingsView(), inWindow: true),
        SnapshotCase(name: "app-inbox", width: 320, height: 480, view: Inbox(), inWindow: true,
                     action: { probe in
                         guard let window = UIApplication.shared.keyWindow else { return }
                         allViews(window, of: UIButton.self).first { $0.title(for: .normal) == "Edit" }?.sendActions(for: .touchUpInside)
                         probe.flush()
                         RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
                     },
                     note: { "editing \(allViews(UIApplication.shared.keyWindow ?? UIView(), of: UITableView.self).contains { $0.isEditing })" }),
        SnapshotCase(name: "app-chat", width: 320, height: 480, view: NavigationView { ChatView() }, inWindow: true),
        SnapshotCase(name: "app-dashboard", width: 320, height: 640, view: DashboardView(), inWindow: true),
        SnapshotCase(name: "app-feed", width: 320, height: 568, view: FeedView(), inWindow: true),
        SnapshotCase(name: "app-calculator", width: 320, height: 568, view: UtilityTabs(), inWindow: true),
        SnapshotCase(name: "symbols", width: 320, height: 720, view: SymbolGallery()),
        SnapshotCase(name: "app-store", width: 320, height: 568, view: StoreView(), inWindow: true),
        SnapshotCase(name: "app-onboarding", width: 320, height: 568, view: OnboardingView(), inWindow: true),
        SnapshotCase(name: "app-player", width: 320, height: 568, view: PlayerView(), inWindow: true),
        SnapshotCase(name: "app-contacts", width: 320, height: 568, view: ContactsView(), inWindow: true),
        SnapshotCase(name: "app-browser", width: 320, height: 568, view: BrowserView(), inWindow: true,
                     action: { probe in RunLoop.main.run(until: Date(timeIntervalSinceNow: 4)); probe.flush() }),
        SnapshotCase(name: "stack-path", width: 320, height: 300, view: PathStackCase(model: stackModel), inWindow: true,
                     action: { probe in
                         stackModel.path = [1, 11]; probe.flush(); RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.8)); probe.flush()
                         stackModel.path = [1, 11, 2]; probe.flush(); RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.8)); probe.flush()
                         stackModel.path = [1]; probe.flush(); RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.8)); probe.flush()
                     },
                     note: { "path \(stackModel.path)" }),
        SnapshotCase(name: "app-tokens", width: 320, height: 400, view: TokenSearchCase(), inWindow: true),
        SnapshotCase(name: "swipe-real", width: 320, height: 300, view: SwipeRealCase(), inWindow: true),
        SnapshotCase(name: "app-detail", width: 320, height: 568, view: NavigationView { ContactDetail(contact: .constant(Contact(id: 1, name: "Alice", phone: "555-0101", favorite: true))) }, inWindow: true),
        SnapshotCase(name: "app-empty", width: 320, height: 300, view: EmptyStateCase(), inWindow: true),
        SnapshotCase(name: "reserve", width: 200, height: 120, view: VStack { Text("One line").lineLimit(3, reservesSpace: true) }),
        SnapshotCase(name: "search", width: 320, height: 200, view: SearchCase()),
        SnapshotCase(name: "split", width: 320, height: 300, view: SplitCase(), inWindow: true, action: { $0.selectRow(1) }),
        SnapshotCase(name: "pickers", width: 320, height: 300, view: PickersCase(), inWindow: true),
        SnapshotCase(name: "progress", width: 320, height: 200, view: ProgressCase()),
        SnapshotCase(name: "calendar", width: 320, height: 300, view: CalendarCase()),
        SnapshotCase(name: "date-picker-styles", width: 320, height: 780, view: DatePickerStyleCase()),
        SnapshotCase(name: "suggestions", width: 320, height: 300, view: SuggestionsCase(model: suggesting), inWindow: true,
                     action: activateSearch,
                     note: { "isSearching \(suggesting.searching)" }),
        SnapshotCase(name: "completion", width: 320, height: 300, view: SuggestionsCase(model: completing), inWindow: true,
                     action: { probe in
                         activateSearch(probe)
                         let rows = allViews(probe.hostView, of: UIButton.self)
                         rows.last?.sendActions(for: .touchUpInside)
                         probe.flush()
                         probe.flush()
                     },
                     note: { "text \(completing.text), isSearching \(completing.searching)" }),
        SnapshotCase(name: "primitive", width: 320, height: 60, view: PrimitiveCase(),
                     action: { probe in primitiveTrigger?(); probe.flush() },
                     note: { "fired \(primitiveFired)" }),
        SnapshotCase(name: "controlinput", width: 320, height: 200, view: InputCase(model: inputs),
                     action: { probe in driveInput(probe, inputs) },
                     note: { probeNote(inputs) }),
        SnapshotCase(name: "timeline", width: 100, height: 100, view: TickCase(), note: { snapshotTicks >= 4 ? "timeline ticked" : "timeline stalled at \(snapshotTicks)" }),
    ]
}

func writeSnapshots(to folder: String) {
    guard let run = snapshotRun else { return }
    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
    let filter = run.only
    for scenario in snapshotCases() where filter == nil || filter!.isEmpty || scenario.name == filter {
        let started = Date()
        let probe = _Probe(scenario.view, width: scenario.width, height: scenario.height)
        if scenario.inWindow, let window = UIApplication.shared.keyWindow { window.addSubview(probe.hostView) }
        probe.flush()
        if let action = scenario.action {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
            action(probe)
            probe.flush()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.8))
        probe.flush()
        var tree = probe.dump()
        if let note = scenario.note { tree += "\n" + note() }
        if scenario.inWindow {
            tree += "\nnavigation depth \(probe.navigationDepth)"
            probe.hostView.removeFromSuperview()
        }
        // A scenario that cannot be written is a failure of the run, not a scenario quietly missing from
        // it: the comparison against the references is the assertion, and a swallowed write would make
        // it pass over a scenario that was never rendered.
        do {
            try tree.write(toFile: folder + "/" + scenario.name + ".txt", atomically: true, encoding: .utf8)
        } catch {
            logProbe("snapshot \(scenario.name) tree NOT written: \(error)")
            continue
        }
        logProbe(String(format: "snapshot %@ tree %d lines in %.0f ms", scenario.name, tree.components(separatedBy: "\n").count, Date().timeIntervalSince(started) * 1000))
        guard run.images else { continue }
        let imageStarted = Date()
        let size = CGSize(width: scenario.width, height: scenario.height)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let context = UIGraphicsGetCurrentContext() else {
            logProbe("snapshot \(scenario.name) image NOT drawn: no context")
            continue
        }
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        probe.hostView.layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let data = image?.pngData() else {
            logProbe("snapshot \(scenario.name) image NOT drawn: no image")
            continue
        }
        do {
            try data.write(to: URL(fileURLWithPath: folder + "/" + scenario.name + ".png"))
        } catch {
            logProbe("snapshot \(scenario.name) image NOT written: \(error)")
            continue
        }
        logProbe(String(format: "snapshot %@ image %d bytes in %.0f ms", scenario.name, data.count, Date().timeIntervalSince(imageStarted) * 1000))
    }
    logProbe("snapshots done")
    // The bundle that was asked for them is done, so the application is: in the emulator
    // `xmake emulate launch ... until-exit` holds the guest until this process is gone and then takes the
    // last frame. A phone run watches for the line above and leaves the application up.
    if run.fromBundle {
        exit(0)
    }
}
