import SwiftUI

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
