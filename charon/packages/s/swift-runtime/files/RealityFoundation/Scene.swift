import simd
import CoreMedia
import SceneKit
import Foundation

@frozen public struct BoundingBox: Equatable {
    public var min: SIMD3<Float>
    public var max: SIMD3<Float>

    public init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }

    public init() {
        min = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        max = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    }

    public var center: SIMD3<Float> { (min + max) / 2 }

    public var extents: SIMD3<Float> { max - min }

    public var corners: [SIMD3<Float>] {
        [SIMD3<Float>(min.x, min.y, min.z), SIMD3<Float>(max.x, min.y, min.z),
         SIMD3<Float>(min.x, max.y, min.z), SIMD3<Float>(max.x, max.y, min.z),
         SIMD3<Float>(min.x, min.y, max.z), SIMD3<Float>(max.x, min.y, max.z),
         SIMD3<Float>(min.x, max.y, max.z), SIMD3<Float>(max.x, max.y, max.z)]
    }

    public mutating func extend(with corner: SIMD3<Float>) {
        min = simd_min(min, corner)
        max = simd_max(max, corner)
    }

    public static func == (a: BoundingBox, b: BoundingBox) -> Bool {
        a.min == b.min && a.max == b.max
    }
}

@frozen public struct AnchoringComponent: Component, Equatable {
    public enum Target: Hashable {
        public struct Alignment: OptionSet, Hashable {
            public let rawValue: UInt8
            public init(rawValue: UInt8) { self.rawValue = rawValue }

            public static let horizontal = Alignment(rawValue: 1 << 0)
            public static let vertical = Alignment(rawValue: 1 << 1)
            public static let any: Alignment = [.horizontal, .vertical]
        }

        public struct Classification: OptionSet, Hashable {
            public let rawValue: UInt64
            public init(rawValue: UInt64) { self.rawValue = rawValue }

            public static let wall = Classification(rawValue: 1 << 0)
            public static let floor = Classification(rawValue: 1 << 1)
            public static let ceiling = Classification(rawValue: 1 << 2)
            public static let table = Classification(rawValue: 1 << 3)
            public static let seat = Classification(rawValue: 1 << 4)
            public static let any: Classification = [.wall, .floor, .ceiling, .table, .seat]
        }

        case camera
        case world(transform: float4x4)
        case anchor(identifier: UUID)
        case plane(Alignment, classification: Classification, minimumBounds: SIMD2<Float>)
        case image(group: String, name: String)
        case object(group: String, name: String)
        case face
        case body

        public static func == (a: Target, b: Target) -> Bool {
            switch (a, b) {
            case (.camera, .camera): return true
            case let (.world(x), .world(y)): return x == y
            case let (.anchor(x), .anchor(y)): return x == y
            case let (.plane(f, c, m), .plane(g, d, n)): return f == g && c == d && m == n
            case let (.image(g, n), .image(h, o)): return g == h && n == o
            case let (.object(g, n), .object(h, o)): return g == h && n == o
            case (.face, .face): return true
            case (.body, .body): return true
            default: return false
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .camera: hasher.combine(0)
            case let .world(transform):
                hasher.combine(1)
                hasher.combine(transform.columns.0)
                hasher.combine(transform.columns.1)
                hasher.combine(transform.columns.2)
                hasher.combine(transform.columns.3)
            case let .anchor(identifier): hasher.combine(2); hasher.combine(identifier)
            case let .plane(alignment, classification, minimumBounds):
                hasher.combine(3); hasher.combine(alignment); hasher.combine(classification); hasher.combine(minimumBounds)
            case let .image(group, name):
                hasher.combine(4); hasher.combine(group); hasher.combine(name)
            case let .object(group, name):
                hasher.combine(5); hasher.combine(group); hasher.combine(name)
            case .face: hasher.combine(6)
            case .body: hasher.combine(7)
            }
        }
    }

    public let target: Target

    public init(_ target: Target) {
        self.target = target
    }

    public static func == (a: AnchoringComponent, b: AnchoringComponent) -> Bool {
        a.target == b.target
    }
}

@MainActor
open class AnchorEntity: Entity, HasAnchoring {
    public required init(_coreEntity: __EntityRef) {
        super.init(_coreEntity: _coreEntity)
    }

    public var anchoring: AnchoringComponent {
        get { components[AnchoringComponent.self] ?? AnchoringComponent(.world(transform: float4x4(diagonal: SIMD4<Float>(1, 1, 1, 1)))) }
        set { components[AnchoringComponent.self] = newValue }
    }

    public required init() {
        super.init()
        components[AnchoringComponent.self] = AnchoringComponent(.camera)
    }

    public init(world: SIMD3<Float> = .zero) {
        super.init()
        name = "AnchorEntity"
        components[AnchoringComponent.self] = AnchoringComponent(.world(transform: float4x4(diagonal: SIMD4<Float>(1, 1, 1, 1))))
        position = world
    }

    public var anchorIdentifier: UUID? {
        if case .anchor(let identifier) = anchoring.target { return identifier }
        return nil
    }

    public var isTracked: Bool = true

    public init(plane: AnchoringComponent.Target.Alignment,
                classification: AnchoringComponent.Target.Classification,
                minimumBounds: SIMD2<Float> = .zero) {
        super.init()
        name = "AnchorEntity(plane)"
        components[AnchoringComponent.self] = AnchoringComponent(.plane(plane, classification: classification,
                                                                        minimumBounds: minimumBounds))
    }

    public func reanchor(_ target: AnchoringComponent.Target, preservingWorldTransform: Bool = true) {
        anchoring = AnchoringComponent(target)
        if !preservingWorldTransform { transform = Transform() }
    }
}

@frozen public struct SynchronizationComponent: Component, Equatable {
    public enum OwnershipTransferMode: Hashable {
        case autoAccept
        case manual
    }

    public enum OwnershipTransferCompletionResult: Hashable {
        case granted
        case timedOut
    }

    public let identifier: UInt64
    public var isOwner: Bool
    public var ownershipTransferMode: OwnershipTransferMode

    public init() {
        identifier = __REComponentRegistry.shared.nextSynchronizationIdentifier()
        isOwner = true
        ownershipTransferMode = .autoAccept
    }

    public init(identifier: UInt64, isOwner: Bool = true, ownershipTransferMode: OwnershipTransferMode = .autoAccept) {
        self.identifier = identifier
        self.isOwner = isOwner
        self.ownershipTransferMode = ownershipTransferMode
    }

    public static func == (a: SynchronizationComponent, b: SynchronizationComponent) -> Bool {
        a.identifier == b.identifier && a.isOwner == b.isOwner && a.ownershipTransferMode == b.ownershipTransferMode
    }
}

@MainActor
extension HasSynchronization {
    public var synchronization: SynchronizationComponent? {
        get { coreEntity.component(of: SynchronizationComponent.self) }
        set {
            if let newValue {
                coreEntity.setComponent(newValue)
            } else {
                coreEntity.removeComponent(of: SynchronizationComponent.self)
            }
        }
    }

    public var isOwner: Bool {
        synchronization?.isOwner ?? false
    }

    public func requestOwnership(timeout: TimeInterval = 15,
                                 _ callback: @escaping (SynchronizationComponent.OwnershipTransferCompletionResult) -> Void) {
        guard var component = synchronization else {
            callback(.timedOut)
            return
        }
        guard component.isOwner || component.ownershipTransferMode == .autoAccept else {
            callback(.timedOut)
            return
        }
        component.isOwner = true
        synchronization = component
        callback(.granted)
    }

    public func withUnsynchronized(_ changes: () -> Void) {
        changes()
    }
}

@MainActor
open class Scene {
    public typealias ID = UInt64

    public var __coreScene: __SceneRef { __SceneRef(coreScene) }

    public let coreScene: __REScene

    public init(_coreScene: __SceneRef) {
        coreScene = _coreScene.scene
        if coreScene.wrapper == nil { coreScene.wrapper = self }
    }

    public var name: String {
        get { coreScene.name }
        set { coreScene.name = newValue }
    }

    public var id: ID { coreScene.identifier }

    public weak var view: SCNView?

    public var timebase: CMTimebase {
        if let existing = coreScene.timebase { return existing }
        var timebase: CMTimebase?
        if CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault,
                                           masterClock: CMClockGetHostTimeClock(),
                                           timebaseOut: &timebase) == noErr, let made = timebase {
            coreScene.timebase = made
            return made
        }
        coreScene.timebase = __REScene.sharedTimebase()
        return coreScene.timebase!
    }

    public static func __fromCore(_ coreScene: __SceneRef) -> Scene {
        coreScene.__as(Scene.self)
    }

    public static func __testInit(name: String) -> Scene {
        Scene(_coreScene: __SceneRef(__REScene(name: name)))
    }

    public init() {
        coreScene = __REScene(name: "Scene")
        coreScene.wrapper = self
    }

    public var anchors: Scene.AnchorCollection {
        get { Scene.AnchorCollection(coreScene) }
        set { newValue.replaceAll(newValue) }
    }

    public func addAnchor(_ anchor: any HasAnchoring) {
        coreScene.add(anchor: anchor.coreEntity)
    }

    public func removeAnchor(_ anchor: any HasAnchoring) {
        coreScene.remove(anchor: anchor.coreEntity)
    }

    public func findEntity(named name: String) -> Entity? {
        coreScene.firstNode(named: name)?.entity
    }

    public func findEntity(id: Entity.ID) -> Entity? {
        coreScene.node(withIdentifier: id)?.entity
    }

    public static func == (lhs: Scene, rhs: Scene) -> Bool {
        lhs.coreScene === rhs.coreScene
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(coreScene.identifier)
    }
}

extension Scene: Hashable {}

extension Scene: Identifiable {}

extension Scene {
    @MainActor
    public struct AnchorCollection: Collection {
        public typealias Element = any HasAnchoring
        public typealias Index = Int
        public typealias Indices = DefaultIndices<AnchorCollection>
        public typealias SubSequence = Slice<AnchorCollection>

        public typealias Iterator = Entity.ChildCollection.IndexingIterator<AnchorCollection>

        let coreScene: __REScene

        init(_ coreScene: __REScene) { self.coreScene = coreScene }

        public var startIndex: Int { 0 }
        public var endIndex: Int { coreScene.anchors.count }
        public func index(after i: Int) -> Int { i + 1 }

        public subscript(index: Int) -> any HasAnchoring {
            get { coreScene.anchor(at: index) }
            set { coreScene.add(anchor: newValue.coreEntity) }
        }

        public func makeIterator() -> Iterator {
            Iterator(_elements: (0..<coreScene.anchors.count).map { coreScene.anchor(at: $0) })
        }

        public func append(_ entity: any HasAnchoring) {
            coreScene.add(anchor: entity.coreEntity)
        }

        public func append(contentsOf array: [any HasAnchoring]) {
            for entity in array { append(entity) }
        }

        public func append<S>(contentsOf sequence: S) where S: Sequence, S.Element == any HasAnchoring {
            for entity in sequence { append(entity) }
        }

        public func remove(_ entity: any HasAnchoring) {
            coreScene.remove(anchor: entity.coreEntity)
        }

        public func remove(at index: Int) {
            coreScene.remove(anchor: coreScene.anchors[index])
        }

        public func removeAll(keepCapacity: Bool = false) {
            for anchor in coreScene.anchors { coreScene.remove(anchor: anchor) }
        }

        public func removeAll() {
            removeAll(keepCapacity: false)
        }

        public func replaceAll(_ entities: [any HasAnchoring]) {
            for entity in entities { coreScene.add(anchor: entity.coreEntity) }
            let wanted = entities.map { $0.coreEntity }
            for anchor in coreScene.anchors where !wanted.contains(where: { $0 === anchor }) {
                coreScene.remove(anchor: anchor)
            }
        }

        public func replaceAll<S>(_ entities: S) where S: Sequence, S.Element == any HasAnchoring {
            let wanted = entities.map { $0.coreEntity }
            for anchor in coreScene.anchors where !wanted.contains(where: { $0 === anchor }) {
                coreScene.remove(anchor: anchor)
            }
            for anchor in wanted { coreScene.add(anchor: anchor) }
        }
    }
}

extension Scene.AnchorCollection: CustomStringConvertible {
    public var description: String {
        "[" + map { $0.debugDescription }.joined(separator: ",\n") + "\n]"
    }
}

@MainActor
extension __REEntity {
    public var anchoring: AnchoringComponent {
        component(of: AnchoringComponent.self)
            ?? AnchoringComponent(.world(transform: float4x4(diagonal: SIMD4<Float>(1, 1, 1, 1))))
    }

    public var isTracked: Bool {
        get { tracked ?? true }
        set { tracked = newValue }
    }
}
