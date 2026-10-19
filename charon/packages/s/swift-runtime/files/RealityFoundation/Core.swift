import simd
import CoreMedia
import Foundation

public final class __REComponentType {
    public let componentType: Any.Type
    public let identifier: ObjectIdentifier
    public let name: String
    public let size: Int

    fileprivate static func simpleName(of componentType: Any.Type) -> String {
        let reflected = String(reflecting: componentType)
        guard let dot = reflected.lastIndex(of: ".") else { return reflected }
        return String(reflected[reflected.index(after: dot)...])
    }

    fileprivate init(_ componentType: Any.Type, size: Int) {
        self.componentType = componentType
        self.identifier = ObjectIdentifier(componentType)
        self.name = __REComponentType.simpleName(of: componentType)
        self.size = size
    }
}

public final class __REComponentRegistry {
    public static let shared = __REComponentRegistry()

    private var registered: [ObjectIdentifier: __REComponentType] = [:]
    private var counter: UInt64 = 0
    private var synchronizationCounter: UInt64 = 0
    private let lock = NSLock()

    public init() {}

    public func registration(of componentType: Any.Type, size: Int) -> __REComponentType {
        let key = ObjectIdentifier(componentType)
        lock.lock()
        defer { lock.unlock() }
        if let known = registered[key] {
            return known
        }
        let made = __REComponentType(componentType, size: size)
        registered[key] = made
        return made
    }

    public func isRegistered(_ componentType: Any.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return registered[ObjectIdentifier(componentType)] != nil
    }

    public func nextEntityIdentifier() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return counter
    }

    public func nextSynchronizationIdentifier() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        synchronizationCounter += 1
        return synchronizationCounter
    }
}

public final class __REComponentBox {
    public var value: Any
    fileprivate init(_ value: Any) { self.value = value }
}

public struct __ComponentRef {
    @usableFromInline let box: __REComponentBox

    @usableFromInline init(_ box: __REComponentBox) { self.box = box }

    public static func __fromCore(_ core: Any) -> __ComponentRef {
        if let box = core as? __REComponentBox { return __ComponentRef(box) }
        return __ComponentRef(__REComponentBox(core))
    }

    public nonisolated func __as<T>(_ type: T.Type) -> T { box.value as! T }

    public nonisolated func __write<T>(_ component: T) { box.value = component }
}

public struct __ComponentTypeRef {
    @usableFromInline let type: __REComponentType

    @usableFromInline init(_ type: __REComponentType) { self.type = type }

    public static func __fromCore(_ core: Any) -> __ComponentTypeRef {
        __ComponentTypeRef(core as! __REComponentType)
    }

    public func __as<T>(_ type: T.Type) -> T { self.type as! T }

    @usableFromInline var registration: __REComponentType { type }
}

public struct __SRTRef {
    @usableFromInline var scale: SIMD3<Float>
    @usableFromInline var rotation: simd_quatf
    @usableFromInline var translation: SIMD3<Float>

    @usableFromInline init(scale: SIMD3<Float>, rotation: simd_quatf, translation: SIMD3<Float>) {
        self.scale = scale
        self.rotation = rotation
        self.translation = translation
    }

    public static func __fromCore(_ core: Any) -> __SRTRef {
        if let srt = core as? __SRTRef { return srt }
        if let transform = core as? Transform { return __SRTRef(scale: transform.scale, rotation: transform.rotation, translation: transform.translation) }
        preconditionFailure("RealityFoundation: __SRTRef.__fromCore was given \(type(of: core)), which is not a transform")
    }

    public func __as<T>(_ type: T.Type) -> T {
        if T.self == __SRTRef.self { return self as! T }
        return Transform(scale: scale, rotation: rotation, translation: translation) as! T
    }
}

public struct __AABBRef {
    @usableFromInline var min: SIMD3<Float>
    @usableFromInline var max: SIMD3<Float>

    @usableFromInline init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }

    public static func __fromCore(_ core: Any) -> __AABBRef {
        if let box = core as? __AABBRef { return box }
        preconditionFailure("RealityFoundation: __AABBRef.__fromCore was given \(type(of: core)), which is not a bounding box")
    }

    public func __as<T>(_ type: T.Type) -> T {
        if T.self == __AABBRef.self { return self as! T }
        return BoundingBox(min: min, max: max) as! T
    }

    @usableFromInline var corners: [SIMD3<Float>] {
        [SIMD3<Float>(min.x, min.y, min.z), SIMD3<Float>(max.x, min.y, min.z),
         SIMD3<Float>(min.x, max.y, min.z), SIMD3<Float>(max.x, max.y, min.z),
         SIMD3<Float>(min.x, min.y, max.z), SIMD3<Float>(max.x, min.y, max.z),
         SIMD3<Float>(min.x, max.y, max.z), SIMD3<Float>(max.x, max.y, max.z)]
    }
}

@MainActor public final class __REEntity {
    public let identifier: UInt64
    public var name: String
    public var transform: Transform
    var components: [(key: ObjectIdentifier, value: Any)] = []
    public var children: [__REEntity] = []
    public weak var parent: __REEntity?
    public var scene: __REScene?
    public var isEnabled: Bool = true
    public var tracked: Bool?
    public var animations: [UInt64: AnimationPlaybackController] = [:]
    public var wrapper: Entity?

    public init(name: String = "") {
        self.identifier = __REComponentRegistry.shared.nextEntityIdentifier()
        self.name = name
        self.transform = Transform()
        self.setComponent(Transform())
        self.setComponent(SynchronizationComponent())
    }

    public var entity: Entity {
        if let wrapper { return wrapper }
        let made = Entity(_coreEntity: __EntityRef(self))
        wrapper = made
        return made
    }

    func registration(of componentType: Any.Type) -> __REComponentType {
        __REComponentRegistry.shared.registration(of: componentType, size: __reComponentSize(of: componentType))
    }

    func component<T>(of componentType: T.Type) -> T? where T: Component {
        if componentType == Transform.self { return transform as! T }
        return stored(of: componentType) as? T
    }

    func setComponent<T>(_ component: T) where T: Component {
        setComponentAny(component)
    }

    func setComponentAny(_ component: any Component) {
        let key = registration(of: Swift.type(of: component)).identifier
        if let at = components.firstIndex(where: { $0.key == key }) {
            components[at] = (key, component)
        } else {
            components.append((key, component))
        }
        if let transform = component as? Transform { self.transform = transform }
    }

    func putComponent(_ component: Any) {
        let key = registration(of: Swift.type(of: component)).identifier
        if let at = components.firstIndex(where: { $0.key == key }) {
            components[at] = (key, component)
        } else {
            components.append((key, component))
        }
    }

    func stored(of componentType: Any.Type) -> Any? {
        let key = registration(of: componentType).identifier
        return components.first { $0.key == key }?.value
    }

    func removeComponent(of componentType: Any.Type) {
        let key = registration(of: componentType).identifier
        components.removeAll { $0.key == key }
    }

    func removeAllComponents() {
        components.removeAll()
        transform = Transform()
    }

    func hasComponent(of componentType: Any.Type) -> Bool {
        stored(of: componentType) != nil
    }

    var componentCount: Int { components.count }

    var root: __REEntity {
        var node = self
        while let parent = node.parent { node = parent }
        return node
    }

    var sceneOfRoot: __REScene? { root.scene }

    var isEnabledInHierarchy: Bool {
        var node: __REEntity? = self
        while let current = node {
            if !current.isEnabled { return false }
            node = current.parent
        }
        return true
    }

    var isActive: Bool { sceneOfRoot != nil && isEnabledInHierarchy }

    var isAnchored: Bool {
        var node: __REEntity? = self
        while let current = node {
            if let scene = current.scene, scene.anchors.contains(where: { $0 === current }) { return true }
            node = current.parent
        }
        return false
    }

    func adopt(_ child: __REEntity, preservingWorldTransform: Bool) {
        let world = child.transformMatrixInHierarchy
        child.detach(preservingWorldTransform: false)
        if preservingWorldTransform {
            let top = self.root
            child.transform = Transform(matrix: top.transformMatrixInHierarchy.inverted * world)
        }
        child.parent = self
        children.append(child)
    }

    func detach(preservingWorldTransform: Bool) {
        guard let parent else { return }
        let world = transformMatrixInHierarchy
        if preservingWorldTransform {
            let top = parent.root
            transform = Transform(matrix: top.transformMatrixInHierarchy * world)
        }
        parent.children.removeAll { $0 === self }
        self.parent = nil
    }

    public var transformMatrixInHierarchy: float4x4 {
        var matrix = transform.matrix
        var node = parent
        while let current = node {
            matrix = current.transform.matrix * matrix
            node = current.parent
        }
        return matrix
    }

    public func transformMatrix(relativeTo reference: __REEntity?) -> float4x4 {
        let mine = transformMatrixInHierarchy
        guard let reference, reference !== self else { return mine }
        return reference.transformMatrixInHierarchy.inverted * mine
    }

    public var transformComponent: Transform { transform }

    public func setTransformComponent(_ value: Transform) { transform = value }

    public func boundingBox(recursive: Bool, excludeInactive: Bool) -> BoundingBox {
        var box = BoundingBox()
        if excludeInactive && !isActive { return box }
        for corner in BoundingBox(min: -.one * 0.5, max: .one * 0.5).corners {
            let placed = transform.matrix * SIMD4<Float>(corner, 1)
            box.extend(with: SIMD3<Float>(placed.x, placed.y, placed.z))
        }
        guard recursive else { return box }
        for child in children {
            for corner in child.boundingBox(recursive: true, excludeInactive: excludeInactive).corners {
                let placed = transform.matrix * SIMD4<Float>(corner, 1)
                box.extend(with: SIMD3<Float>(placed.x, placed.y, placed.z))
            }
        }
        return box
    }

    public func visualBounds(recursive: Bool, reference: __REEntity?, excludeInactive: Bool) -> BoundingBox {
        let box = boundingBox(recursive: recursive, excludeInactive: excludeInactive)
        guard let reference, reference !== self else { return box }
        let toReference = reference.transformMatrixInHierarchy.inverted * transformMatrixInHierarchy
        var moved = BoundingBox(min: box.min, max: box.max)
        for corner in box.corners {
            let world = toReference * SIMD4<Float>(corner, 1)
            moved.extend(with: SIMD3<Float>(world.x, world.y, world.z))
        }
        return moved
    }

    public var subtree: [__REEntity] {
        [self] + children.flatMap { $0.subtree }
    }

    public func firstNode(named name: String) -> __REEntity? {
        subtree.first { $0.name == name }
    }

    public func debugDescription(typeName: String) -> String {
        debugDescription(typeName: typeName, indent: 0)
    }

    public func debugDescription(typeName: String, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        let inner = pad + "  "
        var lines = ["\(pad)▿ '\(name)' : \(typeName)\(children.isEmpty ? "" : ", children: \(children.count)")"]
        for name in components.map({ String(reflecting: type(of: $0.value)).components(separatedBy: ".").last ?? "" }) {
            lines.append("\(inner)⟐ \(name)")
        }
        for child in children {
            lines.append(child.debugDescription(typeName: typeName, indent: indent + 2))
        }
        return lines.joined(separator: "\n")
    }
}

private func __reComponentSize(of componentType: Any.Type) -> Int {
    guard let metatype = componentType as? any Component.Type else { return 0 }
    return metatype.__size
}

public struct __EntityRef: Equatable {
    @usableFromInline let node: __REEntity

    @usableFromInline init(_ node: __REEntity) { self.node = node }

    @MainActor public static func __fromCore(_ core: Any) -> __EntityRef {
        if let node = core as? __REEntity { return __EntityRef(node) }
        if let entity = core as? Entity { return __EntityRef(entity.__coreEntity.node) }
        preconditionFailure("RealityFoundation: __EntityRef.__fromCore was given \(type(of: core)), which is not an entity")
    }

    @MainActor public func __as<T>(_ type: T.Type) -> T {
        if T.self == __REEntity.self { return node as! T }
        return node.entity as! T
    }

    public static func == (a: __EntityRef, b: __EntityRef) -> Bool { a.node === b.node }
}

@MainActor public final class __REScene {
    public let identifier: UInt64
    public var name: String
    public var anchors: [__REEntity] = []
    public var synchronizationService: Any?
    public var timebase: CMTimebase?
    public var wrapper: Scene?
    public var collisions: Set<String>?
    private var counter: UInt64 = 0
    private let lock = NSLock()

    static var _sharedTimebase: CMTimebase?
    static func sharedTimebase() -> CMTimebase {
        if let made = _sharedTimebase { return made }
        var timebase: CMTimebase?
        precondition(CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault,
                                                     masterClock: CMClockGetHostTimeClock(),
                                                     timebaseOut: &timebase) == noErr && timebase != nil,
                     "CoreMedia could not allocate a timebase, and a scene whose time has nowhere to read it from is not usable")
        _sharedTimebase = timebase
        return timebase!
    }

    public init(name: String) {
        self.identifier = __REComponentRegistry.shared.nextEntityIdentifier()
        self.name = name
    }

    public func anchor(at index: Int) -> AnchorEntity {
        let node = anchors[index]
        if let made = node.wrapper as? AnchorEntity { return made }
        let made = AnchorEntity(_coreEntity: __EntityRef(node))
        node.wrapper = made
        return made
    }

    public func add(anchor: __REEntity) {
        if let index = anchors.firstIndex(where: { $0 === anchor }) { anchors.remove(at: index) }
        anchors.append(anchor)
        anchor.scene = self
    }

    public func remove(anchor: __REEntity) {
        anchors.removeAll { $0 === anchor }
        if anchor.scene === self { anchor.scene = nil }
    }

    public func nextEventIdentifier() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return counter
    }

    public var nodes: [__REEntity] { anchors.flatMap { $0.subtree } }

    public func firstNode(named name: String) -> __REEntity? {
        for anchor in anchors {
            if let found = anchor.firstNode(named: name) { return found }
        }
        return nil
    }

    public func node(withIdentifier identifier: UInt64) -> __REEntity? {
        (anchors + anchors.flatMap { $0.subtree.dropFirst() }).first { $0.identifier == identifier }
    }

    public var entity: Scene {
        if let wrapper { return wrapper }
        let made = Scene(_coreScene: __SceneRef(self))
        wrapper = made
        return made
    }
}

public struct __SceneRef {
    @usableFromInline let scene: __REScene

    @usableFromInline init(_ scene: __REScene) { self.scene = scene }

    @MainActor public static func __fromCore(_ core: Any) -> __SceneRef {
        if let scene = core as? __REScene { return __SceneRef(scene) }
        if let value = core as? Scene { return __SceneRef(value.__coreScene.scene) }
        preconditionFailure("RealityFoundation: __SceneRef.__fromCore was given \(type(of: core)), which is not a scene")
    }

    @MainActor public func __as<T>(_ type: T.Type) -> T {
        if T.self == __REScene.self { return scene as! T }
        return scene.entity as! T
    }
}

@inline(__always)
public func __reInverse(_ matrix: float4x4) -> float4x4 {
    var rows: [(SIMD4<Float>, SIMD4<Float>)] = []
    for row in 0..<4 {
        let line = __reRow(matrix, row)
        let identity = SIMD4<Float>(row == 0 ? 1 : 0, row == 1 ? 1 : 0, row == 2 ? 1 : 0, row == 3 ? 1 : 0)
        rows.append((line, identity))
    }
    for column in 0..<4 {
        var pivot = column
        for candidate in (column + 1)..<4 where abs(rows[candidate].0[column]) > abs(rows[pivot].0[column]) {
            pivot = candidate
        }
        guard abs(rows[pivot].0[column]) > 0 else {
            let infinite = SIMD4<Float>(repeating: .infinity)
            return float4x4(infinite, infinite, infinite, infinite)
        }
        if pivot != column { rows.swapAt(pivot, column) }
        let scale: Float = 1 / rows[column].0[column]
        rows[column].0 *= scale
        rows[column].1 *= scale
        for other in 0..<4 where other != column {
            let factor = rows[other].0[column]
            guard factor != 0 else { continue }
            rows[other].0 -= rows[column].0 * factor
            rows[other].1 -= rows[column].1 * factor
        }
    }
    return float4x4(__reColumn(rows, 0), __reColumn(rows, 1), __reColumn(rows, 2), __reColumn(rows, 3))
}

@inline(__always)
private func __reRow(_ matrix: float4x4, _ row: Int) -> SIMD4<Float> {
    SIMD4<Float>(matrix.columns.0[row], matrix.columns.1[row], matrix.columns.2[row], matrix.columns.3[row])
}

@inline(__always)
private func __reColumn(_ rows: [(SIMD4<Float>, SIMD4<Float>)], _ column: Int) -> SIMD4<Float> {
    SIMD4<Float>(rows[0].1[column], rows[1].1[column], rows[2].1[column], rows[3].1[column])
}

@inline(__always)
internal func __reApply(_ matrix: float4x4, _ vector: SIMD3<Float>, asPoint: Bool) -> SIMD3<Float> {
    let moved = matrix * SIMD4<Float>(vector, asPoint ? 1 : 0)
    return SIMD3<Float>(moved.x, moved.y, moved.z)
}

extension float4x4 {
    @inline(__always)
    public var inverted: float4x4 { __reInverse(self) }
}
