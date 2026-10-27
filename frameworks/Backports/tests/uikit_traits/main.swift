import UIKit

final class TraitObserver: UIView {
    func observe() {
        if #available(iOS 17.0, *) {
            let handler = registerForTraitChanges([UITraitUserInterfaceStyle.self], handler: { (environment: any UITraitEnvironment, previous: UITraitCollection) in })
            let target = registerForTraitChanges([UITraitUserInterfaceStyle.self], target: self, action: #selector(UIView.layoutSubviews))
            let action = registerForTraitChanges([UITraitUserInterfaceStyle.self], action: #selector(UIView.layoutSubviews))
            unregisterForTraitChanges(handler)
            unregisterForTraitChanges(target)
            unregisterForTraitChanges(action)
            _ = traitOverrides
            updateTraitsIfNeeded()
        }
    }

    func present(_ interaction: UIEditMenuInteraction, at point: CGPoint) {
        if #available(iOS 16.0, *) {
            interaction.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: point))
        }
    }
}
