import UIKit
import CoreGraphics

// MARK: - the one window a scene has

/// A window of an app, as a scene. Apple declares it for macOS only - the four annotations on the type
/// are `@available(macOS 13.0, *)`, `@available(iOS, unavailable)`, `@available(tvOS, unavailable)` and
/// `@available(watchOS, unavailable)` (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:2740-2743`) -
/// and this port carries it because a scene is what the engine's root is, over the one `UIWindow` iOS 6
/// has. The initialisers are Apple's, one for a `Text`, one for a `LocalizedStringKey` and one disfavoured
/// for anything `StringProtocol`.
public struct Window<Content>: Scene where Content: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }

    /// The id the window is known by, and the content it holds.
    public let id: String
    public let content: () -> Content

    public init(_ title: Text, id: String, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
    }

    public init(_ titleKey: LocalizedStringKey, id: String, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
    }

    @_disfavoredOverload
    public init<S>(_ title: S, id: String, @ViewBuilder content: @escaping () -> Content) where S: StringProtocol {
        self.id = id
        self.content = content
    }

    /// The window this scene is over: the one the release has, which is the only one there is on iOS 6.
    @_spi(Probe) public func presentedWindowContent(forPresented presented: Bool) -> PresentedWindowContent<Data?, Content>? {
        OpenWindowAction.currentWindowID = id
        _Unsupported.note("Window.presentedWindowContent(forPresented:)",
                          "iOS 6 has one UIWindow, so a window scene is that window and a presented one is the same content")
        return PresentedWindowContent(data: nil, content: content)
    }
}

// MARK: - the action that opens one

/// Opens a window by its id, with a value. Apple declares it for iOS 16 and up and not at all for tvOS or
/// watchOS (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:8191-8197`), and marks no member of it
/// unavailable on iOS - while the `Window` scene it opens is macOS-only on the same file. That pair is
/// what this port answers from: iOS has the action and one window, so opening the id that is not the
/// current one has nothing to open, and the action says so in the journal.
public struct OpenWindowAction {
    public init() {}

    /// Opens the window with this value, which is the one its `presentedWindowContent` is given.
    public func callAsFunction<D>(value: D) where D: Codable & Hashable {
        _Unsupported.note("OpenWindowAction(value:)", "iOS 6 has one window and passes no value to it")
    }

    /// Opens the window with this id. The id of the window the scene is over is the one already shown,
    /// and that is the only window there is, so any other id has nothing to open.
    public func callAsFunction(id: String) {
        guard id != OpenWindowAction.currentWindowID else { return }
        _Unsupported.note("OpenWindowAction(id:)", "iOS 6 has one UIWindow and no second window to open")
    }

    /// The id of the window the engine is showing, which a window scene registers and the action reads.
    @_spi(Probe) public static var currentWindowID: String?

    public func callAsFunction<D>(id: String, value: D) where D: Codable & Hashable {
        callAsFunction(id: id)
    }

    /// The action itself, as the `openWindow` of a window scene reads it.
    public var openWindow: OpenWindowAction { OpenWindowAction() }
}

// MARK: - the content a presented window holds

/// The content a presented window shows, with the value the caller opened it with. Apple's shape from
/// the SDK of 16.4 (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:264`): `Data: Decodable &
/// Encodable & Hashable`, `Content: View`, and a body of `Never` - it is a view the window hosts, not one
/// it draws.
public struct PresentedWindowContent<Data, Content>: View where Data: Codable & Hashable, Content: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }

    /// The value the window was opened with, nil for one opened without one.
    public let data: Data?
    /// The content the window's scene builds.
    public let content: () -> Content

    public init(data: Data?, @ViewBuilder content: @escaping () -> Content) {
        self.data = data
        self.content = content
    }
}
