// The storage an entity's state lives in, and the references the SDK's headers name.
//
// The SDK's RealityFoundation is a Swift overlay over a C++ engine: Entity, Scene and the
// components are thin wrappers over a reference into it (__EntityRef, __SceneRef,
// __ComponentRef, __ComponentTypeRef, __SRTRef, __AABBRef), and every question about state
// goes through that reference. This port has no such engine, so the reference *is* the state:
// __REEntity is the scene-graph node, and the references are the handles onto it. The API is
// the SDK's, the layout behind it is ours, and every member below answers from this storage
// rather than from a constant.
//
// No availability attributes: this module is built for the port's release only, and its whole
// surface is what that release carries. The marks come down in the sources, the way the
// Foundation overlay's do in packages/s/swift-runtime/patches/overlays.

import simd
import CoreMedia
import Foundation

// MARK: - The component registration

/// What a component type contributes to the engine: its size, its name, and whether it has
/// been registered with `registerComponent()`.
public final class __REComponentType {
    public let componentType: Any.Type
    public let identifier: ObjectIdentifier
    /// The name `componentName` answers, and the one the introspection data of the type carries.
    public let name: String
    public let size: Int

    /// The name a component type is known by, without the module it is declared in: what a
    /// serialized scene calls it, and what `componentName` answers.
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

/// The component types this program has registered, and the identifier each new entity takes.
public final class __REComponentRegistry {
    public static let shared = __REComponentRegistry()

    private var registered: [ObjectIdentifier: __REComponentType] = [:]
    private var counter: UInt64 = 0
    private var synchronizationCounter: UInt64 = 0
    private let lock = NSLock()

    public init() {}

    /// The registration of `componentType`, made on the first use of the type. A type that
    /// called `registerComponent()` is in the table already; one that did not is added, so
    /// that `componentName` and the introspection data of every type in the program answer.
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

    /// Whether `componentType` called `registerComponent()`.
    public func isRegistered(_ componentType: Any.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return registered[ObjectIdentifier(componentType)] != nil
    }

    /// The next entity identifier. Entities are numbered from one in the order they are made,
    /// and an identifier is never reused, so `Entity.ID` is unique for the life of the process.
    public func nextEntityIdentifier() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return counter
    }

    /// The number a new `SynchronizationComponent` takes. It is not an entity's identifier: a
    /// session agrees on one number for the entity across devices, and every component a
    /// program makes is a different one.
    public func nextSynchronizationIdentifier() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        synchronizationCounter += 1
        return synchronizationCounter
    }
}

/// A component's value in a box, so that a reference to it can be written through.
public final class __REComponentBox {
    public var value: Any
    fileprivate init(_ value: Any) { self.value = value }
}

// MARK: - The references the SDK's headers name

/// A reference to a component value. `__toCore(_:)` writes through it, which is why the value
/// sits in a box and not behind a pointer the caller owns.
public struct __ComponentRef {
    @usableFromInline let box: __REComponentBox

    @usableFromInline init(_ box: __REComponentBox) { self.box = box }

    public static func __fromCore(_ core: Any) -> __ComponentRef {
        if let box = core as? __REComponentBox { return __ComponentRef(box) }
        return __ComponentRef(__REComponentBox(core))
    }

    public nonisolated func __as<T>(_ type: T.Type) -> T { box.value as! T }

    /// What `Component.__toCore(_:)` writes through.
    public nonisolated func __write<T>(_ component: T) { box.value = component }
}

/// A reference to a component type's registration.
public struct __ComponentTypeRef {
    @usableFromInline let type: __REComponentType

    @usableFromInline init(_ type: __REComponentType) { self.type = type }

    public static func __fromCore(_ core: Any) -> __ComponentTypeRef {
        __ComponentTypeRef(core as! __REComponentType)
    }

    public func __as<T>(_ type: T.Type) -> T { self.type as! T }

    /// The registration this reference names, for the code in this module that stores by it.
    @usableFromInline var registration: __REComponentType { type }
}

/// A reference to a scale-rotation-translation, the form the engine keeps a transform in.
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

/// A reference to an axis-aligned bounding box, the form the engine keeps bounds in.
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

    /// The eight corners, which is what a ray/box test needs.
    @usableFromInline var corners: [SIMD3<Float>] {
        [SIMD3<Float>(min.x, min.y, min.z), SIMD3<Float>(max.x, min.y, min.z),
         SIMD3<Float>(min.x, max.y, min.z), SIMD3<Float>(max.x, max.y, min.z),
         SIMD3<Float>(min.x, min.y, max.z), SIMD3<Float>(max.x, min.y, max.z),
         SIMD3<Float>(min.x, max.y, max.z), SIMD3<Float>(max.x, max.y, max.z)]
    }
}

// MARK: - The scene-graph node

/// One node of the scene graph: its name, its transform, its components, its place in the
/// hierarchy and the scene it is rooted in. This is the state an `Entity` reads and writes.
@MainActor public final class __REEntity {
    public let identifier: UInt64
    public var name: String
    public var transform: Transform
    /// The components, by their registration and in the order they were added: an entity
    /// carries at most one of a type, and setting a second replaces the first, which is what
    /// `components.subscript` documents. The order is what the debugger's tree prints, and the
    /// system's own prints a new entity's transform before its synchronization component.
    var components: [(key: ObjectIdentifier, value: Any)] = []
    public var children: [__REEntity] = []
    public weak var parent: __REEntity?
    /// Set on a root entity when it is added to a scene; an entity reads it by walking up.
    public var scene: __REScene?
    public var isEnabled: Bool = true
    /// Whether a session still sees this node's anchor target, which is nil for a node that is
    /// not an anchor.
    public var tracked: Bool?
    /// The animations playing on this node, by their token.
    public var animations: [UInt64: AnimationPlaybackController] = [:]
    /// The `Entity` that wraps this node, made on the first use and kept, so that `children`
    /// and `findEntity` hand back the same object for the same node.
    public var wrapper: Entity?

    public init(name: String = "") {
        self.identifier = __REComponentRegistry.shared.nextEntityIdentifier()
        self.name = name
        self.transform = Transform()
        // Measured on the host (2026-09-27, arm64-apple-macos14, MacOSX26.5.sdk): a new
        // `Entity()` carries two components, and a debugger prints them as this pair.
        self.setComponent(Transform())
        self.setComponent(SynchronizationComponent())
    }

    /// The wrapper of this node, made on the first use.
    public var entity: Entity {
        if let wrapper { return wrapper }
        let made = Entity(_coreEntity: __EntityRef(self))
        wrapper = made
        return made
    }

    /// The registration of `componentType`, whether or not it is in `components`.
    func registration(of componentType: Any.Type) -> __REComponentType {
        __REComponentRegistry.shared.registration(of: componentType, size: __reComponentSize(of: componentType))
    }

    func component<T>(of componentType: T.Type) -> T? where T: Component {
        // The node's own scale-rotation-translation is the transform, whether or not the set
        // still holds the mirror of it: `position`, `orientation` and the hierarchy read the
        // node, and a set that answered a second value would be a second transform.
        if componentType == Transform.self { return transform as! T }
        return stored(of: componentType) as? T
    }

    func setComponent<T>(_ component: T) where T: Component {
        setComponentAny(component)
    }

    /// The same, for a component the caller holds as an existential.
    func setComponentAny(_ component: any Component) {
        let key = registration(of: Swift.type(of: component)).identifier
        if let at = components.firstIndex(where: { $0.key == key }) {
            components[at] = (key, component)
        } else {
            components.append((key, component))
        }
        if let transform = component as? Transform { self.transform = transform }
    }

    /// Puts a component into this node's storage without going through its protocol, which is
    /// what a clone needs: the value it has is the value to keep.
    func putComponent(_ component: Any) {
        let key = registration(of: Swift.type(of: component)).identifier
        if let at = components.firstIndex(where: { $0.key == key }) {
            components[at] = (key, component)
        } else {
            components.append((key, component))
        }
    }

    /// The value the set holds for a component type, and nil for one it does not hold.
    func stored(of componentType: Any.Type) -> Any? {
        let key = registration(of: componentType).identifier
        return components.first { $0.key == key }?.value
    }

    func removeComponent(of componentType: Any.Type) {
        let key = registration(of: componentType).identifier
        components.removeAll { $0.key == key }
        // A transform taken out of the set is not the node's transform any more; the node keeps
        // the transform it had, which is what the system answers for it too.
    }

    /// Removes every component, the transform among them, as `ComponentSet.removeAll()` does.
    func removeAllComponents() {
        components.removeAll()
        transform = Transform()
    }

    /// Whether the set holds a component of the type. A new entity's transform is in the set, as
    /// the system's own is; taking it out takes it out of the count too, and the node keeps the
    /// transform it had.
    func hasComponent(of componentType: Any.Type) -> Bool {
        stored(of: componentType) != nil
    }

    /// The number of components of this node, the transform and the synchronization component
    /// among them: the system's own new entity reports two.
    var componentCount: Int { components.count }

    /// The topmost node of the hierarchy this one is in, itself when it has no parent.
    var root: __REEntity {
        var node = self
        while let parent = node.parent { node = parent }
        return node
    }

    var sceneOfRoot: __REScene? { root.scene }

    /// Whether this node and every node above it is enabled.
    var isEnabledInHierarchy: Bool {
        var node: __REEntity? = self
        while let current = node {
            if !current.isEnabled { return false }
            node = current.parent
        }
        return true
    }

    /// Whether the node is rooted in a scene and enabled all the way up.
    var isActive: Bool { sceneOfRoot != nil && isEnabledInHierarchy }

    /// Whether this node is one of a scene's anchors, or is below one. Measured on the host
    /// (2026-09-27): a detached `AnchorEntity` says false, the same entity once it is added to
    /// a scene says true, and so does a child of it.
    var isAnchored: Bool {
        var node: __REEntity? = self
        while let current = node {
            if let scene = current.scene, scene.anchors.contains(where: { $0 === current }) { return true }
            node = current.parent
        }
        return false
    }

    /// Add `child` to this node, taking it from the parent it has, which is what `addChild`
    /// documents: an entity has one parent, and adding it to a second one moves it.
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

    /// This node's transform in the coordinates of the root of its hierarchy.
    public var transformMatrixInHierarchy: float4x4 {
        var matrix = transform.matrix
        var node = parent
        while let current = node {
            matrix = current.transform.matrix * matrix
            node = current.parent
        }
        return matrix
    }

    /// This node's transform in the coordinates of `reference`, which is nil for the root of
    /// the hierarchy and for an entity no scene roots.
    public func transformMatrix(relativeTo reference: __REEntity?) -> float4x4 {
        let mine = transformMatrixInHierarchy
        guard let reference, reference !== self else { return mine }
        return reference.transformMatrixInHierarchy.inverted * mine
    }

    /// This node's transform as a component value, for `components[Transform.self]`.
    public var transformComponent: Transform { transform }

    public func setTransformComponent(_ value: Transform) { transform = value }

    /// The axis-aligned box of this node and, with `recursive`, of everything below it, in the
    /// coordinates of this node's parent. A node with no model of its own is a cube of one
    /// unit, which is the box its own transform then places and scales.
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

    /// The bounds in the coordinates of `reference`, which is nil for the coordinates of this
    /// node's parent.
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

    /// Every node of the subtree, this one first, in depth-first order.
    public var subtree: [__REEntity] {
        [self] + children.flatMap { $0.subtree }
    }

    public func firstNode(named name: String) -> __REEntity? {
        subtree.first { $0.name == name }
    }

    /// This node, its components and its subtree, in the tree the system's own debugger prints.
    /// Measured on the host, 2026-09-27: `▿ 'name' : TypeName` with `, children: N` when the
    /// node has children, then a line per component with `⟐`, then a line per child, each two
    /// spaces further in than its parent.
    public func debugDescription(typeName: String) -> String {
        debugDescription(typeName: typeName, indent: 0)
    }

    /// The same, with every line moved `indent` spaces to the right.
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

/// The size a component type's value occupies, which the type itself reports. A type that is
/// not a `Component` has no size and no components, and stores nothing.
private func __reComponentSize(of componentType: Any.Type) -> Int {
    guard let metatype = componentType as? any Component.Type else { return 0 }
    return metatype.__size
}

// MARK: - The references over the node

/// A reference to an entity's node in the scene graph. Two references are the same entity when
/// they name the same node, which is what `Entity.__coreEntity` and `__EntityRef.__as` answer.
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

/// The state a scene keeps: its name, the anchors it roots, and the identifiers it hands out.
@MainActor public final class __REScene {
    public let identifier: UInt64
    public var name: String
    public var anchors: [__REEntity] = []
    public var synchronizationService: Any?
    /// The timebase the scene's time is read from, made on the first use of it and kept. CoreMedia's
    /// `CMTimebase` is a C type reached through the SDK's clang module, so the port names it without
    /// an overlay of its own.
    public var timebase: CMTimebase?
    /// The `Scene` that wraps this state, made on the first use and kept.
    public var wrapper: Scene?
    /// The pairs of nodes that were touching at the last step of the simulation, so that the
    /// events a collision ends are raised once.
    public var collisions: Set<String>?
    private var counter: UInt64 = 0
    private let lock = NSLock()

    /// The timebase every scene shares when CoreMedia would not make one of its own, made once.
    /// `nil` here means the allocator failed, which is not a state a scene can be put in.
    static var _sharedTimebase: CMTimebase?
    static func sharedTimebase() -> CMTimebase {
        if let made = _sharedTimebase { return made }
        var timebase: CMTimebase?
        // The Swift import types the master clock as a non-optional `CMClock`, so a timebase with
        // no master clock is spelled by the clock the host time is read from, which is what a scene
        // that is stepped by its caller does not want and this fallback is not the main path anyway.
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

    /// The anchor entity of the node at `index`. A node a scene roots is an anchor, so the
    /// wrapper it gets is an `AnchorEntity`, made once and kept.
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

    /// Every node of every anchor, the anchors' own nodes included.
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

    /// The `Scene` that wraps this state, made on the first use and kept, so that the same
    /// scene is always the same object.
    public var entity: Scene {
        if let wrapper { return wrapper }
        let made = Scene(_coreScene: __SceneRef(self))
        wrapper = made
        return made
    }
}

/// A reference to a scene's state.
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

// MARK: - The matrix operations the port's release needs

/// The 4x4 inverse, and the multiplication of a matrix by a point or a direction.
///
/// The C `simd` module marks `simd_inverse` iOS 8, so a program built for this port's release
/// cannot call it, and a scene graph whose transforms are matrices has to invert them. This is
/// Gauss-Jordan elimination with partial pivoting over the rows, which is what the release's
/// own `simd_inverse` computes.
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
            // A matrix with no pivot in this column has no inverse. The release's own answer
            // here is a matrix of infinities, which is what dividing by the zero pivot gives.
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

/// Row `row` of a column-major matrix, as a vector of four.
@inline(__always)
private func __reRow(_ matrix: float4x4, _ row: Int) -> SIMD4<Float> {
    SIMD4<Float>(matrix.columns.0[row], matrix.columns.1[row], matrix.columns.2[row], matrix.columns.3[row])
}

/// Column `column` of the matrix the `rows` pairs hold, which is the inverse's column.
@inline(__always)
private func __reColumn(_ rows: [(SIMD4<Float>, SIMD4<Float>)], _ column: Int) -> SIMD4<Float> {
    SIMD4<Float>(rows[0].1[column], rows[1].1[column], rows[2].1[column], rows[3].1[column])
}

/// A point or a direction put through a matrix and read back as three components: a point
/// carries its 1, a direction its 0, and neither is translated by the fourth column.
@inline(__always)
internal func __reApply(_ matrix: float4x4, _ vector: SIMD3<Float>, asPoint: Bool) -> SIMD3<Float> {
    let moved = matrix * SIMD4<Float>(vector, asPoint ? 1 : 0)
    return SIMD3<Float>(moved.x, moved.y, moved.z)
}

extension float4x4 {
    /// This matrix's inverse, by `__reInverse`. The `simd` module's own `inverse` is marked
    /// iOS 8 and is not callable from this release.
    @inline(__always)
    public var inverted: float4x4 { __reInverse(self) }
}
