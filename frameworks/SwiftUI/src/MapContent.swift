import UIKit
import MapKit

public protocol MapContent {
    func _mapElements(_ style: _MapElementStyle) -> [_MapElement]
}

public struct _MapElementStyle {
    public var tint: Color?
    public var stroke: Color?
    public var lineWidth: Double?
    public var fill: Color?
    public var tag: AnyHashable?
    public init() {}
}

public enum _MapElement {
    case marker(_MarkerElement)
    case annotation(_AnnotationElement)
    case polyline(_PolylineElement)
    case polygon(_PolygonElement)
    case circle(_CircleElement)
    case userLocation
}

public enum _MarkerGlyph {
    case none
    case systemImage(String)
    case monogram(String)
}

public struct _MarkerElement {
    public var title: String
    public var coordinate: CLLocationCoordinate2D
    public var glyph: _MarkerGlyph
    public var tint: Color?
    public var tag: AnyHashable?
}

public struct _AnnotationElement {
    public var title: String
    public var coordinate: CLLocationCoordinate2D
    public var anchor: UnitPoint
    public var content: AnyView
    public var tag: AnyHashable?
}

public struct _PolylineElement {
    public var coordinates: [CLLocationCoordinate2D]
    public var geodesic: Bool
    public var stroke: Color?
    public var lineWidth: Double?
    public var tag: AnyHashable?
}

public struct _PolygonElement {
    public var coordinates: [CLLocationCoordinate2D]
    public var fill: Color?
    public var stroke: Color?
    public var lineWidth: Double?
    public var tag: AnyHashable?
}

public struct _CircleElement {
    public var center: CLLocationCoordinate2D
    public var radius: CLLocationDistance
    public var fill: Color?
    public var stroke: Color?
    public var lineWidth: Double?
    public var tag: AnyHashable?
}

@resultBuilder
public struct MapContentBuilder {
    public static func buildExpression<Content: MapContent>(_ content: Content) -> Content { content }
    public static func buildBlock() -> EmptyMapContent { EmptyMapContent() }
    public static func buildBlock<Content: MapContent>(_ content: Content) -> Content { content }
    public static func buildBlock<each Content: MapContent>(_ content: repeat each Content) -> TupleMapContent<(repeat each Content)> {
        var parts: [any MapContent] = []
        for part in repeat each content { parts.append(part) }
        return TupleMapContent(parts: parts)
    }
    public static func buildOptional<Content: MapContent>(_ content: Content?) -> Content? { content }
    public static func buildEither<True: MapContent, False: MapContent>(first: True) -> _MapConditionalContent<True, False> {
        _MapConditionalContent(storage: .first(first))
    }
    public static func buildEither<True: MapContent, False: MapContent>(second: False) -> _MapConditionalContent<True, False> {
        _MapConditionalContent(storage: .second(second))
    }
    public static func buildLimitedAvailability<Content: MapContent>(_ content: Content) -> Content { content }
}

public struct EmptyMapContent: MapContent {
    public init() {}
    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] { [] }
}

public struct TupleMapContent<T>: MapContent {
    let parts: [any MapContent]
    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        parts.flatMap { $0._mapElements(style) }
    }
}

public struct _MapConditionalContent<TrueContent: MapContent, FalseContent: MapContent>: MapContent {
    enum Storage {
        case first(TrueContent)
        case second(FalseContent)
    }
    let storage: Storage
    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        switch storage {
        case .first(let content): return content._mapElements(style)
        case .second(let content): return content._mapElements(style)
        }
    }
}

extension Optional: MapContent where Wrapped: MapContent {
    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        self?._mapElements(style) ?? []
    }
}

extension ForEach: MapContent where Content: MapContent {
    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        data.flatMap { content($0)._mapElements(style) }
    }
}

extension ForEach where Content: MapContent {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @MapContentBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data: data, id: id, content: content)
    }
}

extension ForEach where ID == Data.Element.ID, Content: MapContent, Data.Element: Identifiable {
    public init(_ data: Data, @MapContentBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

public struct _MapStyledContent<Content: MapContent>: MapContent {
    let content: Content
    let apply: (inout _MapElementStyle) -> Void
    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        var inner = style
        apply(&inner)
        return content._mapElements(inner)
    }
}

extension MapContent {
    public func tag<Value: Hashable>(_ value: Value) -> _MapStyledContent<Self> {
        _MapStyledContent(content: self) { $0.tag = AnyHashable(value) }
    }

    public func tint(_ color: Color?) -> _MapStyledContent<Self> {
        _MapStyledContent(content: self) { $0.tint = color }
    }

    public func stroke(_ color: Color, lineWidth: Double = 1) -> _MapStyledContent<Self> {
        _MapStyledContent(content: self) {
            $0.stroke = color
            $0.lineWidth = lineWidth
        }
    }

    public func foregroundStyle(_ color: Color) -> _MapStyledContent<Self> {
        _MapStyledContent(content: self) { $0.fill = color }
    }
}
