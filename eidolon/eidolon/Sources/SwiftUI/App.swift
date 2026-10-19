import UIKit
import CoreGraphics

public protocol Scene {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
}

extension Never: Scene {}

@resultBuilder
public struct SceneBuilder {
    public static func buildBlock<Content: Scene>(_ content: Content) -> Content { content }
}

public struct WindowGroup<Content: View>: Scene {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
}

protocol WindowGroupLike { var rootContent: any View { get } }
extension WindowGroup: WindowGroupLike { var rootContent: any View { content } }

public protocol App {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
    init()
}

enum AppRuntime {
    nonisolated(unsafe) static var scenePhase = ScenePhase.active
    nonisolated(unsafe) static var makeRoot: (() -> any View)?

    static func enter(_ phase: ScenePhase) {
        guard phase != scenePhase else { return }
        scenePhase = phase
        for weak in Updates.hosts { weak.host?.rebuild() }
    }
    nonisolated(unsafe) static var customDelegate: (NSObject & UIApplicationDelegate)?
}

func sceneRoot(_ scene: any Scene) -> any View {
    if let w = scene as? WindowGroupLike { return w.rootContent }
    if let wrapper = scene as? SceneWrapper { return sceneRoot(wrapper.wrappedScene) }
    return sceneRoot(sceneBody(scene))
}

func sceneBody<S: Scene>(_ scene: S) -> any Scene { scene.body }

extension App {
    public static func main() {
        AppRuntime.makeRoot = { sceneRoot(Self().body) }
        _ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, "RevSwiftUIAppDelegate")
    }
}

@objc(RevSwiftUIAppDelegate)
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = AppRuntime.customDelegate?.application?(application, didFinishLaunchingWithOptions: launchOptions)
        let window = UIWindow(frame: UIScreen.main.bounds)
        let root = AppRuntime.makeRoot?() ?? EmptyView()
        window.rootViewController = _HostingViewController(rootView: root)
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        AppRuntime.customDelegate?.applicationWillResignActive?(application)
        AppRuntime.enter(.inactive)
    }
    func applicationDidEnterBackground(_ application: UIApplication) {
        AppRuntime.customDelegate?.applicationDidEnterBackground?(application)
        AppRuntime.enter(.background)
    }
    func applicationWillEnterForeground(_ application: UIApplication) {
        AppRuntime.customDelegate?.applicationWillEnterForeground?(application)
        AppRuntime.enter(.inactive)
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        AppRuntime.customDelegate?.applicationDidBecomeActive?(application)
        AppRuntime.enter(.active)
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        let custom = AppRuntime.customDelegate?.application?(application, open: url, sourceApplication: sourceApplication, annotation: annotation) ?? false
        return OpenURLHandlers.deliver(url) || custom
    }
}
