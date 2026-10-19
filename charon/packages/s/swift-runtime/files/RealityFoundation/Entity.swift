// Entity: the node a program builds a scene out of, and the component and child collections
// that hang off it.

import simd
import Foundation

// MARK: - The protocols an entity refines

/// An entity that sits in a hierarchy: it has a parent, children, and a place in a scene.
@MainActor public protocol HasHierarchy: Entity {}

/// An entity that has a transform, and so can be placed.
@MainActor public protocol HasTransform: Entity {}

/// An entity with a name.
@MainActor public protocol HasName: Entity {}

/// An entity that is synchronized with other devices and sessions.
@MainActor public protocol HasSynchronization: Entity {}

/// An entity that can be anchored to a real-world target.
@MainActor public protocol HasAnchoring: Entity {}

/// An entity that carries a model.
@MainActor public protocol HasModel: HasTransform {}

/// An entity that takes part in collision.
@MainActor public protocol HasCollision: Entity {}

/// An entity that a physics body moves.
@MainActor public protocol HasPhysicsMotion: Entity {}

/// An entity with a collision shape and a physics body.
@MainActor public protocol HasPhysicsBody: HasCollision {}

/// An entity with both.
@MainActor public protocol HasPhysics: HasPhysicsBody, HasPhysicsMotion {}

// MARK: - Entity

/// An object in a scene: a position in the hierarchy, a transform, and a set of components.
///
/// Every entity is in a hierarchy and has a transform; the protocols that say so are what the
/// members below are declared on, so a caller that holds an `Entity` reaches all of them.
@MainActor
open class Entity: HasHierarchy, HasTransform, HasSynchronization, EventSource, Sendable {
    /// A reference to this entity's node in the scene graph.
    public var __coreEntity: __EntityRef { __EntityRef(coreEntity) }

    /// The storage every member of this class reads and writes.
    let coreEntity: __REEntity

    public required init() {
        coreEntity = __REEntity(name: "")
        coreEntity.wrapper = self
    }

    /// The initializer an entity's own storage is made through, which the scene graph uses when
    /// it hands back a node it already holds and `clone(recursive:)` uses to make the copy.
    ///
    /// It is `required` so that a copy of a subclass is a subclass: a subclass with no
    /// designated initializer of its own inherits it, and one that has declares its own
    /// `required` initializer here and forwards to this one, which is what a copy of its own
    /// type has to do.
    public required init(_coreEntity: __EntityRef) {
        coreEntity = _coreEntity.node
        if coreEntity.wrapper == nil { coreEntity.wrapper = self }
    }

    // MARK: Identity

    /// A number that identifies this entity for the life of the process.
    public typealias ID = UInt64

    /// A number that identifies this entity for the life of the process.
    public var id: UInt64 { coreEntity.identifier }

    public var name: String {
        get { coreEntity.name }
        set { coreEntity.name = newValue }
    }

    public var components: Entity.ComponentSet {
        get { Entity.ComponentSet(coreEntity) }
        set { coreEntity.components = newValue.coreEntity.components; coreEntity.transform = newValue.coreEntity.transform }
    }

    /// The scene this entity belongs to, or nil when nothing roots it in a scene.
    public var scene: Scene? {
        coreEntity.sceneOfRoot?.entity
    }

    public var isActive: Bool { coreEntity.isActive }

    public var isAnchored: Bool { coreEntity.isAnchored }

    public var isEnabled: Bool {
        get { coreEntity.isEnabled }
        set { coreEntity.isEnabled = newValue }
    }

    public var isEnabledInHierarchy: Bool { coreEntity.isEnabledInHierarchy }

    /// The axis-aligned box of this entity's own unit cube, in the coordinates of its parent.
    public var __boundingBox: __AABBRef {
        let box = coreEntity.boundingBox(recursive: false, excludeInactive: false)
        return __AABBRef(min: box.min, max: box.max)
    }

    public static func __fromCore(_ coreEntity: __EntityRef) -> Entity {
        coreEntity.__as(Entity.self)
    }

    /// Called on a clone of this entity, with the entity it was cloned from, so that a
    /// subclass can copy what its own storage holds and the copy is not shared.
    open func didClone(from source: Entity) {}

    /// The first entity of this one and everything below it with the given name.
    public func findEntity(named name: String) -> Entity? {
        guard let found = coreEntity.firstNode(named: name) else { return nil }
        return found === coreEntity ? self : found.entity
    }

    /// A copy of this entity, and with `recursive` of everything below it. The copy has its own
    /// storage: a later change to either is not a change to the other.
    ///
    /// The copy is made through this type's own `init(_coreEntity:)`, so a subclass's copy is a
    /// subclass; a subclass that also holds state of its own copies that state in
    /// `didClone(from:)`, which is called on the copy with this entity.
    @discardableResult
    public func clone(recursive: Bool) -> Self {
        let copied = coreEntity.clone(recursive: recursive)
        let wanted = Self(_coreEntity: __EntityRef(copied))
        wanted.didClone(from: self)
        return wanted
    }

    public func __clone(recursive: Bool, remapInteractionIdentifiers: Bool) -> Self {
        clone(recursive: recursive)
    }
}

// MARK: - The component set

extension Entity {
    /// The components of one entity, one of each type at most.
    ///
    /// A subscript takes and returns a component by its type, and reading a type the entity
    /// does not carry gives nil. Setting a component of a type the entity already carries
    /// replaces it.
    @MainActor
    public struct ComponentSet {
        let coreEntity: __REEntity

        init(_ coreEntity: __REEntity) { self.coreEntity = coreEntity }

        public subscript<T>(componentType: T.Type) -> T? where T: Component {
            get { coreEntity.component(of: componentType) }
            set { setOrRemove(newValue, of: componentType) }
        }

        public subscript(componentType: any Component.Type) -> (any Component)? {
            get { coreEntity.component(of: componentType) }
            set { setOrRemove(newValue, of: componentType) }
        }

        private func setOrRemove(_ newValue: (any Component)?, of componentType: any Component.Type) {
            if let newValue {
                coreEntity.setComponentAny(newValue)
            } else {
                coreEntity.removeComponent(of: componentType)
            }
        }

        public func set<T>(_ component: T) where T: Component {
            coreEntity.setComponent(component)
        }

        public func set(_ components: [any Component]) {
            for component in components { coreEntity.setComponentAny(component) }
        }

        public func has(_ componentType: any Component.Type) -> Bool {
            coreEntity.hasComponent(of: componentType)
        }

        public func remove(_ componentType: any Component.Type) {
            coreEntity.removeComponent(of: componentType)
        }

        /// Removes every component the entity carries, the transform among them. Measured on
        /// the host (2026-09-27): a new entity reports two components, and after this it
        /// reports none.
        public func removeAll() {
            coreEntity.removeAllComponents()
        }

        /// The number of components the entity carries, the transform among them.
        public var count: Int { coreEntity.componentCount }
    }
}

// MARK: - The child collection

extension Entity {
    /// The children of one entity, in the order they were added.
    ///
    /// Setting the collection replaces the children; a child that was in both collections
    /// keeps one place in the new one, and one that was only in the old one is taken out of
    /// its parent.
    @MainActor
    public struct ChildCollection: Collection {
        public typealias Element = Entity
        public typealias Index = Int
        public typealias Indices = DefaultIndices<ChildCollection>
        public typealias Iterator = IndexingIterator<ChildCollection>
        public typealias SubSequence = Slice<ChildCollection>

        /// The iterator of a collection whose indices are its positions: it walks a snapshot of
        /// the children taken when it was made, which is what a scene graph hands out, so that
        /// the children can be changed while one walks them.
        public struct IndexingIterator<Base: Collection>: IteratorProtocol {
            public typealias Element = Base.Element
            private let elements: [Element]
            private var position: Int

            public init(_elements: [Element]) {
                self.elements = _elements
                self.position = 0
            }

            public init(_elements: [Element], _position: Int) {
                self.elements = _elements
                self.position = _position
            }

            public mutating func next() -> Element? {
                guard position < elements.count else { return nil }
                defer { position += 1 }
                return elements[position]
            }
        }

        let coreEntity: __REEntity

        init(_ coreEntity: __REEntity) { self.coreEntity = coreEntity }

        public var startIndex: Int { 0 }
        public var endIndex: Int { coreEntity.children.count }
        public func index(after i: Int) -> Int { i + 1 }

        public subscript(index: Int) -> Entity {
            get { coreEntity.children[index].entity }
            set { coreEntity.adopt(newValue.coreEntity, preservingWorldTransform: false) }
        }

        public func makeIterator() -> Iterator {
            Iterator(_elements: coreEntity.children.map { $0.entity })
        }

        public func append(_ child: Entity, preservingWorldTransform: Bool = false) {
            coreEntity.adopt(child.coreEntity, preservingWorldTransform: preservingWorldTransform)
        }

        public func append(contentsOf array: [Entity], preservingWorldTransforms: Bool = false) {
            for child in array { append(child, preservingWorldTransform: preservingWorldTransforms) }
        }

        public func append<S>(contentsOf sequence: S, preservingWorldTransforms: Bool = false) where S: Sequence, S.Element: Entity {
            for child in sequence { append(child, preservingWorldTransform: preservingWorldTransforms) }
        }

        public func append(contentsOf children: ChildCollection, preservingWorldTransforms: Bool = false) {
            for child in children { append(child, preservingWorldTransform: preservingWorldTransforms) }
        }

        public func remove(_ child: Entity, preservingWorldTransform: Bool = false) {
            child.coreEntity.detach(preservingWorldTransform: preservingWorldTransform)
        }

        public func remove(at index: Int, preservingWorldTransform: Bool = false) {
            coreEntity.children[index].detach(preservingWorldTransform: preservingWorldTransform)
        }

        public func removeAll(keepCapacity: Bool = false, preservingWorldTransforms: Bool = false) {
            for child in coreEntity.children {
                child.detach(preservingWorldTransform: preservingWorldTransforms)
            }
        }

        public func removeAll(preservingWorldTransforms: Bool = false) {
            removeAll(keepCapacity: false, preservingWorldTransforms: preservingWorldTransforms)
        }

        public func replaceAll(_ children: [Entity], preservingWorldTransforms: Bool = false) {
            let wanted = children.map { $0.coreEntity }
            for child in coreEntity.children where !wanted.contains(where: { $0 === child }) {
                child.detach(preservingWorldTransform: preservingWorldTransforms)
            }
            for child in wanted where child.parent !== coreEntity {
                coreEntity.adopt(child, preservingWorldTransform: preservingWorldTransforms)
            }
            coreEntity.children = wanted.filter { $0.parent === coreEntity }
        }

        public func replaceAll<S>(_ children: S, preservingWorldTransforms: Bool = false) where S: Sequence, S.Element: Entity {
            let wanted = children.map { $0.coreEntity }
            for child in coreEntity.children where !wanted.contains(where: { $0 === child }) {
                child.detach(preservingWorldTransform: preservingWorldTransforms)
            }
            for child in wanted where child.parent !== coreEntity {
                coreEntity.adopt(child, preservingWorldTransform: preservingWorldTransforms)
            }
            // The order the caller gave, for the children this entity keeps.
            coreEntity.children = wanted.filter { $0.parent === coreEntity }
        }
    }
}

/// The basis this entity presents in the coordinates of `reference`, which is where its scale
/// and its orientation are read.
@MainActor
@inline(__always)
internal func __reBasis(_ reference: __REEntity, _ entity: __REEntity) -> simd_float3x3 {
    let relative = reference.transformMatrixInHierarchy.inverted * entity.transformMatrixInHierarchy
    return simd_float3x3(columns: (__re3(relative.columns.0), __re3(relative.columns.1), __re3(relative.columns.2)))
}

// MARK: - Identity

extension Entity: Hashable {
    /// Two entities are equal when they are the same entity: the same node of the scene graph,
    /// reached through two references.
    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        lhs.coreEntity === rhs.coreEntity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(coreEntity.identifier)
    }
}

extension Entity: CustomDebugStringConvertible {
    /// The entity, its components and everything below it, as a tree.
    ///
    /// Measured on the host (2026-09-27, arm64-apple-macos14, MacOSX26.5.sdk) for a new entity
    /// named `box`: `▿ 'box' : Entity` on the first line, then `  ⟐ Transform` and
    /// `  ⟐ SynchronizationComponent`; and for an entity with one child, `▿ 'parent' : Entity,
    /// children: 1`, its own two components, and the child at the same two-space indent with
    /// its own components two further in.
    public var debugDescription: String {
        coreEntity.debugDescription(typeName: String(describing: type(of: self)))
    }
}

// MARK: - The hierarchy

@MainActor
extension HasHierarchy {
    /// The entity this one is a child of, or nil when it is at the top of its hierarchy.
    public var parent: Entity? {
        coreEntity.parent?.entity
    }

    /// Makes `parent` this entity's parent, or takes it out of the one it has when `parent` is
    /// nil. An entity has one parent: setting a second one moves it.
    public func setParent(_ parent: Entity?, preservingWorldTransform: Bool = false) {
        if let parent {
            parent.coreEntity.adopt(coreEntity, preservingWorldTransform: preservingWorldTransform)
        } else {
            coreEntity.detach(preservingWorldTransform: preservingWorldTransform)
        }
    }

    /// The children of this entity. Setting the collection replaces them.
    public var children: Entity.ChildCollection {
        get { Entity.ChildCollection(coreEntity) }
        set {
            let wanted = Array(newValue).map { $0.coreEntity }
            for child in coreEntity.children where !wanted.contains(where: { $0 === child }) {
                child.detach(preservingWorldTransform: false)
            }
            for child in wanted where child.parent !== coreEntity {
                coreEntity.adopt(child, preservingWorldTransform: false)
            }
            coreEntity.children = wanted.filter { $0.parent === coreEntity }
        }
    }

    /// Makes `entity` a child of this one, taking it from the parent it has.
    public func addChild(_ entity: Entity, preservingWorldTransform: Bool = false) {
        coreEntity.adopt(entity.coreEntity, preservingWorldTransform: preservingWorldTransform)
    }

    /// Takes `entity` out of this one's children, whether or not it is one of them.
    public func removeChild(_ entity: Entity, preservingWorldTransform: Bool = false) {
        guard entity.coreEntity.parent === coreEntity else { return }
        entity.coreEntity.detach(preservingWorldTransform: preservingWorldTransform)
    }

    /// Takes this entity out of its parent's children.
    public func removeFromParent(preservingWorldTransform: Bool = false) {
        coreEntity.detach(preservingWorldTransform: preservingWorldTransform)
    }
}

// MARK: - The transform

@MainActor
extension HasTransform {
    public var transform: Transform {
        get { coreEntity.transform }
        set { coreEntity.transform = newValue }
    }

    public var scale: SIMD3<Float> {
        get { transform.scale }
        set { transform.scale = newValue }
    }

    /// This entity's scale in the coordinates of `referenceEntity`, nil being the top of the
    /// hierarchy this entity is in.
    public func scale(relativeTo referenceEntity: Entity?) -> SIMD3<Float> {
        guard let referenceEntity, referenceEntity.coreEntity !== coreEntity else { return scale }
        let basis = __reBasis(referenceEntity.coreEntity, coreEntity)
        return SIMD3<Float>(simd_length(basis.columns.0), simd_length(basis.columns.1), simd_length(basis.columns.2))
    }

    public func setScale(_ scale: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        let relative = self.scale(relativeTo: referenceEntity)
        self.scale = SIMD3<Float>(scale.x / relative.x, scale.y / relative.y, scale.z / relative.z)
    }

    public var position: SIMD3<Float> {
        get { transform.translation }
        set { transform.translation = newValue }
    }

    /// This entity's position in the coordinates of `referenceEntity`, nil being the top of the
    /// hierarchy this entity is in.
    public func position(relativeTo referenceEntity: Entity?) -> SIMD3<Float> {
        let matrix = coreEntity.transformMatrix(relativeTo: referenceEntity?.coreEntity)
        return SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
    }

    public func setPosition(_ position: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        if let referenceEntity, referenceEntity.coreEntity !== coreEntity {
            setTransformMatrix(Transform(matrix: coreEntity.transformMatrix(relativeTo: referenceEntity.coreEntity)).matrix,
                               relativeTo: referenceEntity)
            return
        }
        transform.translation = position
    }

    public var orientation: simd_quatf {
        get { transform.rotation }
        set { transform.rotation = newValue }
    }

    public func orientation(relativeTo referenceEntity: Entity?) -> simd_quatf {
        guard let referenceEntity, referenceEntity.coreEntity !== coreEntity else { return orientation }
        return simd_quatf(__reBasis(referenceEntity.coreEntity, coreEntity))
    }

    public func setOrientation(_ orientation: simd_quatf, relativeTo referenceEntity: Entity?) {
        guard let referenceEntity, referenceEntity.coreEntity !== coreEntity else {
            transform.rotation = orientation
            return
        }
        transform.rotation = simd_quatf(__reBasis(referenceEntity.coreEntity, coreEntity))
    }

    /// This entity's transform as a matrix, in the coordinates of `referenceEntity`.
    public func transformMatrix(relativeTo referenceEntity: Entity?) -> float4x4 {
        coreEntity.transformMatrix(relativeTo: referenceEntity?.coreEntity)
    }

    public func setTransformMatrix(_ transform: float4x4, relativeTo referenceEntity: Entity?) {
        guard let referenceEntity, referenceEntity.coreEntity !== coreEntity else {
            self.transform = Transform(matrix: transform)
            return
        }
        let reference = referenceEntity.coreEntity.transformMatrixInHierarchy
        self.transform = Transform(matrix: reference * transform)
    }

    public func convert(position: SIMD3<Float>, from referenceEntity: Entity?) -> SIMD3<Float> {
        // A position given in the reference's coordinates, read in this entity's. With no
        // reference the position is already in the coordinates of the root of the hierarchy,
        // and `from` reads it in this entity's own.
        guard let referenceEntity else { return __reApply(coreEntity.transformMatrixInHierarchy.inverted, position, asPoint: true) }
        let matrix = referenceEntity.coreEntity.transformMatrix(relativeTo: coreEntity)
        return __reApply(matrix, position, asPoint: true)
    }

    public func convert(direction: SIMD3<Float>, from referenceEntity: Entity?) -> SIMD3<Float> {
        guard let referenceEntity else { return __reApply(coreEntity.transformMatrixInHierarchy.inverted, direction, asPoint: false) }
        let matrix = referenceEntity.coreEntity.transformMatrix(relativeTo: coreEntity)
        return __reApply(matrix, direction, asPoint: false)
    }

    public func convert(normal: SIMD3<Float>, from referenceEntity: Entity?) -> SIMD3<Float> {
        convert(direction: normal, from: referenceEntity)
    }

    public func convert(transform: Transform, from referenceEntity: Entity?) -> Transform {
        guard let referenceEntity, referenceEntity.coreEntity !== coreEntity else { return transform }
        let matrix = referenceEntity.coreEntity.transformMatrix(relativeTo: coreEntity)
        return Transform(matrix: matrix * transform.matrix)
    }

    public func convert(position: SIMD3<Float>, to referenceEntity: Entity?) -> SIMD3<Float> {
        guard let referenceEntity else { return __reApply(coreEntity.transformMatrixInHierarchy, position, asPoint: true) }
        // A position given in this entity's own coordinates, read in the reference's. Measured
        // on the host (2026-09-27): a child at (1, 0, 0) of a parent at (0, 2, 0) answers
        // (1, 0, 0) for the origin and (2, 0, 0) for (1, 0, 0).
        let matrix = coreEntity.transformMatrix(relativeTo: referenceEntity.coreEntity)
        return __reApply(matrix, position, asPoint: true)
    }

    public func convert(direction: SIMD3<Float>, to referenceEntity: Entity?) -> SIMD3<Float> {
        guard let referenceEntity else { return __reApply(coreEntity.transformMatrixInHierarchy, direction, asPoint: false) }
        let matrix = coreEntity.transformMatrix(relativeTo: referenceEntity.coreEntity)
        return __reApply(matrix, direction, asPoint: false)
    }

    public func convert(normal: SIMD3<Float>, to referenceEntity: Entity?) -> SIMD3<Float> {
        convert(direction: normal, to: referenceEntity)
    }

    public func convert(transform: Transform, to referenceEntity: Entity?) -> Transform {
        guard let referenceEntity else { return transform }
        let matrix = coreEntity.transformMatrix(relativeTo: referenceEntity.coreEntity)
        return Transform(matrix: matrix * transform.matrix)
    }

    /// Points this entity's negative z axis from `position` at `target`, with `upVector` as
    /// the up direction, all three in the coordinates of `referenceEntity`.
    public func look(at target: SIMD3<Float>, from position: SIMD3<Float>,
                     upVector: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
                     relativeTo referenceEntity: Entity?) {
        let toTarget = target - position
        let forward = -simd_normalize(toTarget)
        let up = simd_normalize(upVector)
        let right = simd_cross(up, forward)
        let corrected = simd_cross(forward, right)
        setTransformMatrix(float4x4(SIMD4<Float>(right, 0), SIMD4<Float>(corrected, 0),
                                     SIMD4<Float>(forward, 0), SIMD4<Float>(position, 1)),
                           relativeTo: referenceEntity)
    }

    public func move(to transform: Transform, relativeTo referenceEntity: Entity?) {
        setTransformMatrix(transform.matrix, relativeTo: referenceEntity)
    }

    public func move(to transform: float4x4, relativeTo referenceEntity: Entity?) {
        setTransformMatrix(transform, relativeTo: referenceEntity)
    }

    /// The box around this entity and, with `recursive`, everything below it, in the
    /// coordinates of `referenceEntity`.
    public func visualBounds(recursive: Bool = true, relativeTo referenceEntity: Entity?,
                             excludeInactive: Bool = false) -> BoundingBox {
        coreEntity.visualBounds(recursive: recursive, reference: referenceEntity?.coreEntity, excludeInactive: excludeInactive)
    }
}

// MARK: - Cloning

extension __REEntity {
    /// A copy of this node, and with `recursive` of everything below it. The copy carries the
    /// same components by value, so a later change to either is not a change to the other.
    public func clone(recursive: Bool) -> __REEntity {
        let copy = __REEntity(name: name)
        copy.transform = transform
        copy.isEnabled = isEnabled
        for (_, component) in components {
            // Every component is a value, and a value type's copy is the value itself; a
            // component holding a reference (a mesh, an animation) is shared until the types
            // that own those come with their own round. The transform is already copied above,
            // and the node's own is the one that counts.
            if component is Transform { continue }
            copy.putComponent(component)
        }
        if recursive {
            for child in children { copy.adopt(child.clone(recursive: true), preservingWorldTransform: false) }
        }
        return copy
    }

}
