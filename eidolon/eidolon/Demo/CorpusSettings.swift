import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Profile: Codable, Equatable {
    var name = ""
    var email = ""
    var age = 30
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var profile = Profile()
    @Published var theme: Theme = .system
    @Published var notifications = true
    @Published var volume = 0.5
    @Published var accent = Color.blue
    @Published var birthday = Date(timeIntervalSince1970: 800_000_000)
    @Published var isSaving = false
    @Published var error: String?

    var isValid: Bool { !profile.name.isEmpty && profile.email.contains("@") }

    func save() async {
        isSaving = true
        defer { isSaving = false }
        try? await Task.sleep(nanoseconds: 300_000_000)
        if !isValid { error = "Invalid profile" }
    }
}

struct SettingsView: View {
    @StateObject private var model = SettingsModel()
    @AppStorage("username") private var username = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?
    @State private var showReset = false

    enum Field: Hashable { case name, email }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile")) {
                    TextField("Name", text: $model.profile.name)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .email }
                    TextField("Email", text: $model.profile.email)
                        .focused($focused, equals: .email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Stepper("Age: \(model.profile.age)", value: $model.profile.age, in: 13...120)
                    DatePicker("Birthday", selection: $model.birthday, displayedComponents: .date)
                }
                Section(header: Text("Appearance"), footer: Text("Applies after restart")) {
                    Picker("Theme", selection: $model.theme) {
                        ForEach(Theme.allCases) { theme in Text(theme.title).tag(theme) }
                    }
                    .pickerStyle(.segmented)
                    ColorPicker("Accent", selection: $model.accent)
                    Slider(value: $model.volume, in: 0...1) { Text("Volume") }
                }
                Section {
                    Toggle("Notifications", isOn: $model.notifications)
                    if model.notifications {
                        Text("You will be notified").font(.footnote).foregroundColor(.secondary)
                    }
                    Button(role: .destructive) { showReset = true } label: { Label("Reset", systemImage: "trash") }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await model.save() } }.disabled(!model.isValid || model.isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = nil }
                }
            }
            .alert("Error", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } }), actions: {
                Button("OK", role: .cancel) {}
            }, message: { Text(model.error ?? "") })
            .confirmationDialog("Reset everything?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.profile = Profile() }
                Button("Cancel", role: .cancel) {}
            }
            .overlay {
                if model.isSaving { ProgressView().padding().background(.ultraThinMaterial).cornerRadius(8) }
            }
            .task { username = model.profile.name }
            .onChange(of: model.theme) { newValue in username = newValue.title }
        }
    }
}
