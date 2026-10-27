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
        switch self {
        case let .path(path):
            return __UIPointerShape(path: path)
        case let .roundedRect(rect, radius):
            return __UIPointerShape(roundedRect: rect, cornerRadius: radius)
        case let .verticalBeam(length):
            return __UIPointerShape.beam(withPreferredLength: length, axis: .vertical)
        case let .horizontalBeam(length):
            return __UIPointerShape.beam(withPreferredLength: length, axis: .horizontal)
        }
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
