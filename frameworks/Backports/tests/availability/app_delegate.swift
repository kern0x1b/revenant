import UIKit

protocol Subscriber: UIApplicationDelegate {}

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {}
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {}
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {}
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool { return false }
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool { return false }
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool { return false }
    func application(_ application: UIApplication, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {}
    func application(_ application: UIApplication, didUpdate userActivity: NSUserActivity) {}
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {}
}

enum Forwarding {
    static func selectors(_ subscriber: NSObject) -> [Bool] {
        return [
            subscriber.responds(to: #selector(UIApplicationDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:))),
            subscriber.responds(to: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))),
            subscriber.responds(to: #selector(UIApplicationDelegate.application(_:continue:restorationHandler:))),
            subscriber.responds(to: #selector(UIApplicationDelegate.application(_:performActionFor:completionHandler:))),
            subscriber.responds(to: #selector(UIApplicationDelegate.application(_:performFetchWithCompletionHandler:))),
        ]
    }

    static func forward(_ subscriber: any Subscriber, _ application: UIApplication, _ url: URL, _ options: [UIApplication.OpenURLOptionsKey: Any], _ activity: NSUserActivity, _ shortcut: UIApplicationShortcutItem, _ error: Error) -> Bool {
        subscriber.application?(application, performActionFor: shortcut, completionHandler: { _ in })
        subscriber.application?(application, didUpdate: activity)
        subscriber.application?(application, didFailToContinueUserActivityWithType: "", error: error)
        _ = subscriber.application?(application, willContinueUserActivityWithType: "")
        _ = subscriber.application?(application, continue: activity, restorationHandler: { _ in })
        subscriber.application?(application, handleEventsForBackgroundURLSession: "", completionHandler: {})
        subscriber.application?(application, didReceiveRemoteNotification: [:], fetchCompletionHandler: { _ in })
        subscriber.application?(application, performFetchWithCompletionHandler: { _ in })
        return subscriber.application?(application, open: url, options: options) ?? false
    }
}
