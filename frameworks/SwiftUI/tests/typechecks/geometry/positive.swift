import SwiftUI

final class ShadowProxy {
    var setViewSize: ((CGSize) -> Void)?
}

struct AutoSized<Content: View>: View {
    let content: Content
    let axis: Axis.Set
    let proxy: ShadowProxy

    var body: some View {
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            content.overlay {
                content.fixedSize(horizontal: axis.contains(.horizontal), vertical: axis.contains(.vertical))
                    .hidden()
                    .onGeometryChange(for: CGSize.self, of: { proxy in proxy.size }, action: { size in
                        var size = size
                        size.width = axis.contains(.horizontal) ? size.width : 0
                        size.height = axis.contains(.vertical) ? size.height : 0
                        self.proxy.setViewSize?(size)
                    })
            }
        } else {
            content
        }
    }
}
