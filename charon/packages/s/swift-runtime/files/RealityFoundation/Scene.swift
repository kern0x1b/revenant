// Scene: the root a set of anchors hangs from, and the anchoring component that makes an
// entity one of them.

import simd
import CoreMedia
import SceneKit
import Foundation

// MARK: - BoundingBox

/// An axis-aligned bounding box, given by two of its corners.
@frozen public struct BoundingBox: Equatable {
    /// The corner with the smallest coordinate on every axis.
    public var min: SIMD3<Float>
    /// The corner with the largest coordinate on every axis.
    public var max: SIMD3<Float>

    public init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }

    public init() {
        min = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        max = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    }

    /// The centre of the box.
    public var center: SIMD3<Float> { (min + max) / 2 }

    /// The size of the box along each axis.
    public var extents: SIMD3<Float> { max - min }

    /// The eight corners of the box, which is what a ray/box test and a corner-wise transform
    /// both need.
    public var corners: [SIMD3<Float>] {
        [SIMD3<Float>(min.x, min.y, min.z), SIMD3<Float>(max.x, min.y, min.z),
         SIMD3<Float>(min.x, max.y, min.z), SIMD3<Float>(max.x, max.y, min.z),
         SIMD3<Float>(min.x, min.y, max.z), SIMD3<Float>(max.x, min.y, max.z),
         SIMD3<Float>(min.x, max.y, max.z), SIMD3<Float>(max.x, max.y, max.z)]
    }

    /// Grows the box, if `corner` lies outside it.
    public mutating func extend(with corner: SIMD3<Float>) {
        min = simd_min(min, corner)
        max = simd_max(max, corner)
    }

    public static func == (a: BoundingBox, b: BoundingBox) -> Bool {
        a.min == b.min && a.max == b.max
    }
}

// MARK: - AnchoringComponent

/// A component that makes the entity it is on an anchor, and says what the anchor is for.
@frozen public struct AnchoringComponent: Component, Equatable {
    /// What an entity is anchored to: a point in the world, a plane, a real-world object, or a
    /// target an AR session names.
    public enum Target: Hashable {
        /// Which of a plane's directions an anchor's alignment may choose.
        public struct Alignment: OptionSet, Hashable {
            public let rawValue: UInt8
            public init(rawValue: UInt8) { self.rawValue = rawValue }

            public static let horizontal = Alignment(rawValue: 1 << 0)
            public static let vertical = Alignment(rawValue: 1 << 1)
            public static let any: Alignment = [.horizontal, .vertical]
        }

        /// Which of the kinds of real-world surface an anchor may bind to.
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

        /// The camera's own frame of reference.
        case camera
        /// A fixed transform in the world.
        case world(transform: float4x4)
        /// A target an AR session of this device names by its identifier. A device with no AR
        /// session of its own has no target to name, and an anchor to it stays where it is.
        case anchor(identifier: UUID)
        /// A detected plane of the given classification, at least the given size in metres.
        case plane(Alignment, classification: Classification, minimumBounds: SIMD2<Float>)
        /// A feature the session has detected in an image.
        case image(group: String, name: String)
        /// A real-world object.
        case object(group: String, name: String)
        /// The user's face.
        case face
        /// The user's body.
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

    /// What the entity this component is on is anchored to.
    public let target: Target

    public init(_ target: Target) {
        self.target = target
    }

    public static func == (a: AnchoringComponent, b: AnchoringComponent) -> Bool {
        a.target == b.target
    }
}

// MARK: - AnchorEntity

/// An entity that is anchored to a target in the world, and that a scene roots.
@MainActor
open class AnchorEntity: Entity, HasAnchoring {
    public required init(_coreEntity: __EntityRef) {
        super.init(_coreEntity: _coreEntity)
    }

    /// The component that says what this entity is anchored to.
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

    /// The identifier of the target in an AR session this entity is anchored to, when the
    /// device has a session that names one. A device without one answers nil, which is what a
    /// device with no ARSession of its own does.
    public var anchorIdentifier: UUID? {
        if case .anchor(let identifier) = anchoring.target { return identifier }
        return nil
    }

    /// Whether a session still sees this anchor's target. An anchor to the world or to a plane
    /// is not something a session tracks, and says so rather than claiming to.
    public var isTracked: Bool = true

    public init(plane: AnchoringComponent.Target.Alignment,
                classification: AnchoringComponent.Target.Classification,
                minimumBounds: SIMD2<Float> = .zero) {
        super.init()
        name = "AnchorEntity(plane)"
        components[AnchoringComponent.self] = AnchoringComponent(.plane(plane, classification: classification,
                                                                        minimumBounds: minimumBounds))
    }

    /// Anchors this entity to `target` again. A device with no AR session of its own has no
    /// target to anchor to, and the entity keeps the one it has.
    public func reanchor(_ target: AnchoringComponent.Target, preservingWorldTransform: Bool = true) {
        anchoring = AnchoringComponent(target)
        if !preservingWorldTransform { transform = Transform() }
    }
}

// MARK: - SynchronizationComponent

/// A component every entity carries, and the one a synchronizing session owns: the identifier
/// its participants agree on and who among them may change it.
@frozen public struct SynchronizationComponent: Component, Equatable {
    /// Whether the ownership of the entity's synchronized state moves on its own or only when a
    /// participant asks for it.
    public enum OwnershipTransferMode: Hashable {
        case autoAccept
        case manual
    }

    /// How a request for ownership ended.
    public enum OwnershipTransferCompletionResult: Hashable {
        case granted
        case timedOut
    }

    /// The number the participants agree on.
    public let identifier: UInt64
    /// Whether this participant may change the synchronized state.
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
    /// The component that carries this entity's synchronized state, which every entity has.
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

    /// Whether this participant may change the entity's synchronized state.
    public var isOwner: Bool {
        synchronization?.isOwner ?? false
    }

    /// Asks for the ownership of the entity's synchronized state, answering when the request
    /// ended.
    ///
    /// Nothing on this device arbitrates between participants: a session does, and this port
    /// carries no session. A request made by a participant that already owns the state is
    /// granted at once, which is what the single-participant case is, and anything else times
    /// out rather than inventing an answer.
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

    /// Runs `changes` with the entity's synchronized state held, so that a session sends the
    /// change as one update. With no session there is nothing to hold, and the changes run.
    public func withUnsynchronized(_ changes: () -> Void) {
        changes()
    }
}

// MARK: - Scene

/// A container for the entities of a world, and the anchors they are rooted in.
@MainActor
open class Scene {
    /// A number that identifies this scene for the life of the process.
    public typealias ID = UInt64

    /// A reference to this scene's state.
    public var __coreScene: __SceneRef { __SceneRef(coreScene) }

    /// The scene's state. A renderer in another module - RealityKit's own view - reads and
    /// steps it, so it is public rather than internal.
    public let coreScene: __REScene

    public init(_coreScene: __SceneRef) {
        coreScene = _coreScene.scene
        if coreScene.wrapper == nil { coreScene.wrapper = self }
    }

    /// The name of the scene, which is what a serialized scene and a test name it by.
    public var name: String {
        get { coreScene.name }
        set { coreScene.name = newValue }
    }

    /// A number that identifies this scene for the life of the process.
    public var id: ID { coreScene.identifier }

    /// The view this scene is shown in, set by `ARView` when it puts the scene into its own.
    ///
    /// Weak on both sides' account: a view does not keep a scene alive, and a scene that outlived
    /// the view that showed it would keep a handle on a view whose camera and frame are gone. A
    /// scene with no view is a scene that is not shown, and the things that need a camera - a pixel
    /// cast, and nothing else this module has - answer nil for it, as the interface does for a scene
    /// that is not on screen.
    public weak var view: SCNView?

    /// The timebase the scene's time is read from: `CMTimebase`, CoreMedia's own, reached through
    /// the SDK's clang module because the port builds no CoreMedia overlay of its own.
    ///
    /// It is made on the first use, against the host clock, and kept: a timebase that were made and
    /// dropped on each read would jump back to the clock every time, and a scene that steps would
    /// lose the time it had accumulated. Apple's is a getter too (26.2:12118-12122), so there is no
    /// way to set a scene's timebase from outside, only to read the one it has.
    public var timebase: CMTimebase {
        if let existing = coreScene.timebase { return existing }
        var timebase: CMTimebase?
        // A timebase with no master clock of its own is still a timebase: it counts from zero, which
        // is what a scene that is stepped by its caller wants, and the host clock is what makes it
        // move on its own for a scene that is not.
        if CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault,
                                           masterClock: CMClockGetHostTimeClock(),
                                           timebaseOut: &timebase) == noErr, let made = timebase {
            coreScene.timebase = made
            return made
        }
        // CoreMedia would not give this scene a timebase of its own, so it shares the one that is
        // made once for the process. A timebase is a few kilobytes of CoreMedia state, and a second
        // failure here is the allocator failing, which is not something a scene can carry on with: it
        // is said so rather than handed a value that is not a timebase.
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

    // MARK: Anchors

    /// The anchors this scene roots. Setting the collection replaces them, and an anchor taken
    /// out of the collection is taken out of the scene with it.
    public var anchors: Scene.AnchorCollection {
        get { Scene.AnchorCollection(coreScene) }
        set { newValue.replaceAll(newValue) }
    }

    /// Roots `anchor` in this scene, taking it out of the scene it was in.
    public func addAnchor(_ anchor: any HasAnchoring) {
        coreScene.add(anchor: anchor.coreEntity)
    }

    /// Takes `anchor` out of this scene, whether or not it is one of its anchors.
    public func removeAnchor(_ anchor: any HasAnchoring) {
        coreScene.remove(anchor: anchor.coreEntity)
    }

    // MARK: Finding

    /// The first entity of this scene, its anchors and everything below them, with the given name.
    public func findEntity(named name: String) -> Entity? {
        coreScene.firstNode(named: name)?.entity
    }

    /// The entity of this scene with the given identifier, when there is one.
    public func findEntity(id: Entity.ID) -> Entity? {
        coreScene.node(withIdentifier: id)?.entity
    }

    // MARK: Identity

    public static func == (lhs: Scene, rhs: Scene) -> Bool {
        lhs.coreScene === rhs.coreScene
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(coreScene.identifier)
    }
}

extension Scene: Hashable {}

extension Scene: Identifiable {}

// MARK: - The anchor collection

extension Scene {
    /// The anchors of one scene, in the order they were added.
    @MainActor
    public struct AnchorCollection: Collection {
        public typealias Element = any HasAnchoring
        public typealias Index = Int
        public typealias Indices = DefaultIndices<AnchorCollection>
        public typealias SubSequence = Slice<AnchorCollection>

        /// The iterator of a collection whose indices are its positions; see
        /// `Entity.ChildCollection.IndexingIterator`.
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
    /// The anchors' own trees, one after another between brackets. Measured on the host
    /// (2026-09-27): two anchors print as `[` then the first anchor's `debugDescription`, then
    /// `,` and a line break and the second's, then a line break and `]`.
    public var description: String {
        "[" + map { $0.debugDescription }.joined(separator: ",\n") + "\n]"
    }
}

@MainActor
extension __REEntity {
    /// The component that says what this node is anchored to, which a renderer in another
    /// module needs to tell one anchor's target from another's. A node with no component is
    /// anchored to the world, which is what an anchor with nothing set means.
    public var anchoring: AnchoringComponent {
        component(of: AnchoringComponent.self)
            ?? AnchoringComponent(.world(transform: float4x4(diagonal: SIMD4<Float>(1, 1, 1, 1))))
    }

    /// Whether a session still sees this node's target, and whether the node is one it tracks.
    public var isTracked: Bool {
        get { tracked ?? true }
        set { tracked = newValue }
    }
}
