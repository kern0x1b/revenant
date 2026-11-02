import SwiftUI
import MapKit

struct MapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let tint: Color
    let item: MKMapItem
}

struct MapScreen: View {
    @State private var position: MapCameraPosition = .automatic
    @State private var selection: MapSelection<MKMapItem>?
    @State private var lookAround: MKLookAroundScene?
    @State private var presented = false
    let pins: [MapPin]
    let line: [CLLocationCoordinate2D]
    let showsCompass: Bool
    let showsMyLocation: Bool

    var body: some View {
        MapReader { reader in
            Map(position: $position, selection: $selection) {
                ForEach(pins) { pin in
                    Marker(pin.title, coordinate: pin.coordinate)
                        .tint(pin.tint)
                        .tag(MapSelection(pin.item))
                }
                ForEach(pins) { pin in
                    Annotation(pin.title, coordinate: pin.coordinate) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5).fill(Color.red)
                            Text(pin.title)
                        }
                    }
                }
                MapPolyline(coordinates: line, contourStyle: .geodesic)
                    .stroke(Color.blue, lineWidth: 4)
                MapPolygon(coordinates: line)
                    .foregroundStyle(Color.red)
                    .stroke(Color.green, lineWidth: 1)
                MapCircle(center: line[0], radius: 100)
                    .foregroundStyle(Color.red)
                    .stroke(Color.clear, lineWidth: 0)
                if showsMyLocation {
                    UserAnnotation()
                }
            }
            .onTapGesture(coordinateSpace: .local) { point in
                if let coordinate = reader.convert(point, from: .local) {
                    _ = coordinate.latitude
                }
            }
            .mapControls {
                if showsCompass {
                    MapCompass()
                }
                MapScaleView()
                MapPitchToggle()
                MapUserLocationButton()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                _ = context.region.center
                _ = context.camera.pitch
                _ = context.region.span.longitudeDelta
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excluding([]), showsTraffic: false))
            .mapFeatureSelectionAccessory(.automatic)
            .lookAroundViewer(
                isPresented: $presented,
                initialScene: lookAround,
                allowsNavigation: true,
                showsRoadLabels: true,
                pointsOfInterest: .all,
                onDismiss: {}
            )
        }
    }
}

func mapStylesAreChosen() -> [any MapStyle] {
    [
        .hybrid(elevation: .flat, pointsOfInterest: .none, showsTraffic: true),
        .imagery(elevation: .automatic),
        .standard(),
    ]
}

func cameraPositionsAreBuilt(_ coordinate: CLLocationCoordinate2D, _ item: MKMapItem) -> [MapCameraPosition] {
    let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    let camera = MapCamera(centerCoordinate: coordinate, distance: 1000, heading: 0, pitch: 45)
    return [
        .automatic,
        .region(region),
        .camera(camera),
        .userLocation(fallback: .region(region)),
        .item(item),
        .rect(MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize(width: 1, height: 1))),
    ]
}

func customContentIsMapContent(_ show: Bool, _ coordinate: CLLocationCoordinate2D) -> some MapContent {
    CustomMapContent(coordinate: coordinate, show: show)
}

struct CustomMapContent: MapContent {
    let coordinate: CLLocationCoordinate2D
    let show: Bool

    func _mapElements(_ style: _MapElementStyle) -> [_MapElement] {
        var elements: [_MapElement] = []
        if show {
            elements.append(contentsOf: Marker("one", coordinate: coordinate)._mapElements(style))
        }
        return elements
    }
}

func pointOfInterestFiltersAreBuilt() -> [PointOfInterestCategories] {
    [.all, .none, .including([]), .excluding([])]
}

func selectionBindingIsBuilt(_ selection: Binding<MapSelection<String>?>, _ position: Binding<MapCameraPosition>) -> some View {
    Map(position: position, interactionModes: [.pan, .zoom], selection: selection) {
        Marker("x", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)).tag(MapSelection("x"))
    }
}
