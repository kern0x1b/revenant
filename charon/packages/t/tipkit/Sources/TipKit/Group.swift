// The group, and the error the datastore reports.

import Foundation

/// A group of tips, of which one is shown at a time: the framework's own answer for "show me the first
/// tip the owner has not seen yet".
public struct TipGroup {
    /// Which tip of the group is shown.
    public enum Priority: Sendable {
        /// The first tip the datastore says may be shown.
        case firstAvailable
        /// The tips in the order the group wrote them.
        case ordered

        public static func == (a: Priority, b: Priority) -> Bool { return a.raw == b.raw }
        public func hash(into hasher: inout Hasher) { hasher.combine(raw) }
        public var hashValue: Int { return raw.hashValue }
        private var raw: Int {
            switch self {
            case .firstAvailable: return 0
            case .ordered: return 1
            }
        }
    }

    /// The tips of the group, in the order the group wrote them.
    public let tips: [AnyTip]
    /// Which of them is shown.
    public let priority: Priority

    public init(_ priority: Priority = .firstAvailable, @Tips.GroupBuilder _ builder: () -> [any Tip]) {
        self.priority = priority
        self.tips = builder().map { AnyTip($0) }
    }

    /// The tip the group would show now, which is the first one the datastore says may be shown, or
    /// the first one in order when the group is ordered.
    public var currentTip: AnyTip? {
        switch priority {
        case .firstAvailable: return tips.first { Tips.Store.shared.shouldDisplay($0) }
        case .ordered: return tips.first
        }
    }

    /// The stream of the tip the group shows as it changes.
    public var currentTipUpdates: AsyncStream<AnyTip?> {
        return AsyncStream { continuation in
            continuation.yield(currentTip)
            continuation.finish()
        }
    }
}

/// The builder a group's tips are written with, which is what the `@GroupBuilder` attribute names.

/// The builder a group's tips are written with, which is what the `@Tips.GroupBuilder` attribute names.
extension Tips {
    @resultBuilder
    public enum GroupBuilder {
        public static func buildPartialBlock(first: any Tip) -> [any Tip] { return [first] }
        public static func buildPartialBlock(accumulated: [any Tip], next: any Tip) -> [any Tip] {
            var all = accumulated
            all.append(next)
            return all
        }
        public static func buildBlock() -> [any Tip] { return [] }
        public static func buildBlock(_ tip: any Tip) -> [any Tip] { return [tip] }
        public static func buildIf(_ tip: (any Tip)?) -> [any Tip] { return tip.map { [$0] } ?? [] }
        public static func buildEither(first: any Tip) -> [any Tip] { return [first] }
        public static func buildEither(second: any Tip) -> [any Tip] { return [second] }
        public static func buildArray(_ tips: [any Tip]) -> [any Tip] { return tips }
    }
}
