import SwiftUI

// The same refusal with a named widget type in the `if`, which is the input that tells the
// generic-unavailable overload from a concrete one: `buildOptional<W>` at
// `arm64e-apple-ios.swiftinterface:21970` is generic and unavailable, so a bundle whose `if`
// yields a concrete widget is refused exactly as one that yields `any Widget` is.
struct PlainConfiguration: WidgetConfiguration {
    var body: some WidgetConfiguration { EmptyWidgetConfiguration() }
}

struct PlainWidget: Widget {
    var body: some WidgetConfiguration { PlainConfiguration() }
}

struct PlatformWidgets: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        if true {
            PlainWidget()
        }
    }
}
