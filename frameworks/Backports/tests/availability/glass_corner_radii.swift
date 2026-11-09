import UIKit

enum GlassCornerRadiiUse {
    static func apply(_ view: UIVisualEffectView, topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        if #available(iOS 26.0, tvOS 26.0, macOS 26.0, *) {
            let topLeftRadius = UICornerRadius(floatLiteral: topLeft)
            let topRightRadius = UICornerRadius(floatLiteral: topRight)
            let bottomLeftRadius = UICornerRadius(floatLiteral: bottomLeft)
            let bottomRightRadius = UICornerRadius(floatLiteral: bottomRight)

            view.cornerConfiguration = .corners(
                topLeftRadius: topLeftRadius,
                topRightRadius: topRightRadius,
                bottomLeftRadius: bottomLeftRadius,
                bottomRightRadius: bottomRightRadius
            )
        }
    }
}
