import UIKit

public protocol NavigationTransition {}

public struct AutomaticNavigationTransition: NavigationTransition {
    public init() {}
}

public struct ZoomNavigationTransition: NavigationTransition {
    let sourceID: AnyHashable
    public let namespace: Namespace.ID
    public init(sourceID: some Hashable, in namespace: Namespace.ID) {
        self.sourceID = AnyHashable(sourceID); self.namespace = namespace
    }
}

extension NavigationTransition where Self == AutomaticNavigationTransition {
    public static var automatic: Self { AutomaticNavigationTransition() }
}

extension NavigationTransition where Self == ZoomNavigationTransition {
    public static func zoom(sourceID: some Hashable, in namespace: Namespace.ID) -> Self {
        ZoomNavigationTransition(sourceID: sourceID, in: namespace)
    }
}

extension NavigationBarItem.TitleDisplayMode: Hashable {}

extension TabViewStyle {
    public static var sidebarAdaptable: DefaultTabViewStyle { DefaultTabViewStyle() }
    public static var tabBarOnly: DefaultTabViewStyle { DefaultTabViewStyle() }
}

extension View {
    public func isDetailLink(_ isDetailLink: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.opensByPushing = isDetailLink }, onUpdate: nil))
    }
}
