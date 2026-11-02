import UIKit
import MapKit

public struct Marker: MapContent {
    let title: String
    let coordinate: CLLocationCoordinate2D
    let glyph: _MarkerGlyph

    public init(_ title: String, coordinate: CLLocationCoordinate2D) {
        self.init(title, glyph: .none, coordinate: coordinate)
    }

    public init(_ title: String, systemImage: String, coordinate: CLLocationCoordinate2D) {
        self.init(title, glyph: .systemImage(systemImage), coordinate: coordinate)
    }

    public init(_ title: String, monogram: Text, coordinate: CLLocationCoordinate2D) {
        self.init(title, glyph: .monogram(findText(monogram)?.content ?? ""), coordinate: coordinate)
    }

    init(_ title: String, glyph: _MarkerGlyph, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
        self.glyph = glyph
    }

    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        [.marker(_MarkerElement(title: title, coordinate: coordinate, glyph: glyph, tint: style.tint, tag: style.tag))]
    }
}

public struct Annotation<Content: View>: MapContent {
    let title: String
    let coordinate: CLLocationCoordinate2D
    let anchor: UnitPoint
    let content: Content

    public init(_ title: String, coordinate: CLLocationCoordinate2D, anchor: UnitPoint = .center, @ViewBuilder content: () -> Content) {
        self.title = title
        self.coordinate = coordinate
        self.anchor = anchor
        self.content = content()
    }

    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        [.annotation(_AnnotationElement(title: title, coordinate: coordinate, anchor: anchor, content: AnyView(content), tag: style.tag))]
    }
}

public struct MapPolyline: MapContent {
    public enum ContourStyle: Hashable {
        case straight
        case geodesic
    }

    let coordinates: [CLLocationCoordinate2D]
    let contourStyle: ContourStyle

    public init(coordinates: [CLLocationCoordinate2D], contourStyle: ContourStyle = .straight) {
        self.coordinates = coordinates
        self.contourStyle = contourStyle
    }

    public init(_ polyline: MKPolyline) {
        self.init(coordinates: _mapCoordinates(of: polyline), contourStyle: .straight)
    }

    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        [.polyline(_PolylineElement(coordinates: coordinates, geodesic: contourStyle == .geodesic, stroke: style.stroke, lineWidth: style.lineWidth, tag: style.tag))]
    }
}

public struct MapPolygon: MapContent {
    let coordinates: [CLLocationCoordinate2D]

    public init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
    }

    public init(_ polygon: MKPolygon) {
        self.init(coordinates: _mapCoordinates(of: polygon))
    }

    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        [.polygon(_PolygonElement(coordinates: coordinates, fill: style.fill, stroke: style.stroke, lineWidth: style.lineWidth, tag: style.tag))]
    }
}

public struct MapCircle: MapContent {
    let center: CLLocationCoordinate2D
    let radius: CLLocationDistance

    public init(center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        self.center = center
        self.radius = radius
    }

    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        [.circle(_CircleElement(center: center, radius: radius, fill: style.fill, stroke: style.stroke, lineWidth: style.lineWidth, tag: style.tag))]
    }
}

public struct UserAnnotation: MapContent {
    public init() {}

    public func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        [.userLocation]
    }
}

func _mapCoordinates(of shape: MKMultiPoint) -> [CLLocationCoordinate2D] {
    let count = shape.pointCount
    guard count > 0 else { return [] }
    var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: count)
    shape.getCoordinates(&coordinates, range: NSRange(location: 0, length: count))
    return coordinates
}
