import UIKit
import MapKit

public typealias MapCamera = MKMapCamera

extension MKMapCamera {
    public convenience init(centerCoordinate: CLLocationCoordinate2D, distance: CLLocationDistance, heading: CLLocationDirection, pitch: CGFloat) {
        self.init(lookingAtCenter: centerCoordinate, fromDistance: distance, pitch: pitch, heading: heading)
    }
}

public struct MapCameraPosition: Equatable {
    indirect enum Storage: Equatable {
        case automatic
        case region(MKCoordinateRegion)
        case camera(MKMapCamera)
        case userLocation(fallback: MapCameraPosition)
        case item(MKMapItem)
        case rect(MKMapRect)
    }

    let storage: Storage

    public static var automatic: MapCameraPosition { MapCameraPosition(storage: .automatic) }

    public static func region(_ region: MKCoordinateRegion) -> MapCameraPosition {
        MapCameraPosition(storage: .region(region))
    }

    public static func camera(_ camera: MapCamera) -> MapCameraPosition {
        MapCameraPosition(storage: .camera(camera))
    }

    public static func userLocation(fallback: MapCameraPosition) -> MapCameraPosition {
        MapCameraPosition(storage: .userLocation(fallback: fallback))
    }

    public static func item(_ item: MKMapItem) -> MapCameraPosition {
        MapCameraPosition(storage: .item(item))
    }

    public static func rect(_ rect: MKMapRect) -> MapCameraPosition {
        MapCameraPosition(storage: .rect(rect))
    }

    public static func == (lhs: MapCameraPosition, rhs: MapCameraPosition) -> Bool {
        lhs.storage == rhs.storage
    }
}

extension MapCameraPosition.Storage {
    static func == (lhs: MapCameraPosition.Storage, rhs: MapCameraPosition.Storage) -> Bool {
        switch (lhs, rhs) {
        case (.automatic, .automatic): return true
        case let (.region(a), .region(b)): return _mapSameRegion(a, b)
        case let (.camera(a), .camera(b)): return _mapSameCamera(a, b)
        case let (.userLocation(a), .userLocation(b)): return a == b
        case let (.item(a), .item(b)): return a.isEqual(b)
        case let (.rect(a), .rect(b)): return MKMapRectEqualToRect(a, b)
        default: return false
        }
    }
}

func _mapSameCoordinate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
    a.latitude == b.latitude && a.longitude == b.longitude
}

func _mapSameRegion(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
    _mapSameCoordinate(a.center, b.center)
        && a.span.latitudeDelta == b.span.latitudeDelta
        && a.span.longitudeDelta == b.span.longitudeDelta
}

func _mapSameCamera(_ a: MKMapCamera, _ b: MKMapCamera) -> Bool {
    _mapSameCoordinate(a.centerCoordinate, b.centerCoordinate)
        && a.centerCoordinateDistance == b.centerCoordinateDistance
        && a.heading == b.heading
        && a.pitch == b.pitch
}

public struct MapCameraUpdateFrequency: Hashable {
    enum Storage: Hashable {
        case continuous
        case onEnd
    }

    let storage: Storage

    public static let continuous = MapCameraUpdateFrequency(storage: .continuous)
    public static let onEnd = MapCameraUpdateFrequency(storage: .onEnd)
}

public struct MapCameraUpdateContext {
    public let camera: MapCamera
    public let region: MKCoordinateRegion
    public let rect: MKMapRect
    public let animated: Bool
}

public struct MapSelection<Value: Hashable>: Hashable {
    public var value: Value

    public init(_ value: Value) {
        self.value = value
    }
}

public struct MapInteractionModes: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let pan = MapInteractionModes(rawValue: 1 << 0)
    public static let zoom = MapInteractionModes(rawValue: 1 << 1)
    public static let rotate = MapInteractionModes(rawValue: 1 << 2)
    public static let pitch = MapInteractionModes(rawValue: 1 << 3)
    public static let all: MapInteractionModes = [.pan, .zoom, .rotate, .pitch]
}

struct _MapCameraChange {
    let frequency: MapCameraUpdateFrequency
    let perform: (MapCameraUpdateContext) -> Void
}

struct _MapCameraChangeKey: EnvironmentKey { static var defaultValue: _MapCameraChange? { nil } }

extension EnvironmentValues {
    var _mapCameraChange: _MapCameraChange? {
        get { self[_MapCameraChangeKey.self] }
        set { self[_MapCameraChangeKey.self] = newValue }
    }
}

extension View {
    public func onMapCameraChange(frequency: MapCameraUpdateFrequency = .onEnd, _ perform: @escaping (MapCameraUpdateContext) -> Void) -> some View {
        environment(\._mapCameraChange, _MapCameraChange(frequency: frequency, perform: perform))
    }
}
