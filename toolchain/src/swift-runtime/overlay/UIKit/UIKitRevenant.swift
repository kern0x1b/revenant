import UIKit
import _SwiftRevenantUIKitOverlayShims

extension UIAction {
    public convenience init(title: String = "", image: UIImage? = nil, identifier: UIAction.Identifier? = nil,
                            discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [],
                            state: UIMenuElement.State = .off, handler: @escaping UIActionHandler) {
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, handler: handler)
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }
}

extension UIMenu {
    public convenience init(title: String = "", image: UIImage? = nil, identifier: UIMenu.Identifier? = nil,
                            options: UIMenu.Options = [], children: [UIMenuElement] = []) {
        let objects: [AnyObject] = children.map { $0 as AnyObject }
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, options: options, children: objects)
    }
}

extension UITraitChangeObservable {
    @discardableResult
    public func registerForTraitChanges<Observer: UITraitEnvironment>(_ traits: [UITrait], handler: @escaping (Observer, UITraitCollection) -> Void) -> any UITraitChangeRegistration {
        registerForTraitChanges(traits, handler: { (environment: any UITraitEnvironment, previous: UITraitCollection) in
            if let observer = environment as? Observer {
                handler(observer, previous)
            }
        })
    }
}

@available(iOS 26.0, *)
extension UIView {
    public var cornerConfiguration: UICornerConfiguration {
        get { __cornerConfiguration }
        set { __cornerConfiguration = newValue }
    }
}


@available(iOS 26.0, *)
public struct UICornerRadius: Equatable, Hashable {
    private let fixedValue: Double

    public static func fixed(_ radius: Double) -> UICornerRadius {
        UICornerRadius(fixedValue: radius)
    }
}

@available(iOS 26.0, *)
public typealias UICornerConfiguration = __UICornerConfiguration

@available(iOS 26.0, *)
extension UICornerConfiguration {
    public static func corners(topLeftRadius: UICornerRadius, topRightRadius: UICornerRadius, bottomLeftRadius: UICornerRadius, bottomRightRadius: UICornerRadius) -> UICornerConfiguration {
        preconditionFailure("UICornerConfiguration.corners(...) has no backing: per-corner radii need CAShapeLayer-mask backing")
    }
}
