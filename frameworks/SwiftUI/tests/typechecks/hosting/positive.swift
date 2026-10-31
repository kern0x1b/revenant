import SwiftUI
import UIKit

final class HostingView: UIView {
    private let hostingController: UIHostingController<AnyView>

    init(content: some View) {
        let controller = UIHostingController(rootView: AnyView(content))
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            controller.sizingOptions = [.intrinsicContentSize]
        }
        self.hostingController = controller
        super.init(frame: .zero)
        hostingController.view.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func applySafeAreaRegions(ignoring ignore: Bool) {
        guard #available(iOS 16.4, tvOS 16.4, macOS 13.3, *) else {
            return
        }
        let regions: SafeAreaRegions = ignore ? .all : .container
        hostingController.safeAreaRegions = regions
    }
}
