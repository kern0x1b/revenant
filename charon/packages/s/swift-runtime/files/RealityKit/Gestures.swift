// The gestures an entity answers: it can be moved, turned and scaled by a touch.
//
// The SDK's own recognizers are `UIGestureRecognizer` subclasses that ask the renderer where
// the touch landed; these are the same three, driving the entity's own transform, so that a
// program's answer does not depend on a renderer being present to hit-test the touch.

// The arithmetic below is the entity's own and needs no UIKit, so these two are imported
// outside the guard: with them inside it, the guard closed at the end of the recognizers and
// left the arithmetic without the module that names Entity, and the module failed to build on
// every host without UIKit - the one platform the host differential runs on.
import simd
import RealityFoundation

#if canImport(UIKit)
import UIKit

/// A gesture that acts on one entity.
@MainActor
public protocol EntityGestureRecognizer: AnyObject {
    /// The entity the gesture moves.
    var entity: Entity { get }
    /// The recognizer itself, which a caller adds to a view and takes away again.
    var recognizer: UIGestureRecognizer { get }
}

/// Moves an entity under the touch.
@MainActor
open class EntityTranslationGestureRecognizer: UIPanGestureRecognizer, EntityGestureRecognizer {
    public let entity: Entity
    /// Where the entity was when the gesture began, which every change is measured from.
    public private(set) var initialPosition: SIMD3<Float>

    public init(entity: any HasCollision) {
        self.entity = (entity as? Entity) ?? AnchorEntity()
        initialPosition = self.entity.position
        super.init(target: nil, action: nil)
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        initialPosition = entity.position
        translation = .zero
    }

    /// How far the entity has been dragged, in the view's own units.
    public private(set) var translation: CGPoint = .zero

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        translation = touch.location(in: nil)
        entity.position = initialPosition + SIMD3<Float>(x: Float(translation.x),
                                                          y: Float(translation.y),
                                                          z: 0)
    }

    public var recognizer: UIGestureRecognizer { self }
}

/// Turns an entity under a two-finger rotation.
@MainActor
open class EntityRotationGestureRecognizer: UIRotationGestureRecognizer, EntityGestureRecognizer {
    public let entity: Entity
    /// The orientation the entity had when the gesture began.
    public private(set) var initialOrientation: simd_quatf

    public init(entity: any HasCollision) {
        self.entity = (entity as? Entity) ?? AnchorEntity()
        initialOrientation = self.entity.orientation
        super.init(target: nil, action: nil)
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        initialOrientation = entity.orientation
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        EntityGesture.rotate(entity, from: initialOrientation, by: Float(rotation))
    }

    public var recognizer: UIGestureRecognizer { self }
}

/// Scales an entity under a pinch.
@MainActor
open class EntityScaleGestureRecognizer: UIPinchGestureRecognizer, EntityGestureRecognizer {
    public let entity: Entity
    /// The scale the entity had when the gesture began.
    public private(set) var initialScale: SIMD3<Float>

    public init(entity: any HasCollision) {
        self.entity = (entity as? Entity) ?? AnchorEntity()
        initialScale = self.entity.scale
        super.init(target: nil, action: nil)
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        initialScale = entity.scale
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        EntityGesture.scale(entity, from: initialScale, by: Float(scale))
    }

    public var recognizer: UIGestureRecognizer { self }
}
#endif

// MARK: - The gesture arithmetic

/// What a gesture does to an entity, as a function of its own value.
///
/// The three are kept apart from their recognizers so that the arithmetic can be asked
/// without a touch, which is what the host differential does: a recognizer calls these with what
/// its own gesture reports, and nothing else.
@MainActor
public enum EntityGesture {
    /// Moves an entity by a drag, in the view's own units, without moving it in depth.
    public static func translate(_ entity: Entity, from initial: SIMD3<Float>,
                                 by delta: SIMD2<Float>) {
        entity.position = initial + SIMD3<Float>(x: delta.x, y: delta.y, z: 0)
    }

    /// Turns an entity about the screen's own axis, which is the camera's z, from where it was
    /// when the gesture began.
    public static func rotate(_ entity: Entity, from initial: simd_quatf, by radians: Float) {
        entity.orientation = simd_quatf(angle: radians, axis: SIMD3<Float>(0, 0, 1)) * initial
    }

    /// Scales an entity by a pinch, about the scale it had when the gesture began, so that a
    /// pinch out and back leaves it where it was.
    public static func scale(_ entity: Entity, from initial: SIMD3<Float>, by factor: Float) {
        entity.scale = initial * SIMD3<Float>(repeating: factor)
    }
}
