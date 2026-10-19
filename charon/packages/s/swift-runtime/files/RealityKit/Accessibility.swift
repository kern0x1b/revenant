import simd
import RealityFoundation
import Foundation

#if canImport(UIKit)
import UIKit
#endif

@frozen public struct RealityFoundationAccessibilityComponent: Component {
        public enum RotorType: Hashable {
            case custom
            case system
        }

        #if canImport(UIKit)
        public var traits: UIAccessibilityTraits
        #endif
        public var isAccessibilityElement: Bool
        public var customRotors: [String: AccessibilityEvents.RotorNavigation]
        public var label: String?
        public var value: String?
        public var customActions: [AccessibilityEvents.CustomAction]
        public var customContent: [AccessibilityEvents.CustomContent]

        public enum AccessibilityEvents {
            public struct Activate: Event {
                public let entity: RealityFoundation.Entity
                public init(entity: RealityFoundation.Entity) { self.entity = entity }
            }
            public struct Increment: Event {
                public let entity: RealityFoundation.Entity
                public init(entity: RealityFoundation.Entity) { self.entity = entity }
            }
            public struct Decrement: Event {
                public let entity: RealityFoundation.Entity
                public init(entity: RealityFoundation.Entity) { self.entity = entity }
            }
            public struct CustomAction: Event {
                public let key: String
                public let entity: RealityFoundation.Entity
                public init(key: String, entity: RealityFoundation.Entity) {
                    self.key = key
                    self.entity = entity
                }
            }
            public struct RotorNavigation: Event {
                public let hostEntity: RealityFoundation.Entity
                public let rotorType: RotorType
                public let currentItem: String
                public let resultHandler: (String) -> Void

                public init(rotorType: RotorType, hostEntity: RealityFoundation.Entity,
                            currentItem: String, resultHandler: @escaping (String) -> Void) {
                    self.rotorType = rotorType
                    self.hostEntity = hostEntity
                    self.currentItem = currentItem
                    self.resultHandler = resultHandler
                }
            }
            public struct CustomContent {
                public let key: String
                public let value: String
                public init(key: String, value: String) {
                    self.key = key
                    self.value = value
                }
            }
        }

        #if canImport(UIKit)
        public init(traits: UIAccessibilityTraits = [], isAccessibilityElement: Bool = false,
                    label: String? = nil, value: String? = nil) {
            self.traits = traits
            self.isAccessibilityElement = isAccessibilityElement
            self.label = label
            self.value = value
            customRotors = [:]
            customActions = []
            customContent = []
        }
        #else
        public init(isAccessibilityElement: Bool = false, label: String? = nil, value: String? = nil) {
            self.isAccessibilityElement = isAccessibilityElement
            self.label = label
            self.value = value
            customRotors = [:]
            customActions = []
            customContent = []
        }
        #endif

}

extension RealityFoundation.Entity {
    public typealias AccessibilityComponent = RealityFoundationAccessibilityComponent
}


extension RealityFoundation.Entity {
    public var accessibility: AccessibilityComponent? {
        get { components[AccessibilityComponent.self] }
        set {
            if let newValue {
                components.set(newValue)
            } else {
                components.remove(AccessibilityComponent.self)
            }
        }
    }

    public var accessibilityLabelKey: String? { accessibility?.label }
    public var accessibilityValue: String? { accessibility?.value }
    public var accessibilityCustomActions: [AccessibilityComponent.AccessibilityEvents.CustomAction] { accessibility?.customActions ?? [] }
    public var accessibilityCustomRotors: [String: AccessibilityComponent.AccessibilityEvents.RotorNavigation] { accessibility?.customRotors ?? [:] }
    public var accessibilityCustomContent: [AccessibilityComponent.AccessibilityEvents.CustomContent] { accessibility?.customContent ?? [] }
    public var accessibilitySystemActions: [AccessibilityComponent.AccessibilityEvents.Activate] { [AccessibilityComponent.AccessibilityEvents.Activate(entity: self)] }

    #if canImport(UIKit)
    public var accessibilityTraits: UIAccessibilityTraits? { accessibility?.traits }
    #endif
    public var isAccessibilityElement: Bool {
        get { accessibility?.isAccessibilityElement ?? false }
        set {
            var component = accessibility ?? AccessibilityComponent()
            component.isAccessibilityElement = newValue
            accessibility = component
        }
    }
}
