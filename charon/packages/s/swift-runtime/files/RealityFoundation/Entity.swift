import simd
import Foundation

@MainActor public protocol HasHierarchy: Entity {}

@MainActor public protocol HasTransform: Entity {}

@MainActor public protocol HasName: Entity {}

@MainActor public protocol HasSynchronization: Entity {}

@MainActor public protocol HasAnchoring: Entity {}

@MainActor public protocol HasModel: HasTransform {}

@MainActor public protocol HasCollision: Entity {}

@MainActor public protocol HasPhysicsMotion: Entity {}

@MainActor public protocol HasPhysicsBody: HasCollision {}

@MainActor public protocol HasPhysics: HasPhysicsBody, HasPhysicsMotion {}

@MainActor
open class Entity: HasHierarchy, HasTransform, HasSynchronization, EventSource, Sendable {
    public var __coreEntity: __EntityRef { __EntityRef(coreEntity) }

    let coreEntity: __REEntity

    public required init() {
        coreEntity = __REEntity(name: "")
        coreEntity.wrapper = self
    }

    public required init(_coreEntity: __EntityRef) {
        coreEntity = _coreEntity.node
        if coreEntity.wrapper == nil { coreEntity.wrapper = self }
    }

    public typealias ID = UInt64

    public var id: UInt64 { coreEntity.identifier }

    public var name: String {
        get { coreEntity.name }
        set { coreEntity.name = newValue }
    }

    public var components: Entity.ComponentSet {
        get { Entity.ComponentSet(coreEntity) }
        set { coreEntity.components = newValue.coreEntity.components; coreEntity.transform = newValue.coreEntity.transform }
    }

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

    public var __boundingBox: __AABBRef {
        let box = coreEntity.boundingBox(recursive: false, excludeInactive: false)
        return __AABBRef(min: box.min, max: box.max)
    }

    public static func __fromCore(_ coreEntity: __EntityRef) -> Entity {
        coreEntity.__as(Entity.self)
    }

    open func didClone(from source: Entity) {}

    public func findEntity(named name: String) -> Entity? {
        guard let found = coreEntity.firstNode(named: name) else { return nil }
        return found === coreEntity ? self : found.entity
    }

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

extension Entity {
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

        public func removeAll() {
            coreEntity.removeAllComponents()
        }

        public var count: Int { coreEntity.componentCount }
    }
}

extension Entity {
    @MainActor
    public struct ChildCollection: Collection {
        public typealias Element = Entity
        public typealias Index = Int
        public typealias Indices = DefaultIndices<ChildCollection>
        public typealias Iterator = IndexingIterator<ChildCollection>
        public typealias SubSequence = Slice<ChildCollection>

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
            coreEntity.children = wanted.filter { $0.parent === coreEntity }
        }
    }
}

@MainActor
@inline(__always)
internal func __reBasis(_ reference: __REEntity, _ entity: __REEntity) -> simd_float3x3 {
    let relative = reference.transformMatrixInHierarchy.inverted * entity.transformMatrixInHierarchy
    return simd_float3x3(columns: (__re3(relative.columns.0), __re3(relative.columns.1), __re3(relative.columns.2)))
}

extension Entity: Hashable {
    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        lhs.coreEntity === rhs.coreEntity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(coreEntity.identifier)
    }
}

extension Entity: CustomDebugStringConvertible {
    public var debugDescription: String {
        coreEntity.debugDescription(typeName: String(describing: type(of: self)))
    }
}

@MainActor
extension HasHierarchy {
    public var parent: Entity? {
        coreEntity.parent?.entity
    }

    public func setParent(_ parent: Entity?, preservingWorldTransform: Bool = false) {
        if let parent {
            parent.coreEntity.adopt(coreEntity, preservingWorldTransform: preservingWorldTransform)
        } else {
            coreEntity.detach(preservingWorldTransform: preservingWorldTransform)
        }
    }

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

    public func addChild(_ entity: Entity, preservingWorldTransform: Bool = false) {
        coreEntity.adopt(entity.coreEntity, preservingWorldTransform: preservingWorldTransform)
    }

    public func removeChild(_ entity: Entity, preservingWorldTransform: Bool = false) {
        guard entity.coreEntity.parent === coreEntity else { return }
        entity.coreEntity.detach(preservingWorldTransform: preservingWorldTransform)
    }

    public func removeFromParent(preservingWorldTransform: Bool = false) {
        coreEntity.detach(preservingWorldTransform: preservingWorldTransform)
    }
}

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

    public func visualBounds(recursive: Bool = true, relativeTo referenceEntity: Entity?,
                             excludeInactive: Bool = false) -> BoundingBox {
        coreEntity.visualBounds(recursive: recursive, reference: referenceEntity?.coreEntity, excludeInactive: excludeInactive)
    }
}

extension __REEntity {
    public func clone(recursive: Bool) -> __REEntity {
        let copy = __REEntity(name: name)
        copy.transform = transform
        copy.isEnabled = isEnabled
        for (_, component) in components {
            if component is Transform { continue }
            copy.putComponent(component)
        }
        if recursive {
            for child in children { copy.adopt(child.clone(recursive: true), preservingWorldTransform: false) }
        }
        return copy
    }

}
