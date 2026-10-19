import simd
import Foundation

public struct QueryPredicate<Value> {
    let matches: @MainActor (Value) -> Bool

    public init(_ predicate: @escaping @MainActor (Value) -> Bool) {
        matches = predicate
    }

    @MainActor
    public func callAsFunction(_ value: Value) -> Bool {
        matches(value)
    }
}

extension QueryPredicate where Value == Entity {
    public static func has<T>(_ componentType: T.Type) -> QueryPredicate<Entity> where T: Component {
        QueryPredicate<Entity> { $0.components.has(componentType) }
    }
}

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

public struct EntityQuery: @unchecked Sendable {
    let predicate: QueryPredicate<Entity>?

    public init() {
        predicate = nil
    }

    public init(where predicate: QueryPredicate<Entity>) {
        self.predicate = predicate
    }

    @MainActor
    func entities(of scene: __REScene) -> [Entity] {
        let anchors = scene.anchors.map { $0.entity }
        let below = scene.anchors.flatMap { $0.subtree.dropFirst().map { $0.entity } }
        let candidates = anchors + below
        guard let predicate else { return candidates }
        return candidates.filter { predicate.matches($0) }
    }
}

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

extension Scene {
    public func performQuery(_ query: EntityQuery) -> QueryResult<Entity> {
        QueryResult(query.entities(of: coreScene))
    }
}
