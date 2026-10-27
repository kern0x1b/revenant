import UIKit

@available(iOS 13.4, *)
func pointerStyles(for view: UIView, path: UIBezierPath, rect: CGRect) -> [UIPointerStyle] {
    let preview = UITargetedPreview(view: view)
    return [
        UIPointerStyle(effect: .highlight(preview), shape: .roundedRect(rect, radius: UIPointerShape.defaultCornerRadius)),
        UIPointerStyle(effect: .highlight(preview), shape: .path(path)),
        UIPointerStyle(effect: .hover(preview, preferredTintMode: .none, prefersShadow: false, prefersScaledContent: false)),
        UIPointerStyle(effect: .lift(preview)),
        UIPointerStyle(shape: .verticalBeam(length: 24.0), constrainedAxes: .vertical),
        UIPointerStyle(shape: .horizontalBeam(length: rect.width), constrainedAxes: .horizontal),
    ]
}

@available(iOS 13.4, *)
func defaultRadiusIsLeastNormal() -> Bool {
    return UIPointerShape.defaultCornerRadius == CGFloat.leastNormalMagnitude
}

func frameRateRange(_ link: CADisplayLink, _ animation: CAAnimation) -> Bool {
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: 120.0, preferred: 120.0)
    animation.preferredFrameRateRange = .default
    return link.preferredFrameRateRange != .default
}

func underlineIsPatternDot(_ value: Int) -> Bool {
    return value == NSUnderlineStyle.patternDot.rawValue
}
