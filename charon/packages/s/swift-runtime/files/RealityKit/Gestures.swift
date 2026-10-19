import simd
import RealityFoundation

#if canImport(UIKit)
import UIKit

@MainActor
public protocol EntityGestureRecognizer: AnyObject {
    var entity: Entity { get }
    var recognizer: UIGestureRecognizer { get }
}

@MainActor
open class EntityTranslationGestureRecognizer: UIPanGestureRecognizer, EntityGestureRecognizer {
    public let entity: Entity
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

@MainActor
open class EntityRotationGestureRecognizer: UIRotationGestureRecognizer, EntityGestureRecognizer {
    public let entity: Entity
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

@MainActor
open class EntityScaleGestureRecognizer: UIPinchGestureRecognizer, EntityGestureRecognizer {
    public let entity: Entity
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

@MainActor
public enum EntityGesture {
    public static func translate(_ entity: Entity, from initial: SIMD3<Float>,
                                 by delta: SIMD2<Float>) {
        entity.position = initial + SIMD3<Float>(x: delta.x, y: delta.y, z: 0)
    }

    public static func rotate(_ entity: Entity, from initial: simd_quatf, by radians: Float) {
        entity.orientation = simd_quatf(angle: radians, axis: SIMD3<Float>(0, 0, 1)) * initial
    }

    public static func scale(_ entity: Entity, from initial: SIMD3<Float>, by factor: Float) {
        entity.scale = initial * SIMD3<Float>(repeating: factor)
    }
}
