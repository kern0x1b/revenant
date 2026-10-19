import SwiftUI

// A bare `if` in a widget bundle is a compile error in Apple's SDK, with the message
// "if statements in a WidgetBundleBuilder can only be used with #available clauses"
// (SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:21969). This must not compile either, and the
// error must name #available.
struct ClockConfiguration: WidgetConfiguration {
    var body: some WidgetConfiguration { EmptyWidgetConfiguration() }
}

struct ClockWidget: Widget {
    var body: some WidgetConfiguration { ClockConfiguration() }
}

struct PlatformWidgets: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        if true {
            ClockWidget()
        }
    }
}
