import UIKit
import _SwiftRevenantUIKitOverlayShims

@available(iOS 13.4, *)
public typealias UIPointerEffect = __UIPointerEffect

@available(iOS 13.4, *)
public enum UIPointerShape {
    case path(UIBezierPath)
    case roundedRect(CGRect, radius: CGFloat = UIPointerShape.defaultCornerRadius)
    case verticalBeam(length: CGFloat)
    case horizontalBeam(length: CGFloat)

    public static let defaultCornerRadius: CGFloat = .leastNormalMagnitude

    fileprivate var objectiveC: __UIPointerShape {
        let shape: __UIPointerShape?
        switch self {
        case let .path(path):
            shape = revenantPointerShape(path: path)
        case let .roundedRect(rect, radius):
            shape = revenantPointerShape(roundedRect: rect, cornerRadius: radius)
        case let .verticalBeam(length):
            shape = revenantPointerShape(beamWithPreferredLength: length, axis: .vertical)
        case let .horizontalBeam(length):
            shape = revenantPointerShape(beamWithPreferredLength: length, axis: .horizontal)
        }
        guard let object = shape else {
            preconditionFailure("UIPointerShape is not on this iOS, and the Backports that provide it are not linked")
        }
        return object
    }
}

@available(iOS 13.4, *)
extension UIPointerStyle {
    public convenience init(effect: UIPointerEffect, shape: UIPointerShape? = nil) {
        self.init(__effect: effect, shape: shape?.objectiveC)
    }

    public convenience init(shape: UIPointerShape, constrainedAxes: UIAxis = []) {
        self.init(revenantShape: shape.objectiveC, constrainedAxes: constrainedAxes)
    }
}
