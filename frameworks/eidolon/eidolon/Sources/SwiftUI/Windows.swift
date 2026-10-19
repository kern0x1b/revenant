import UIKit
import CoreGraphics

public struct Window<Content>: Scene where Content: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }

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

    @_spi(Probe) public func presentedWindowContent(forPresented presented: Bool) -> PresentedWindowContent<Data?, Content>? {
        OpenWindowAction.currentWindowID = id
        _Unsupported.note("Window.presentedWindowContent(forPresented:)",
                          "iOS 6 has one UIWindow, so a window scene is that window and a presented one is the same content")
        return PresentedWindowContent(data: nil, content: content)
    }
}

public struct OpenWindowAction {
    public init() {}

    public func callAsFunction<D>(value: D) where D: Codable & Hashable {
        _Unsupported.note("OpenWindowAction(value:)", "iOS 6 has one window and passes no value to it")
    }

    public func callAsFunction(id: String) {
        guard id != OpenWindowAction.currentWindowID else { return }
        _Unsupported.note("OpenWindowAction(id:)", "iOS 6 has one UIWindow and no second window to open")
    }

    @_spi(Probe) public static var currentWindowID: String?

    public func callAsFunction<D>(id: String, value: D) where D: Codable & Hashable {
        callAsFunction(id: id)
    }

    public var openWindow: OpenWindowAction { OpenWindowAction() }
}

public struct PresentedWindowContent<Data, Content>: View where Data: Codable & Hashable, Content: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }

    public let data: Data?
    public let content: () -> Content

    public init(data: Data?, @ViewBuilder content: @escaping () -> Content) {
        self.data = data
        self.content = content
    }
}
