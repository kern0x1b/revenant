import UIKit

/// How a navigation move looks. iOS 6 has one move to make - the release's own push - so a
/// transition chooses which of the release's animations a push gets, and `zoom` is the push.
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

/// The title a navigation bar shows in each of the three ways a title can be shown; iOS 6 has the
/// three, so the mode is a value like any other.
extension NavigationBarItem.TitleDisplayMode: Hashable {}

extension TabViewStyle {
    /// iOS 6 shows a tab bar and nothing else, so both of these keep it.
    public static var sidebarAdaptable: DefaultTabViewStyle { DefaultTabViewStyle() }
    public static var tabBarOnly: DefaultTabViewStyle { DefaultTabViewStyle() }
}

extension View {
    /// A link that is not a detail link shows what it points at without pushing: the release's own
    /// push belongs to a link that opens a screen.
    public func isDetailLink(_ isDetailLink: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.opensByPushing = isDetailLink }, onUpdate: nil))
    }
}
