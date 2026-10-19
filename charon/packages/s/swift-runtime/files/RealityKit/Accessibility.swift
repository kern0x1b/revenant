// MARK: - What an entity offers a screen reader
//
// The events, the component that stores what an entity offers, and the entity's own properties
// over them - all reached through the public `components` API, so nothing here needs an
// internal seam. The traits are UIKit's own `UIAccessibilityTraits`, spelled as the SDK spells
// them and guarded by `#if canImport(UIKit)`: this module carries Apple's type and no option
// set of its own, which would be an invented API. The parts that name the traits are checked by
// the device call probe, because no host has UIKit; everything else is plain and is host-checked.

import simd
import RealityFoundation
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// What an entity offers a screen reader: how it is announced, and the actions, rotors and
/// content it carries. It is at file scope and not nested, because a type nested in a
/// `@MainActor` extension is itself main-actor isolated, and an isolated type cannot satisfy the
/// nonisolated `Component` protocol - which the compiler reports only where the conformance is
/// used, never where it is declared. `Entity.AccessibilityComponent` names it, so a caller writes
/// what the SDK spells.
@frozen public struct RealityFoundationAccessibilityComponent: Component {
        /// Whether a rotor is the entity's own or the system's.
        public enum RotorType: Hashable {
            /// A rotor the entity's own accessibility component defines.
            case custom
            /// A rotor the system provides.
            case system
        }

        #if canImport(UIKit)
        /// How the entity is announced, and nil for one that says nothing: the traits are UIKit's own option set.
        public var traits: UIAccessibilityTraits
        #endif
        /// Whether the entity is announced as one element, or as the container of several.
        ///
        /// The SDK's own field, read from `RealityFoundation.swiftmodule`'s `AccessibilityComponent`, where it is
        /// the first stored property and a plain `Bool`. It is not spelled through `UIAccessibilityTraits`: no SDK
        /// header declares such a member of that option set - neither the 26.2 one the ledger's rows come from nor the
        /// 16.4 one this overlay is compiled against - so `UIAccessibilityTraits.accessibilityElement` is not a name
        /// this port can offer, and the flag is stored as what it is.
        public var isAccessibilityElement: Bool
        /// The rotors the entity adds, by the key a caller registers them under.
        public var customRotors: [String: AccessibilityEvents.RotorNavigation]
        /// The key the entity is announced under.
        public var label: String?
        /// What is said about the entity's value.
        public var value: String?
        /// What the entity is asked to do, beyond the system's own actions.
        public var customActions: [AccessibilityEvents.CustomAction]
        /// What the entity shows, in the order it shows it.
        public var customContent: [AccessibilityEvents.CustomContent]

        public enum AccessibilityEvents {
            /// The entity was selected.
            public struct Activate: Event {
                public let entity: RealityFoundation.Entity
                public init(entity: RealityFoundation.Entity) { self.entity = entity }
            }
            /// The entity's value was asked to go up.
            public struct Increment: Event {
                public let entity: RealityFoundation.Entity
                public init(entity: RealityFoundation.Entity) { self.entity = entity }
            }
            /// The entity's value was asked to go down.
            public struct Decrement: Event {
                public let entity: RealityFoundation.Entity
                public init(entity: RealityFoundation.Entity) { self.entity = entity }
            }
            /// One of the entity's own actions was asked for, by the key it was registered under.
            public struct CustomAction: Event {
                public let key: String
                public let entity: RealityFoundation.Entity
                public init(key: String, entity: RealityFoundation.Entity) {
                    self.key = key
                    self.entity = entity
                }
            }
            /// The entity was asked to move to another of its own items, through a rotor.
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
            /// What the entity shows, beyond its label and its value.
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
        /// A host has no UIKit, so the component is made without the traits: the storage, the
        /// events and everything else about an entity's accessibility is the same, and the traits
        /// are the one part the device probe reads.
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
    /// What the entity offers a screen reader, named as the SDK names it.
    public typealias AccessibilityComponent = RealityFoundationAccessibilityComponent
}


extension RealityFoundation.Entity {
    /// What the entity offers a screen reader, and nil when it offers nothing.
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

    /// The key the entity is announced under.
    public var accessibilityLabelKey: String? { accessibility?.label }
    /// What is said about the entity's value.
    public var accessibilityValue: String? { accessibility?.value }
    /// What the entity is asked to do, beyond the system's own.
    public var accessibilityCustomActions: [AccessibilityComponent.AccessibilityEvents.CustomAction] { accessibility?.customActions ?? [] }
    /// The rotors the entity carries, by the key they are registered under.
    public var accessibilityCustomRotors: [String: AccessibilityComponent.AccessibilityEvents.RotorNavigation] { accessibility?.customRotors ?? [:] }
    /// What the entity shows, beyond its label and its value.
    public var accessibilityCustomContent: [AccessibilityComponent.AccessibilityEvents.CustomContent] { accessibility?.customContent ?? [] }
    /// The system's own action against the entity, which every entity has.
    public var accessibilitySystemActions: [AccessibilityComponent.AccessibilityEvents.Activate] { [AccessibilityComponent.AccessibilityEvents.Activate(entity: self)] }

    #if canImport(UIKit)
    /// How the entity is announced, and nil for one that says nothing.
    public var accessibilityTraits: UIAccessibilityTraits? { accessibility?.traits }
    #endif
    /// Whether the entity is announced as one element, or as the container of several, as the SDK
    /// spells it: a plain `Bool`, and an entity with no accessibility component is not one. It is not
    /// behind the UIKit guard, because the SDK does not put it there either - the flag is the
    /// component's own `Bool`, not a trait of UIKit's option set.
    public var isAccessibilityElement: Bool {
        get { accessibility?.isAccessibilityElement ?? false }
        set {
            var component = accessibility ?? AccessibilityComponent()
            component.isAccessibilityElement = newValue
            accessibility = component
        }
    }
}
