import SwiftUI

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
