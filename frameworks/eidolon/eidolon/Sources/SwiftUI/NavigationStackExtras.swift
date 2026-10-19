import UIKit
import CoreGraphics

public struct NavigationPath: Equatable {
    /// How the path's elements are written down and read back. Only a path that was given a
    /// representation can be encoded, and one without says so by having none.
    public struct CodableRepresentation: Codable, Equatable {
        var items: [AnyHashable] = []
        var read: ((any Decoder) throws -> [AnyHashable])?
        var write: (([AnyHashable], any Encoder) throws -> Void)?
        public init() { read = nil; write = nil }
        public init(read: @escaping (any Decoder) throws -> [AnyHashable], write: @escaping ([AnyHashable], any Encoder) throws -> Void) {
            self.read = read; self.write = write
        }
        public init(from decoder: any Decoder) throws {
            guard let read else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                         debugDescription: "no representation to read the path with"))
            }
            items = try read(decoder)
        }
        public func encode(to encoder: any Encoder) throws {
            guard let write else {
                throw EncodingError.invalidValue(items, .init(codingPath: encoder.codingPath,
                                                              debugDescription: "no representation to write the path with"))
            }
            try write(items, encoder)
        }
        public static func == (lhs: CodableRepresentation, rhs: CodableRepresentation) -> Bool {
            (lhs.read == nil) == (rhs.read == nil) && (lhs.write == nil) == (rhs.write == nil)
        }
    }

    var items: [AnyHashable] = []
    var representation: CodableRepresentation?
    public init() {}
    public init<S: Sequence>(_ elements: S) where S.Element: Hashable {
        items = elements.map { AnyHashable($0) }
    }
    public init(_ codable: CodableRepresentation) { representation = codable }
    public var codable: CodableRepresentation? { representation }
    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }
    public mutating func append<V: Hashable>(_ value: V) { items.append(AnyHashable(value)) }
    public mutating func removeLast(_ k: Int = 1) { items.removeLast(min(k, items.count)) }
    public static func == (lhs: NavigationPath, rhs: NavigationPath) -> Bool {
        lhs.items == rhs.items && lhs.representation == rhs.representation
    }

    public init(from decoder: any Decoder) throws {
        guard let representation else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                     debugDescription: "a path with no codable representation"))
        }
        let decoded = try CodableRepresentation(from: decoder)
        items = decoded.items
        self.representation = representation
    }
    public func encode(to encoder: any Encoder) throws {
        guard let representation else {
            throw EncodingError.invalidValue(items, .init(codingPath: encoder.codingPath,
                                                          debugDescription: "a path with no codable representation"))
        }
        var box = representation
        box.items = items
        try box.encode(to: encoder)
    }
}

struct NavigationDestinationModifier: NodeModifier {
    let type: ObjectIdentifier
    let build: (AnyHashable) -> any View
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { NavigationDestinationNode() }
}

final class NavigationDestinationNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! NavigationDestinationModifier
        var inner = env
        inner.destinations[modifier.type] = modifier.build
        env.stackState?.builders[modifier.type] = modifier.build
        child = adopt(reconcile(child, m.modifiedContent, inner))
    }

    override func mountContents() { child?.mount() }
}

extension View {
    public func navigationDestination<D: Hashable, C: View>(for type: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View {
        _ModifiedView(content: self, modifier: NavigationDestinationModifier(
            type: ObjectIdentifier(type),
            build: { value in
                guard let typed = value.base as? D else { return AnyView(EmptyView()) }
                return destination(typed)
            }))
    }
}

extension NavigationLink where Label: View {
    public init<D: Hashable>(value: D?, @ViewBuilder label: () -> Label) where Destination == _ValueDestination {
        self.init(destination: _ValueDestination(value: value.map { AnyHashable($0) }), label: label)
    }
}

extension NavigationLink where Label == Text, Destination == _ValueDestination {
    public init<D: Hashable>(_ titleKey: LocalizedStringKey, value: D?) {
        self.init(destination: _ValueDestination(value: value.map { AnyHashable($0) })) { Text(titleKey) }
    }
}

public struct _ValueDestination: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let value: AnyHashable?
    var childViews: [any View] { [] }
}

public struct ColorPicker<Label: View>: View {
    let selection: Binding<Color>
    let label: Label

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                label
                Spacer()
                Rectangle().fill(selection.wrappedValue).frame(width: 40, height: 22)
            }
            channel("R", index: 0)
            channel("G", index: 1)
            channel("B", index: 2)
        }
    }

    func channel(_ name: String, index: Int) -> some View {
        HStack(spacing: 6) {
            Text(name)
            Slider(value: Binding(
                get: { Double(components(selection.wrappedValue)[index]) },
                set: { newValue in
                    var parts = components(selection.wrappedValue)
                    parts[index] = CGFloat(newValue)
                    selection.wrappedValue = Color(UIColor(red: parts[0], green: parts[1], blue: parts[2], alpha: 1))
                }))
        }
    }

    func components(_ color: Color) -> [CGFloat] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue]
    }
}

extension ColorPicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.init(selection: selection, label: Text(titleKey))
    }
}

extension Image {
    public init(uiImage: UIImage) {
        self.init("")
        stored = uiImage
    }
}

extension View {
    @available(iOS 8.0, *)
    public func onDrag(_ data: @escaping () -> NSItemProvider) -> some View {
        ignored(self, "onDrag", "a drag of this release is a gesture, not a session: UIDragInteraction and UIDropInteraction are iOS 11, and the release hands an app no drag session and no preview to carry a payload in — a table of rows is moved with .onMove, and a drag of one's own is a DragGesture")
    }
    @available(iOS 8.0, *)
    public func onDrop(of types: [String], isTargeted: Binding<Bool>?, perform: @escaping ([NSItemProvider]) -> Bool) -> some View {
        ignored(self, "onDrop", "a drag of this release is a gesture, not a session: UIDragInteraction and UIDropInteraction are iOS 11, and the release hands an app no drag session and no preview to carry a payload in — a table of rows is moved with .onMove, and a drag of one's own is a DragGesture")
    }
}
