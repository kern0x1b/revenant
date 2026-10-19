import UIKit

public protocol Commands {
    associatedtype Body: Commands
    @CommandsBuilder var body: Body { get }
}

extension Never: Commands {}

public struct EmptyCommands: Commands {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init() {}
}

public struct CommandMenu<Content: View>: Commands {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init(_ name: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ name: S, @ViewBuilder content: () -> Content) {}
}

public struct CommandGroupPlacement {
    public static let appInfo = CommandGroupPlacement()
    public static let appSettings = CommandGroupPlacement()
    public static let systemServices = CommandGroupPlacement()
    public static let appVisibility = CommandGroupPlacement()
    public static let appTermination = CommandGroupPlacement()
    public static let newItem = CommandGroupPlacement()
    public static let saveItem = CommandGroupPlacement()
    public static let importExport = CommandGroupPlacement()
    public static let printItem = CommandGroupPlacement()
    public static let undoRedo = CommandGroupPlacement()
    public static let pasteboard = CommandGroupPlacement()
    public static let textEditing = CommandGroupPlacement()
    public static let textFormatting = CommandGroupPlacement()
    public static let toolbar = CommandGroupPlacement()
    public static let sidebar = CommandGroupPlacement()
    public static let windowSize = CommandGroupPlacement()
    public static let windowArrangement = CommandGroupPlacement()
    public static let help = CommandGroupPlacement()
}

public struct CommandGroup<Content: View>: Commands {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init(before group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
    public init(after group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
    public init(replacing group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
}

public struct SidebarCommands: Commands { public typealias Body = Never; public var body: Never { neverBody(Self.self) }; public init() {} }
public struct ToolbarCommands: Commands { public typealias Body = Never; public var body: Never { neverBody(Self.self) }; public init() {} }
public struct TextEditingCommands: Commands { public typealias Body = Never; public var body: Never { neverBody(Self.self) }; public init() {} }
public struct TextFormattingCommands: Commands { public typealias Body = Never; public var body: Never { neverBody(Self.self) }; public init() {} }
public struct ImportFromDevicesCommands: Commands { public typealias Body = Never; public var body: Never { neverBody(Self.self) }; public init() {} }

public struct _TupleCommands<T>: Commands {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let value: T
}

@resultBuilder
public struct CommandsBuilder {
    public static func buildBlock() -> EmptyCommands { EmptyCommands() }
    public static func buildBlock<C: Commands>(_ content: C) -> C { content }
    public static func buildBlock<each C: Commands>(_ content: repeat each C) -> _TupleCommands<(repeat each C)> { _TupleCommands(value: (repeat each content)) }
}

public struct _CommandsScene<Base: Scene>: Scene {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let base: Base
}

extension _CommandsScene: SceneWrapper { var wrappedScene: any Scene { base } }

protocol SceneWrapper { var wrappedScene: any Scene { get } }

extension Scene {
    public func commands<Content: Commands>(@CommandsBuilder content: () -> Content) -> some Scene {
        _Unsupported.note("commands", "iOS 6 has no menu bar and no keyboard commands")
        return _CommandsScene(base: self)
    }
}
