import UIKit
import CoreGraphics

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

extension EnvironmentValues {
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { (values[ObjectIdentifier(key)] as? K.Value) ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }
}

@propertyWrapper
public struct Environment<Value>: DynamicProperty, DynamicPropertyInstaller {
    let read: (EnvironmentValues) -> Value
    var resolved: Value?
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) { read = { $0[keyPath: keyPath] } }
    init(read: @escaping (EnvironmentValues) -> Value) { self.read = read }
    public var wrappedValue: Value {
        if let resolved { return resolved }
        return read(EnvironmentValues())
    }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: Environment<Value>.self)
        p.pointee.resolved = p.pointee.read(node.env)
    }
}

public struct PresentationMode {
    let dismissAction: () -> Void
    public private(set) var isPresented: Bool
    public mutating func dismiss() { dismissAction() }
}

struct PresentationModeKey: EnvironmentKey {
    static var defaultValue: Binding<PresentationMode> {
        Binding(get: { PresentationMode(dismissAction: {}, isPresented: false) }, set: { _ in })
    }
}

extension EnvironmentValues {
    public var presentationMode: Binding<PresentationMode> {
        get { self[PresentationModeKey.self] }
        set { self[PresentationModeKey.self] = newValue }
    }
}

extension EnvironmentValues {
    public var font: Font? {
        get { fontValue.map { Font(uiFont: $0) } }
        set { fontValue = newValue?.uiFont }
    }
    public var multilineTextAlignment: TextAlignment {
        get {
            switch textAlignment {
            case .right: return .trailing
            case .center: return .center
            default: return .leading
            }
        }
        set {
            switch newValue {
            case .leading: textAlignment = .left
            case .center: textAlignment = .center
            case .trailing: textAlignment = .right
            }
        }
    }
    public var redactionReasons: RedactionReasons {
        get { self[RedactionKey.self] }
        set { self[RedactionKey.self] = newValue }
    }
    public var isSearching: Bool {
        get { self[IsSearchingKey.self] }
        set { self[IsSearchingKey.self] = newValue }
    }
}

struct RedactionKey: EnvironmentKey { static var defaultValue: RedactionReasons { RedactionReasons(rawValue: 0) } }
struct IsSearchingKey: EnvironmentKey { static var defaultValue: Bool { false } }

extension View {
    public func environment<Value>(_ keyPath: WritableKeyPath<EnvironmentValues, Value>, _ value: Value) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0[keyPath: keyPath] = value }, onUpdate: nil))
    }
}
