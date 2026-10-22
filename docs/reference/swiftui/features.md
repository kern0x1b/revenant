# Features

A retained node tree over UIKit views, with a reconciler, a layout engine of its own and a scheduler that re-renders
only what changed. The areas below are exercised by tests and by rendered scenarios; the full ledger — what is
implemented, what is deliberately ignored and why, what is simplified — is in [`ledger.md`](ledger.md)
and is checked by the build.

| Area | What there is |
| --- | --- |
| Description and state | `View`, `ViewBuilder`, `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, `@EnvironmentObject`, `@Environment`, `@AppStorage`, `@FocusState`, `@GestureState`, `@FetchRequest` (over Core Data) |
| Layout | stacks, `ZStack`, `Grid`, lazy stacks and grids, `ScrollView`, `GeometryReader`, alignment guides, the `Layout` protocol with a persistent cache and animatable layouts |
| Controls and text | `Text` (concatenation, styles), `Button`, `Toggle`, `TextField`, `Slider`, `Stepper`, `Picker`, `DatePicker`, `List`, `Form`, `Table`, `Menu`, `Label`, `ProgressView`, `Canvas` |
| Navigation and presentation | `NavigationView`, `NavigationStack`, `NavigationSplitView`, `TabView`, sheets, every form of `alert` and `confirmationDialog`, search |
| Gestures | typed gesture engine: `map`, `updating` with `@GestureState`, `sequenced`, `exclusively`, `simultaneously`, custom gestures through `body` |
| Animation | `withAnimation`, `repeatForever`, transitions, `matchedGeometryEffect`; the `animatableData` of custom shapes, geometry effects, view modifiers and layouts is interpolated frame by frame |
| Graphics | `Shape` and `Path` (trim, stroke, relative arcs), gradients, `GeometryEffect`, `ProjectionTransform` |
| Bridges | `UIViewRepresentable`, `UIViewControllerRepresentable`, `UIHostingController` |
| Accessibility | labels, values, traits, containers built from `accessibilityChildren`, sort priority, VoiceOver focus |
