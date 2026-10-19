import Foundation

public struct TipGroup {
    public enum Priority: Sendable {
        case firstAvailable
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

    public let tips: [AnyTip]
    public let priority: Priority

    public init(_ priority: Priority = .firstAvailable, @Tips.GroupBuilder _ builder: () -> [any Tip]) {
        self.priority = priority
        self.tips = builder().map { AnyTip($0) }
    }

    public var currentTip: AnyTip? {
        switch priority {
        case .firstAvailable: return tips.first { Tips.Store.shared.shouldDisplay($0) }
        case .ordered: return tips.first
        }
    }

    public var currentTipUpdates: AsyncStream<AnyTip?> {
        return AsyncStream { continuation in
            continuation.yield(currentTip)
            continuation.finish()
        }
    }
}

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
