import UIKit
import _SwiftRevenantUIKitOverlayShims

@available(iOS 13.0, *)
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

@available(iOS 13.0, *)
extension UIMenu {
    public convenience init(title: String = "", image: UIImage? = nil, identifier: UIMenu.Identifier? = nil,
                            options: UIMenu.Options = [], children: [UIMenuElement] = []) {
        self.init(revenantTitle: title, image: image, identifier: identifier?.rawValue, options: options, children: children)
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
