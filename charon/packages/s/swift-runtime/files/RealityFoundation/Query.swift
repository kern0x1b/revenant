// The scene graph's queries: which entities a scene holds, and what a caller asks of them.

import simd
import Foundation

// MARK: - QueryPredicate

/// A test one entity is asked to pass, and the result of a query is every entity that does.
///
/// A predicate is a closure over the value: `QueryPredicate { $0.name == "box" }`. Two
/// predicates combine with `&&`, `||` and `!`, and `QueryPredicate.has(_:)` asks for a
/// component of a type.
public struct QueryPredicate<Value> {
    let matches: @MainActor (Value) -> Bool

    public init(_ predicate: @escaping @MainActor (Value) -> Bool) {
        matches = predicate
    }

    /// Whether `value` passes the predicate.
    @MainActor
    public func callAsFunction(_ value: Value) -> Bool {
        matches(value)
    }
}

extension QueryPredicate where Value == Entity {
    /// The predicate of the entities that carry a component of the given type.
    public static func has<T>(_ componentType: T.Type) -> QueryPredicate<Entity> where T: Component {
        QueryPredicate<Entity> { $0.components.has(componentType) }
    }
}

/// The negation of a predicate.
@MainActor
public prefix func ! <Value>(operand: QueryPredicate<Value>) -> QueryPredicate<Value> {
    QueryPredicate<Value> { !operand.matches($0) }
}

@MainActor
public func && <Value>(left: QueryPredicate<Value>, right: QueryPredicate<Value>) -> QueryPredicate<Value> {
    QueryPredicate<Value> { left.matches($0) && right.matches($0) }
}

@MainActor
public func || <Value>(left: QueryPredicate<Value>, right: QueryPredicate<Value>) -> QueryPredicate<Value> {
    QueryPredicate<Value> { left.matches($0) || right.matches($0) }
}

// MARK: - EntityQuery

/// A query over the entities of a scene: every one of them, or only the ones a predicate
/// admits.
///
/// The query is `Sendable` the way the SDK's is: it holds a caller's closure, and whether that
/// closure is safe to call off the main actor is the caller's business.
public struct EntityQuery: @unchecked Sendable {
    let predicate: QueryPredicate<Entity>?

    public init() {
        predicate = nil
    }

    public init(where predicate: QueryPredicate<Entity>) {
        self.predicate = predicate
    }

    /// The scene's anchors first, in the order they were added, and then everything below them,
    /// each anchor's own subtree depth-first.
    ///
    /// Measured on the host (2026-09-27, arm64-apple-macos14, MacOSX26.5.sdk): a scene with
    /// the anchors A, B and C, A holding A1 which holds A2, and B holding B1, C holding C1,
    /// answers `performQuery(EntityQuery())` with
    /// `["A", "B", "C", "A1", "A2", "B1", "C1"]` - every anchor before anything below one.
    @MainActor
    func entities(of scene: __REScene) -> [Entity] {
        let anchors = scene.anchors.map { $0.entity }
        let below = scene.anchors.flatMap { $0.subtree.dropFirst().map { $0.entity } }
        let candidates = anchors + below
        guard let predicate else { return candidates }
        return candidates.filter { predicate.matches($0) }
    }
}

// MARK: - QueryResult

/// The entities a query found, in the order the scene holds them: every anchor first, and an
/// entity's own children after it.
public struct QueryResult<Element> {
    let entities: [Element]

    init(_ entities: [Element]) {
        self.entities = entities
    }
}

extension QueryResult: Sequence {
    public struct Iterator: IteratorProtocol {
        private let entities: [Element]
        private var position: Int

        fileprivate init(_ entities: [Element]) {
            self.entities = entities
            self.position = 0
        }

        public mutating func next() -> Element? {
            guard position < entities.count else { return nil }
            defer { position += 1 }
            return entities[position]
        }
    }

    public func makeIterator() -> Iterator {
        Iterator(entities)
    }
}

// MARK: - Running a query

extension Scene {
    /// The entities of this scene the query admits, each anchor first and its subtree after it.
    public func performQuery(_ query: EntityQuery) -> QueryResult<Entity> {
        QueryResult(query.entities(of: coreScene))
    }
}
