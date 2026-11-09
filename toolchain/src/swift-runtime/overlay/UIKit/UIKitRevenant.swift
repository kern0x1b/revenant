import UIKit
import _SwiftRevenantUIKitOverlayShims

extension UIAction {
    @_disfavoredOverload
    public convenience init(title: String = "", image: UIImage? = nil, identifier: UIAction.Identifier? = nil,
                            discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [],
                            state: UIMenuElement.State = .off, handler: @escaping UIActionHandler) {
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, handler: handler)
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }

    @_disfavoredOverload
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: UIAction.Identifier? = nil,
                            discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [],
                            state: UIMenuElement.State = .off, handler: @escaping UIActionHandler) {
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, handler: handler)
        self.subtitle = subtitle
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }

    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, selectedImage: UIImage? = nil,
                            identifier: UIAction.Identifier? = nil, discoverabilityTitle: String? = nil,
                            attributes: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off,
                            handler: @escaping UIActionHandler) {
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, handler: handler)
        self.subtitle = subtitle
        self.revenantSelectedImage = selectedImage
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }
}

extension UICommand {
    @_disfavoredOverload
    public convenience init(title: String = "", image: UIImage? = nil, action: Selector, propertyList: Any? = nil,
                            alternates: [UICommandAlternate] = [], discoverabilityTitle: String? = nil,
                            attributes: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off) {
        self.init(revenantTitle: title, image: image, action: action, propertyList: propertyList,
                  alternates: alternates.map { $0 as AnyObject })
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }

    @_disfavoredOverload
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, action: Selector,
                            propertyList: Any? = nil, alternates: [UICommandAlternate] = [], discoverabilityTitle: String? = nil,
                            attributes: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off) {
        self.init(revenantTitle: title, image: image, action: action, propertyList: propertyList,
                  alternates: alternates.map { $0 as AnyObject })
        self.subtitle = subtitle
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }

    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, selectedImage: UIImage? = nil,
                            action: Selector, propertyList: Any? = nil, alternates: [UICommandAlternate] = [],
                            discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [],
                            state: UIMenuElement.State = .off) {
        self.init(revenantTitle: title, image: image, action: action, propertyList: propertyList,
                  alternates: alternates.map { $0 as AnyObject })
        self.subtitle = subtitle
        self.revenantSelectedImage = selectedImage
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }
}

extension UIKeyCommand {
    public convenience init(title: String = "", image: UIImage? = nil, action: Selector, input: String,
                            modifierFlags: UIKeyModifierFlags = [], propertyList: Any? = nil,
                            alternates: [UICommandAlternate] = [], discoverabilityTitle: String? = nil,
                            attributes: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off) {
        self.init(revenantTitle: title, image: image, action: action, input: input, modifierFlags: modifierFlags,
                  propertyList: propertyList,
                  alternates: alternates.map { $0 as AnyObject })
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
    }
}

extension UIMenu {
    @_disfavoredOverload
    public convenience init(title: String = "", image: UIImage? = nil, identifier: UIMenu.Identifier? = nil,
                            options: UIMenu.Options = [], children: [UIMenuElement] = []) {
        let objects: [AnyObject] = children.map { $0 as AnyObject }
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, options: options, children: objects)
    }

    @_disfavoredOverload
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil,
                            identifier: UIMenu.Identifier? = nil, options: UIMenu.Options = [],
                            children: [UIMenuElement] = []) {
        let objects: [AnyObject] = children.map { $0 as AnyObject }
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, options: options, children: objects)
        self.subtitle = subtitle
    }

    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil,
                            identifier: UIMenu.Identifier? = nil, options: UIMenu.Options = [],
                            preferredElementSize: UIMenu.ElementSize = .automatic, children: [UIMenuElement] = []) {
        let objects: [AnyObject] = children.map { $0 as AnyObject }
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, options: options, children: objects)
        self.subtitle = subtitle
        self.preferredElementSize = preferredElementSize
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

extension UIView {
    public var cornerConfiguration: UICornerConfiguration {
        get { __cornerConfiguration }
        set { __cornerConfiguration = newValue }
    }
}

public struct UICornerRadius: Equatable, Hashable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, CustomStringConvertible {
    fileprivate enum Kind: Hashable {
        case fixed(Double)
        case containerConcentric(minimum: CGFloat?)
    }

    fileprivate let kind: Kind

    public static func fixed(_ radius: Double) -> UICornerRadius {
        UICornerRadius(kind: .fixed(radius))
    }

    public static func containerConcentric(minimum: CGFloat? = nil) -> UICornerRadius {
        UICornerRadius(kind: .containerConcentric(minimum: minimum))
    }

    public init(floatLiteral value: Double) {
        self.init(kind: .fixed(value))
    }

    public init(integerLiteral value: Int) {
        self.init(kind: .fixed(Double(value)))
    }

    fileprivate init(kind: Kind) {
        self.kind = kind
    }

    public var description: String {
        switch kind {
        case let .fixed(radius):
            return "fixed(\(radius))"
        case let .containerConcentric(minimum):
            return minimum.map { "containerConcentric(minimum: \($0))" } ?? "containerConcentric()"
        }
    }

    fileprivate var objectiveC: __UICornerRadius {
        let radius: __UICornerRadius?
        switch kind {
        case let .fixed(value):
            radius = revenantCornerRadius(fixed: CGFloat(value))
        case let .containerConcentric(minimum?):
            radius = revenantCornerRadius(containerConcentricMinimum: minimum)
        case .containerConcentric(nil):
            radius = revenantCornerRadiusContainerConcentric()
        }
        guard let radius else {
            preconditionFailure("UICornerRadius is not on this iOS, and the Backports that provide it are not linked")
        }
        return radius
    }
}

public typealias UICornerConfiguration = __UICornerConfiguration

extension UICornerConfiguration {
    public static func corners(radius: UICornerRadius) -> UICornerConfiguration {
        corners(radius: radius.objectiveC)
    }

    public static func corners(topLeftRadius: UICornerRadius?, topRightRadius: UICornerRadius?, bottomLeftRadius: UICornerRadius?, bottomRightRadius: UICornerRadius?) -> UICornerConfiguration {
        corners(topLeftRadius: topLeftRadius?.objectiveC, topRightRadius: topRightRadius?.objectiveC,
                bottomLeftRadius: bottomLeftRadius?.objectiveC, bottomRightRadius: bottomRightRadius?.objectiveC)
    }

    public static func uniformCorners(radius: UICornerRadius) -> UICornerConfiguration {
        uniformCorners(radius: radius.objectiveC)
    }

    public static func uniformEdges(topRadius: UICornerRadius, bottomRadius: UICornerRadius) -> UICornerConfiguration {
        uniformEdges(topRadius: topRadius.objectiveC, bottomRadius: bottomRadius.objectiveC)
    }

    public static func uniformEdges(leftRadius: UICornerRadius, rightRadius: UICornerRadius) -> UICornerConfiguration {
        uniformEdges(leftRadius: leftRadius.objectiveC, rightRadius: rightRadius.objectiveC)
    }

    public static func uniformTopRadius(_ topRadius: UICornerRadius, bottomLeftRadius: UICornerRadius? = nil, bottomRightRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        uniformTopRadius(topRadius.objectiveC, bottomLeftRadius: bottomLeftRadius?.objectiveC, bottomRightRadius: bottomRightRadius?.objectiveC)
    }

    public static func uniformBottomRadius(_ bottomRadius: UICornerRadius, topLeftRadius: UICornerRadius? = nil, topRightRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        uniformBottomRadius(bottomRadius.objectiveC, topLeftRadius: topLeftRadius?.objectiveC, topRightRadius: topRightRadius?.objectiveC)
    }

    public static func uniformLeftRadius(_ leftRadius: UICornerRadius, topRightRadius: UICornerRadius? = nil, bottomRightRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        uniformLeftRadius(leftRadius.objectiveC, topRightRadius: topRightRadius?.objectiveC, bottomRightRadius: bottomRightRadius?.objectiveC)
    }

    public static func uniformRightRadius(_ rightRadius: UICornerRadius, topLeftRadius: UICornerRadius? = nil, bottomLeftRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        uniformRightRadius(rightRadius.objectiveC, topLeftRadius: topLeftRadius?.objectiveC, bottomLeftRadius: bottomLeftRadius?.objectiveC)
    }
}
