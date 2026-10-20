import simd
import Foundation

public protocol Event: Sendable {}

public protocol EventSource {}

public protocol Cancellable {
    func cancel()
}

public final class EventSubscriptionToken {
    public typealias Handler = (Any) -> Void
    let eventType: Any.Type
    let source: __REEntity?
    let componentType: Any.Type?
    let handler: Handler
    var isCancelled = false

    init(eventType: Any.Type, source: __REEntity?, componentType: Any.Type?, handler: @escaping Handler) {
        self.eventType = eventType
        self.source = source
        self.componentType = componentType
        self.handler = handler
    }

    public func cancel() { isCancelled = true }
}

extension EventSubscriptionToken: Cancellable {}

@MainActor
public final class __REEventBus {
    public static let shared = __REEventBus()

    private var tokens: [EventSubscriptionToken] = []

    public init() {}

    @discardableResult
    func add(_ token: EventSubscriptionToken) -> EventSubscriptionToken {
        tokens.append(token)
        return token
    }

    func post<E>(_ event: E, on source: __REEntity?, componentType: Any.Type?) {
        let wanted = E.self
        for token in tokens where !token.isCancelled {
            guard token.eventType == wanted else { continue }
            if let source, let tokenSource = token.source, tokenSource !== source { continue }
            if let componentType, let tokenComponent = token.componentType, tokenComponent != componentType { continue }
            token.handler(event)
        }
        tokens.removeAll { $0.isCancelled }
    }
}

public enum CollisionEvents {
    public struct Began: Event {
        public let entityA: Entity
        public let entityB: Entity
        public let position: SIMD3<Float>
        public let impulse: Float
    }

    public struct Updated: Event {
        public let entityA: Entity
        public let entityB: Entity
        public let position: SIMD3<Float>
        public let impulse: Float
    }

    public struct Ended: Event {
        public let entityA: Entity
        public let entityB: Entity
    }
}

@MainActor
extension Scene {
    public func subscribe<E>(to event: E.Type, on sourceObject: (any EventSource)? = nil,
                             componentType: (any Component.Type)? = nil,
                             _ handler: @escaping (E) -> Void) -> any Cancellable where E: Event {
        let source = (sourceObject as? Entity)?.coreEntity
        let token = EventSubscriptionToken(eventType: event, source: source, componentType: componentType) { value in
            if let event = value as? E { handler(event) }
        }
        return __REEventBus.shared.add(token)
    }

    public func subscribe<E>(to event: E.Type, on sourceObject: (any EventSource)? = nil,
                             _ handler: @escaping (E) -> Void) -> any Cancellable where E: Event {
        subscribe(to: event, on: sourceObject, componentType: nil, handler)
    }
}

@MainActor
extension Entity {
    public func subscribe<E>(to event: E.Type, componentType: (any Component.Type)? = nil,
                             _ handler: @escaping (E) -> Void) -> any Cancellable where E: Event {
        scene?.subscribe(to: event, on: self, componentType: componentType, handler)
            ?? EventSubscriptionToken(eventType: event, source: coreEntity, componentType: componentType) { _ in }
    }
}

@MainActor
public struct CollisionCastHit: Equatable {
    public var entity: Entity
    public var position: SIMD3<Float>
    public var normal: SIMD3<Float>
    public var distance: Float

    public init(entity: Entity, position: SIMD3<Float>, normal: SIMD3<Float>, distance: Float) {
        self.entity = entity
        self.position = position
        self.normal = normal
        self.distance = distance
    }

    public static func == (a: CollisionCastHit, b: CollisionCastHit) -> Bool {
        a.entity == b.entity && a.position == b.position && a.normal == b.normal && a.distance == b.distance
    }
}

public enum CollisionCastQueryType: Hashable {
    case all
    case trigger
    case `default`
}

@MainActor
func __reApplyPoint(_ matrix: float4x4, _ point: SIMD3<Float>) -> SIMD3<Float> {
    __reApply(matrix, point, asPoint: true)
}

@MainActor
func __reApplyDirection(_ matrix: float4x4, _ direction: SIMD3<Float>) -> SIMD3<Float> {
    __reApply(matrix, direction, asPoint: false)
}

@MainActor
func __reCastDirection(_ direction: SIMD3<Float>, length: Float) -> SIMD3<Float> {
    let magnitude = simd_length(direction)
    guard magnitude > 0 else { return .zero }
    return direction / magnitude * length
}

@MainActor
func __reInvert(_ matrix: float4x4) -> float4x4 { matrix.inverted }

enum Slab {
    static func hit(origin: SIMD3<Float>, direction: SIMD3<Float>, halfExtents: SIMD3<Float>) -> (distance: Float, normal: SIMD3<Float>)? {
        var tEnter: Float = -.infinity
        var tLeave: Float = .infinity
        var axis = 0
        var sign: Float = 1
        for component in 0..<3 {
            let o = component == 0 ? origin.x : (component == 1 ? origin.y : origin.z)
            let d = component == 0 ? direction.x : (component == 1 ? direction.y : direction.z)
            let h = component == 0 ? halfExtents.x : (component == 1 ? halfExtents.y : halfExtents.z)
            if abs(d) < 1e-8 {
                if o < -h || o > h { return nil }
                continue
            }
            let inverse = 1 / d
            var near = (-h - o) * inverse
            var far = (h - o) * inverse
            var nearSign: Float = 1
            if near > far { swap(&near, &far); nearSign = -1 }
            if near > tEnter { tEnter = near; axis = component; sign = nearSign }
            if far < tLeave { tLeave = far }
            if tEnter > tLeave { return nil }
        }
        if tLeave < 0 { return nil }
        var normal = SIMD3<Float>(repeating: 0)
        switch axis {
        case 0: normal.x = -sign
        case 1: normal.y = -sign
        default: normal.z = -sign
        }
        return (Swift.max(tEnter, 0), normal)
    }
}

@MainActor
extension Scene {
    public func raycast(from startPosition: SIMD3<Float>, to endPosition: SIMD3<Float>,
                        query: CollisionCastQueryType = .all, mask: CollisionGroup = .all,
                        relativeTo referenceEntity: Entity? = nil) -> [CollisionCastHit] {
        let offset = endPosition - startPosition
        return raycast(origin: startPosition, direction: offset, length: simd_length(offset), query: query,
                       mask: mask, relativeTo: referenceEntity)
    }

    public func raycast(origin: SIMD3<Float>, direction: SIMD3<Float>, length: Float = 100,
                        query: CollisionCastQueryType = .all, mask: CollisionGroup = .all,
                        relativeTo referenceEntity: Entity? = nil) -> [CollisionCastHit] {
        let step = __reCastDirection(direction, length: length)
        var hits: [CollisionCastHit] = []
        for node in coreScene.nodes {
            guard node.isEnabledInHierarchy, let collision = node.component(of: CollisionComponent.self) else { continue }
            if query == .trigger && collision.mode == .default { continue }
            if query == .default && collision.mode == .trigger { continue }
            if !mask.contains(collision.filter.group) && collision.filter.group != .all { continue }
            let toEntity = referenceEntity.map { node.transformMatrix(relativeTo: $0.coreEntity) } ?? node.transformMatrixInHierarchy
            let local = __reInvert(toEntity)
            let localOrigin = __reApplyPoint(local, origin)
            let localDirection = __reApplyDirection(local, step)
            for shape in collision.shapes {
                guard let hit = Slab.hit(origin: localOrigin, direction: localDirection,
                                         halfExtents: shape.shape.bounds.extents / 2) else { continue }
                let world = __reApplyPoint(toEntity, localOrigin + localDirection * hit.distance)
                let worldNormal = __reApplyDirection(toEntity, hit.normal)
                hits.append(CollisionCastHit(entity: node.entity, position: world, normal: worldNormal,
                                             distance: simd_length(world - origin)))
                break
            }
        }
        return hits.sorted { $0.distance < $1.distance }
    }

    public func convexCast(convexShape: ShapeResource, fromPosition: SIMD3<Float>,
                           fromOrientation: simd_quatf, toPosition: SIMD3<Float>, toOrientation: simd_quatf,
                           query: CollisionCastQueryType = .all, mask: CollisionGroup = .all,
                           relativeTo referenceEntity: Entity? = nil) -> [CollisionCastHit] {
        raycast(from: fromPosition, to: toPosition, query: query, mask: mask, relativeTo: referenceEntity)
            .filter { $0.entity !== convexShape }
    }
}

@MainActor
struct __REBody {
    let node: __REEntity
    let mode: PhysicsBodyMode
    let mass: Float
    let inverseMass: Float
    let inertia: SIMD3<Float>
    let inverseInertia: SIMD3<Float>
    let lockedTranslation: (x: Bool, y: Bool, z: Bool)
    let lockedRotation: (x: Bool, y: Bool, z: Bool)
    let affectedByGravity: Bool
    let linearDamping: Float
    let restitution: Float
    var linearVelocity: SIMD3<Float>
    var angularVelocity: SIMD3<Float>
}

@MainActor
extension __REScene {
    var bodies: [__REBody] {
        var found: [__REBody] = []
        for node in nodes {
            guard let body = node.component(of: PhysicsBodyComponent.self) else { continue }
            let motion = node.component(of: PhysicsMotionComponent.self) ?? PhysicsMotionComponent()
            let dynamic = body.mode == .dynamic
            found.append(__REBody(node: node, mode: body.mode, mass: body.massProperties.mass,
                                  inverseMass: dynamic && body.massProperties.mass > 0 ? 1 / body.massProperties.mass : 0,
                                  inertia: body.massProperties.inertia,
                                  inverseInertia: dynamic ? 1 / body.massProperties.inertia : .zero,
                                  lockedTranslation: body.isTranslationLocked,
                                  lockedRotation: body.isRotationLocked,
                                  affectedByGravity: body.isAffectedByGravity,
                                  linearDamping: body.linearDamping,
                                  restitution: body.material?.__restitution ?? 0,
                                  linearVelocity: motion.linearVelocity,
                                  angularVelocity: motion.angularVelocity))
        }
        return found
    }

    public func __advancePhysics(deltaTime: TimeInterval) {
        let step = 1.0 / 60.0
        var count = deltaTime / TimeInterval(step)
        count = count < 0 ? 0 : (count > 512 ? 512 : count)
        for _ in 0..<Int(count.rounded(.down)) {
            __step(Float(step))
        }
    }

    func __step(_ dt: Float) {
        nodes.forEach { $0.__advanceAnimations(TimeInterval(dt)) }
        nodes.forEach { __solveInverseKinematics(of: $0) }
        var bodies = self.bodies
        guard !bodies.isEmpty else { return }
        let gravity = SIMD3<Float>(0, -9.81, 0)

        for index in bodies.indices where bodies[index].mode == .dynamic {
            if bodies[index].affectedByGravity {
                let locked = bodies[index].lockedTranslation
                bodies[index].linearVelocity += SIMD3<Float>(locked.x ? 0 : gravity.x,
                                                             locked.y ? 0 : gravity.y,
                                                             locked.z ? 0 : gravity.z) * dt
            }
            if bodies[index].linearDamping > 0 {
                let keep = Swift.max(0, 1 - bodies[index].linearDamping * dt)
                bodies[index].linearVelocity *= keep
                bodies[index].angularVelocity *= keep
            }
        }

        for index in bodies.indices {
            let body = bodies[index]
            if body.mode == .static { continue }
            let locked = body.lockedTranslation
            let step = SIMD3<Float>(locked.x ? 0 : body.linearVelocity.x,
                                    locked.y ? 0 : body.linearVelocity.y,
                                    locked.z ? 0 : body.linearVelocity.z)
            let moved = body.node.transform
            var next = moved
            next.translation += step * dt
            if simd_length(body.angularVelocity) > 0 {
                let angle = simd_length(body.angularVelocity) * dt
                let axis = simd_normalize(body.angularVelocity)
                next.rotation = simd_quatf(angle: angle, axis: axis) * moved.rotation
            }
            body.node.transform = next
            bodies[index].linearVelocity = step
        }

        let previous = collisions ?? []
        var touching: Set<String> = []
        for first in 0..<bodies.count {
            for second in (first + 1)..<bodies.count {
                if bodies[first].mode == .static && bodies[second].mode == .static { continue }
                let firstNode = bodies[first].node, secondNode = bodies[second].node
                guard let contact = __reContact(of: firstNode, with: secondNode) else { continue }
                let key = "\(firstNode.identifier)-\(secondNode.identifier)"
                let was = previous.contains(key)
                touching.insert(key)
                var left = bodies[first]
                var right = bodies[second]
                if left.mode == .dynamic || right.mode == .dynamic {
                    __reResolve(&left, &right, contact)
                    bodies[first] = left
                    bodies[second] = right
                }
                if firstNode.isEnabledInHierarchy && secondNode.isEnabledInHierarchy {
                    if !was {
                        __REEventBus.shared.post(CollisionEvents.Began(entityA: firstNode.entity, entityB: secondNode.entity,
                                                                        position: contact.position, impulse: contact.impulse),
                                                  on: firstNode, componentType: nil)
                    } else {
                        __REEventBus.shared.post(CollisionEvents.Updated(entityA: firstNode.entity, entityB: secondNode.entity,
                                                                          position: contact.position, impulse: contact.impulse),
                                                  on: firstNode, componentType: nil)
                    }
                }
            }
        }
        let current = touching
        if let previous = collisions {
            for pair in previous.subtracting(current) {
                let parts = pair.split(separator: "-").compactMap { UInt64($0) }
                if parts.count == 2,
                   let a = node(withIdentifier: parts[0]), let b = node(withIdentifier: parts[1]) {
                    __REEventBus.shared.post(CollisionEvents.Ended(entityA: a.entity, entityB: b.entity), on: a, componentType: nil)
                }
            }
        }
        collisions = current

        for body in bodies where body.mode != .static {
            body.node.setComponent(PhysicsMotionComponent(linearVelocity: body.linearVelocity,
                                                           angularVelocity: body.angularVelocity))
        }
    }

}

struct __REContact {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var depth: Float
    var impulse: Float
}

@MainActor
func __reContact(of a: __REEntity, with b: __REEntity) -> __REContact? {
    guard let first = a.component(of: CollisionComponent.self), let second = b.component(of: CollisionComponent.self) else { return nil }
    for shapeA in first.shapes {
        let boxA = __reWorldBox(of: a, shape: shapeA)
        for shapeB in second.shapes {
            let boxB = __reWorldBox(of: b, shape: shapeB)
            guard let overlap = __reOverlaps(boxA, boxB) else { continue }
            return overlap
        }
    }
    return nil
}

@MainActor
func __reWorldBox(of node: __REEntity, shape: ShapeResource) -> [SIMD3<Float>] {
    let matrix = node.transformMatrixInHierarchy
    return shape.shape.bounds.corners.map { __reApplyPoint(matrix, $0 + shape.offsetTranslation) }
}

@MainActor
func __reOverlaps(_ a: [SIMD3<Float>], _ b: [SIMD3<Float>]) -> __REContact? {
    let centreA = __reCentroid(a), centreB = __reCentroid(b)
    let axesA = __reEdges(of: a), axesB = __reEdges(of: b)
    let slop: Float = 1e-4
    var least: Float = .infinity
    var leastAxis = SIMD3<Float>(0, 1, 0)
    let candidates: [SIMD3<Float>] = axesA + axesB + __reCross(axesA, axesB)
    for axis in candidates where simd_length(axis) > 1e-6 {
        let direction = simd_normalize(axis)
        let (aMin, aMax) = __reProject(a, onto: direction)
        let (bMin, bMax) = __reProject(b, onto: direction)
        let overlap = Swift.min(aMax, bMax) - Swift.max(aMin, bMin)
        if overlap < -slop { return nil }
        if overlap < least {
            least = overlap
            let alongA = simd_dot(centreA, direction)
            let alongB = simd_dot(centreB, direction)
            leastAxis = alongA <= alongB ? -direction : direction
        }
    }
    let position = (centreA + centreB) / 2
    let depth = Swift.max(least, 0)
    return __REContact(position: position, normal: leastAxis, depth: depth, impulse: depth)
}

@MainActor
private func __reCentroid(_ corners: [SIMD3<Float>]) -> SIMD3<Float> {
    guard !corners.isEmpty else { return .zero }
    var total = SIMD3<Float>(repeating: 0)
    for corner in corners { total += corner }
    return total / Float(corners.count)
}

@MainActor
private func __reEdges(of corners: [SIMD3<Float>]) -> [SIMD3<Float>] {
    guard corners.count >= 5 else { return [] }
    let first = simd_normalize(corners[1] - corners[0])
    let second = simd_normalize(corners[4] - corners[0])
    guard simd_length(first) > 0, simd_length(second) > 0 else { return [] }
    return [first, second, simd_normalize(simd_cross(first, second))]
}

@MainActor
private func __reCross(_ a: [SIMD3<Float>], _ b: [SIMD3<Float>]) -> [SIMD3<Float>] {
    var out: [SIMD3<Float>] = []
    for first in a {
        for second in b {
            let crossed = simd_cross(first, second)
            if simd_length(crossed) > 1e-6 { out.append(crossed) }
        }
    }
    return out
}

@MainActor
private func __reProject(_ corners: [SIMD3<Float>], onto direction: SIMD3<Float>) -> (Float, Float) {
    var low = Float.infinity, high = -Float.infinity
    for corner in corners {
        let along = simd_dot(corner, direction)
        low = Swift.min(low, along)
        high = Swift.max(high, along)
    }
    return (low, high)
}

@MainActor
private func __reResolve(_ a: inout __REBody, _ b: inout __REBody, _ contact: __REContact) {
    guard contact.normal != .zero else { return }
    let total = a.inverseMass + b.inverseMass
    guard total > 0 else { return }
    let relative = simd_dot(b.linearVelocity - a.linearVelocity, contact.normal)
    let restitution = Swift.max(a.restitution, b.restitution)
    let impulse = -(1 + restitution) * relative / total
    a.linearVelocity -= contact.normal * (impulse * a.inverseMass)
    b.linearVelocity += contact.normal * (impulse * b.inverseMass)
    let correction = contact.normal * (contact.depth / total)
    if a.mode != .static { a.node.transform.translation += correction * a.inverseMass }
    if b.mode != .static { b.node.transform.translation -= correction * b.inverseMass }
}
