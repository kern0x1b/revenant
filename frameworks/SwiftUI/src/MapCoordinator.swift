import UIKit
import MapKit
import QuartzCore

final class _MapAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    let isMarker: Bool
    var tag: AnyHashable?
    var tint: UIColor?
    var glyph: _MarkerGlyph = .none
    var content: AnyView?
    var anchor: UnitPoint = .center
    var hosting: UIHostingController<AnyView>?
    weak var view: MKAnnotationView?

    init(isMarker: Bool, coordinate: CLLocationCoordinate2D) {
        self.isMarker = isMarker
        self.coordinate = coordinate
    }
}

enum _MapShape {
    case polyline([CLLocationCoordinate2D], geodesic: Bool)
    case polygon([CLLocationCoordinate2D])
    case circle(CLLocationCoordinate2D, radius: CLLocationDistance)
}

struct _MapShapeStyle {
    var fill: UIColor?
    var stroke: UIColor?
    var lineWidth: CGFloat
    var tag: AnyHashable?
}

struct _MapOverlayRecord {
    let overlay: MKOverlay
    let shape: _MapShape
    let style: _MapShapeStyle
}

func _mapShape(of element: _MapElement) -> (_MapShape, _MapShapeStyle)? {
    switch element {
    case .polyline(let line):
        return (.polyline(line.coordinates, geodesic: line.geodesic),
                _MapShapeStyle(fill: nil, stroke: (line.stroke?.uiColor) ?? .blue, lineWidth: CGFloat(line.lineWidth ?? 1), tag: line.tag))
    case .polygon(let polygon):
        return (.polygon(polygon.coordinates),
                _MapShapeStyle(fill: (polygon.fill?.uiColor) ?? UIColor.blue.withAlphaComponent(0.25),
                               stroke: (polygon.stroke?.uiColor) ?? .blue, lineWidth: CGFloat(polygon.lineWidth ?? 1), tag: polygon.tag))
    case .circle(let circle):
        return (.circle(circle.center, radius: circle.radius),
                _MapShapeStyle(fill: (circle.fill?.uiColor) ?? UIColor.blue.withAlphaComponent(0.25),
                               stroke: (circle.stroke?.uiColor) ?? .blue, lineWidth: CGFloat(circle.lineWidth ?? 1), tag: circle.tag))
    default:
        return nil
    }
}

func _mapSameCoordinates(_ a: [CLLocationCoordinate2D], _ b: [CLLocationCoordinate2D]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { _mapSameCoordinate($0, $1) }
}

func _mapSameShape(_ a: (_MapShape, _MapShapeStyle), _ b: (_MapShape, _MapShapeStyle)) -> Bool {
    let styleEqual = a.1.fill == b.1.fill && a.1.stroke == b.1.stroke && a.1.lineWidth == b.1.lineWidth && a.1.tag == b.1.tag
    guard styleEqual else { return false }
    switch (a.0, b.0) {
    case let (.polyline(x, gx), .polyline(y, gy)): return gx == gy && _mapSameCoordinates(x, y)
    case let (.polygon(x), .polygon(y)): return _mapSameCoordinates(x, y)
    case let (.circle(cx, rx), .circle(cy, ry)): return rx == ry && _mapSameCoordinate(cx, cy)
    default: return false
    }
}

func _mapPinColor(for tint: UIColor?) -> MKPinAnnotationColor {
    guard let tint else { return .red }
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard tint.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return .red }
    let candidates: [(MKPinAnnotationColor, (CGFloat, CGFloat, CGFloat))] = [
        (.red, (1, 0, 0)), (.green, (0, 0.6, 0)), (.purple, (0.5, 0, 0.5)),
    ]
    return candidates.min { lhs, rhs in
        let dl = (lhs.1.0 - red) * (lhs.1.0 - red) + (lhs.1.1 - green) * (lhs.1.1 - green) + (lhs.1.2 - blue) * (lhs.1.2 - blue)
        let dr = (rhs.1.0 - red) * (rhs.1.0 - red) + (rhs.1.1 - green) * (rhs.1.1 - green) + (rhs.1.2 - blue) * (rhs.1.2 - blue)
        return dl < dr
    }?.0 ?? .red
}

func _mapPolygonContains(_ point: MKMapPoint, _ vertices: [MKMapPoint]) -> Bool {
    guard vertices.count > 2 else { return false }
    var inside = false
    var j = vertices.count - 1
    for i in vertices.indices {
        let a = vertices[i], b = vertices[j]
        if (a.y > point.y) != (b.y > point.y), point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
            inside.toggle()
        }
        j = i
    }
    return inside
}

func _mapDistance(from point: MKMapPoint, toSegment a: MKMapPoint, _ b: MKMapPoint) -> Double {
    let dx = b.x - a.x, dy = b.y - a.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else { return point.distance(to: a) }
    let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
    return point.distance(to: MKMapPoint(x: a.x + t * dx, y: a.y + t * dy))
}

func _mapPolylineHit(_ point: MKMapPoint, _ vertices: [MKMapPoint], tolerance: Double) -> Bool {
    guard vertices.count > 1 else { return false }
    return zip(vertices, vertices.dropFirst()).contains { _mapDistance(from: point, toSegment: $0, $1) <= tolerance }
}

func _mapShapeHit(_ shape: _MapShape, at point: MKMapPoint, tolerance: Double) -> Bool {
    switch shape {
    case .polyline(let coordinates, _):
        return _mapPolylineHit(point, coordinates.map(MKMapPoint.init), tolerance: tolerance)
    case .polygon(let coordinates):
        return _mapPolygonContains(point, coordinates.map(MKMapPoint.init))
    case .circle(let center, let radius):
        let metersPerPoint = MKMetersPerMapPointAtLatitude(center.latitude)
        return point.distance(to: MKMapPoint(center)) <= radius / metersPerPoint
    }
}

final class MapCoordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
    private weak var mapView: MKMapView?
    private var position: Binding<MapCameraPosition>?
    private var lastPosition: MapCameraPosition?
    private var selection: _MapSelectionLink?
    private var cameraChange: _MapCameraChange?
    private var annotations: [_MapAnnotation] = []
    private var overlays: [_MapOverlayRecord] = []
    private var lastOverlayShapes: [(_MapShape, _MapShapeStyle)] = []
    private var styleDescription: String?
    private var displayLink: CADisplayLink?
    private var lookAround: _MapLookAround?
    private var lookAroundController: _MapLookAroundController?
    private var proxy: _MapProxyBox?

    func install(on view: MKMapView) {
        mapView = view
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    func update(_ view: MKMapView, _ update: _MapUpdate) {
        mapView = view
        proxy = update.proxy
        proxy?.view = view
        selection = update.selection
        cameraChange = update.cameraChange
        position = update.position
        lookAround = update.lookAround

        applyInteraction(update.interactionModes, to: view)
        applyControls(update.controls, to: view)
        applyStyle(update.style, to: view)
        let overlaysChanged = syncOverlays(update.elements, in: view)
        let annotationsChanged = syncAnnotations(update.elements, in: view)
        view.showsUserLocation = update.elements.contains { if case .userLocation = $0 { return true } else { return false } }
            || update.position.wrappedValue.isUserLocation
        syncSelection(in: view)

        let current = update.position.wrappedValue
        if lastPosition != current {
            lastPosition = current
            applyPosition(current, to: view)
        } else if current.isAutomatic && (overlaysChanged || annotationsChanged) {
            fitContent(in: view)
        }
        presentLookAround(in: view)
    }

    private func applyInteraction(_ modes: MapInteractionModes, to view: MKMapView) {
        view.isScrollEnabled = modes.contains(.pan)
        view.isZoomEnabled = modes.contains(.zoom)
        view.isRotateEnabled = modes.contains(.rotate)
        view._mapSetFlag("pitchEnabled", modes.contains(.pitch))
    }

    private func applyControls(_ controls: Set<_MapControlKind>, to view: MKMapView) {
        view._mapSetFlag("showsCompass", controls.contains(.compass))
        view._mapSetFlag("showsScale", controls.contains(.scale))
        view._mapSetFlag("showsPitchControl", controls.contains(.pitch))
        view._mapSetFlag("showsUserTrackingButton", controls.contains(.userLocation))
    }

    private func applyStyle(_ style: (any MapStyle)?, to view: MKMapView) {
        let description = style.map { String(describing: $0) } ?? "standard"
        guard description != styleDescription else { return }
        styleDescription = description
        if let style {
            style._apply(to: view)
        } else {
            StandardMapStyle(elevation: .automatic, emphasis: .automatic, pointsOfInterest: .all, showsTraffic: false)._apply(to: view)
        }
    }

    private func syncOverlays(_ elements: [_MapElement], in view: MKMapView) -> Bool {
        let shapes = elements.compactMap(_mapShape(of:))
        let unchanged = shapes.count == lastOverlayShapes.count
            && zip(shapes, lastOverlayShapes).allSatisfy { _mapSameShape($0, $1) }
        guard !unchanged else { return false }
        lastOverlayShapes = shapes
        view.removeOverlays(overlays.map(\.overlay))
        overlays = shapes.map { shape, style in
            _MapOverlayRecord(overlay: makeOverlay(shape), shape: shape, style: style)
        }
        view.addOverlays(overlays.map(\.overlay))
        return true
    }

    private func makeOverlay(_ shape: _MapShape) -> MKOverlay {
        switch shape {
        case .polyline(let coordinates, let geodesic):
            var copy = coordinates
            return geodesic
                ? MKGeodesicPolyline(coordinates: &copy, count: copy.count)
                : MKPolyline(coordinates: &copy, count: copy.count)
        case .polygon(let coordinates):
            var copy = coordinates
            return MKPolygon(coordinates: &copy, count: copy.count)
        case .circle(let center, let radius):
            return MKCircle(center: center, radius: radius)
        }
    }

    private func syncAnnotations(_ elements: [_MapElement], in view: MKMapView) -> Bool {
        let specs: [(Bool, _MapAnnotationSpec)] = elements.compactMap { element in
            switch element {
            case .marker(let marker):
                return (true, _MapAnnotationSpec(title: marker.title, coordinate: marker.coordinate, tint: marker.tint, glyph: marker.glyph,
                                                 content: nil, anchor: .center, tag: marker.tag))
            case .annotation(let annotation):
                return (false, _MapAnnotationSpec(title: annotation.title, coordinate: annotation.coordinate, tint: nil, glyph: .none,
                                                  content: annotation.content, anchor: annotation.anchor, tag: annotation.tag))
            default:
                return nil
            }
        }

        let previousCount = annotations.count
        var keep = 0
        while keep < min(specs.count, annotations.count), annotations[keep].isMarker == specs[keep].0 {
            keep += 1
        }
        if keep < annotations.count {
            view.removeAnnotations(Array(annotations[keep...]))
            annotations.removeSubrange(keep...)
        }
        for (index, spec) in specs.enumerated() where index < keep {
            let value = spec.1
            let object = annotations[index]
            object.coordinate = value.coordinate
            object.title = value.title
            object.tag = value.tag
            object.tint = value.tint?.uiColor
            object.glyph = value.glyph
            object.anchor = value.anchor
            if let content = value.content {
                object.content = content
                if let hosting = object.hosting {
                    hosting.rootView = content
                    hosting.contentChanged()
                }
            }
            if let pin = object.view as? MKPinAnnotationView {
                pin.pinColor = _mapPinColor(for: object.tint)
                pin.leftCalloutAccessoryView = _mapCalloutAccessory(object.glyph)
            }
            if let annotationView = object.view {
                _mapLayOutAnnotationView(annotationView, object)
            }
        }
        let added = specs.enumerated().filter { $0.offset >= keep }.map { $0.element }
        let created = added.map { isMarker, value -> _MapAnnotation in
            let object = _MapAnnotation(isMarker: isMarker, coordinate: value.coordinate)
            object.title = value.title
            object.tag = value.tag
            object.tint = value.tint?.uiColor
            object.glyph = value.glyph
            object.anchor = value.anchor
            if let content = value.content {
                object.content = content
                object.hosting = UIHostingController(rootView: content)
            }
            return object
        }
        annotations.append(contentsOf: created)
        if !created.isEmpty {
            view.addAnnotations(created)
        }
        return keep < specs.count || keep < previousCount
    }

    private func syncSelection(in view: MKMapView) {
        guard let selection else { return }
        let wanted = selection.current()
        let selected = view.selectedAnnotations.compactMap { $0 as? _MapAnnotation }
        if let wanted {
            guard !selected.contains(where: { $0.tag == wanted }) else { return }
            if let target = annotations.first(where: { $0.tag == wanted }) {
                view.selectAnnotation(target, animated: true)
            }
        } else {
            for annotation in selected {
                view.deselectAnnotation(annotation, animated: true)
            }
        }
    }

    private func applyPosition(_ position: MapCameraPosition, to view: MKMapView) {
        switch position.storage {
        case .automatic:
            fitContent(in: view)
        case .region(let region):
            view.setRegion(region, animated: true)
        case .camera(let camera):
            view.setCamera(camera, animated: true)
        case .userLocation(let fallback):
            if view.showsUserLocation, let location = view.userLocation.location {
                view.setRegion(MKCoordinateRegion(center: location.coordinate, span: view.region.span), animated: true)
            } else {
                applyPosition(fallback, to: view)
            }
        case .item(let item):
            view.setRegion(MKCoordinateRegion(center: item.placemark.coordinate, span: view.region.span), animated: true)
        case .rect(let rect):
            view.setVisibleMapRect(rect, animated: true)
        }
    }

    private func fitContent(in view: MKMapView) {
        var rect = MKMapRect.null
        for record in overlays {
            rect = rect.union(record.overlay.boundingMapRect)
        }
        for annotation in annotations {
            rect = rect.union(MKMapRect(origin: MKMapPoint(annotation.coordinate), size: MKMapSize(width: 0, height: 0)))
        }
        guard !rect.isNull else { return }
        let padded = rect.insetBy(dx: -rect.size.width * 0.1 - 1, dy: -rect.size.height * 0.1 - 1)
        view.setVisibleMapRect(padded, animated: true)
    }

    private func presentLookAround(in view: MKMapView) {
        guard let request = lookAround else { return }
        var top = view.window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        if request.isPresented.wrappedValue, lookAroundController == nil, let scene = request.scene, let presenter = top {
            let controller = _MapLookAroundController(scene: scene)
            controller._mapSetFlag("navigationEnabled", request.allowsNavigation)
            controller._mapSetFlag("showsRoadLabels", request.showsRoadLabels)
            controller._mapSetValue("pointOfInterestFilter", request.pointsOfInterest.pointOfInterestFilter)
            controller.disappeared = { [weak self, weak controller] in
                guard let self, let controller, self.lookAroundController === controller else { return }
                self.lookAroundController = nil
                request.isPresented.wrappedValue = false
                request.onDismiss?()
            }
            lookAroundController = controller
            presenter.present(controller, animated: true)
        } else if !request.isPresented.wrappedValue, let controller = lookAroundController {
            lookAroundController = nil
            controller.disappeared = nil
            controller.dismiss(animated: true)
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let view = mapView else { return }
        let point = recognizer.location(in: view)
        var candidate = view.hitTest(point, with: nil)
        while let current = candidate, current !== view {
            if current is MKAnnotationView { return }
            candidate = current.superview
        }
        let coordinate = view.convert(point, toCoordinateFrom: view)
        let tolerance = 20 * view.visibleMapRect.size.width / Double(max(view.bounds.width, 1))
        let mapPoint = MKMapPoint(coordinate)
        if let record = overlays.last(where: { $0.style.tag != nil && _mapShapeHit($0.shape, at: mapPoint, tolerance: tolerance) }) {
            selection?.assign(record.style.tag)
        } else if selection?.current() != nil {
            selection?.assign(nil)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let object = annotation as? _MapAnnotation else { return nil }
        if object.isMarker {
            let identifier = "space.kern0x1b.swiftui.marker"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
                ?? MKPinAnnotationView(annotation: object, reuseIdentifier: identifier)
            view.annotation = object
            view.pinColor = _mapPinColor(for: object.tint)
            view.canShowCallout = true
            view.leftCalloutAccessoryView = _mapCalloutAccessory(object.glyph)
            object.view = view
            return view
        }
        let view = MKAnnotationView(annotation: object, reuseIdentifier: nil)
        view.canShowCallout = false
        if let hosting = object.hosting {
            view.addSubview(hosting.view)
        }
        object.view = view
        _mapLayOutAnnotationView(view, object)
        return view
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let record = overlays.first(where: { $0.overlay === overlay }) else {
            return MKOverlayRenderer(overlay: overlay)
        }
        switch overlay {
        case let circle as MKCircle:
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = record.style.fill
            renderer.strokeColor = record.style.stroke
            renderer.lineWidth = record.style.lineWidth
            return renderer
        case let polygon as MKPolygon:
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = record.style.fill
            renderer.strokeColor = record.style.stroke
            renderer.lineWidth = record.style.lineWidth
            return renderer
        case let polyline as MKPolyline:
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = record.style.stroke
            renderer.lineWidth = record.style.lineWidth
            return renderer
        default:
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let object = view.annotation as? _MapAnnotation, let tag = object.tag else { return }
        selection?.assign(tag)
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        guard let object = view.annotation as? _MapAnnotation, let tag = object.tag else { return }
        if selection?.current() == tag {
            selection?.assign(nil)
        }
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard displayLink == nil, cameraChange?.frequency == .continuous else { return }
        let link = CADisplayLink(target: self, selector: #selector(sampleCamera(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        displayLink?.invalidate()
        displayLink = nil
        reportCamera(mapView, animated: animated, isFinal: true)
        if let position, let next = _mapPosition(describing: mapView), position.wrappedValue != next,
           position.wrappedValue.isCameraBound {
            lastPosition = next
            position.wrappedValue = next
        }
    }

    @objc private func sampleCamera(_ link: CADisplayLink) {
        guard let mapView else { return }
        reportCamera(mapView, animated: false, isFinal: false)
    }

    private func reportCamera(_ mapView: MKMapView, animated: Bool, isFinal: Bool) {
        guard let change = cameraChange else { return }
        if change.frequency == .onEnd && !isFinal { return }
        change.perform(MapCameraUpdateContext(camera: mapView.camera, region: mapView.region, rect: mapView.visibleMapRect, animated: animated))
    }
}

struct _MapAnnotationSpec {
    let title: String
    let coordinate: CLLocationCoordinate2D
    let tint: Color?
    let glyph: _MarkerGlyph
    let content: AnyView?
    let anchor: UnitPoint
    let tag: AnyHashable?
}

func _mapPosition(describing mapView: MKMapView) -> MapCameraPosition? {
    let camera = mapView.camera
    if camera.pitch == 0 && camera.heading == 0 {
        return .region(mapView.region)
    }
    return .camera(camera)
}

func _mapLayOutAnnotationView(_ view: MKAnnotationView, _ object: _MapAnnotation) {
    guard let hosting = object.hosting else { return }
    let size = hosting.sizeThatFits(in: CGSize(width: 10_000, height: 10_000))
    view.bounds = CGRect(origin: .zero, size: size)
    hosting.view.frame = view.bounds
    view.centerOffset = CGPoint(x: (0.5 - object.anchor.x) * size.width, y: (0.5 - object.anchor.y) * size.height)
}

func _mapCalloutAccessory(_ glyph: _MarkerGlyph) -> UIView? {
    switch glyph {
    case .none:
        return nil
    case .systemImage(let name):
        let image = SymbolGlyphs.image(named: name, points: 22, bold: false) ?? SymbolGlyphs.placeholder(points: 22)
        return UIImageView(image: image)
    case .monogram(let text):
        let label = UILabel()
        label.text = text
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.textAlignment = .center
        label.sizeToFit()
        return label
    }
}

extension MapCameraPosition {
    var isAutomatic: Bool {
        if case .automatic = storage { return true }
        return false
    }

    var isUserLocation: Bool {
        if case .userLocation = storage { return true }
        return false
    }

    var isCameraBound: Bool {
        switch storage {
        case .region, .camera: return true
        default: return false
        }
    }
}

