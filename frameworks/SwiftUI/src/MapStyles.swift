import UIKit
import MapKit

public protocol MapStyle {
    func _apply(to mapView: MKMapView)

    typealias Elevation = _MapStyleElevation
    typealias StandardEmphasis = _MapStyleEmphasis
}

public enum _MapStyleElevation: Hashable {
    case automatic
    case flat
    case realistic
}

public enum _MapStyleEmphasis: Hashable {
    case automatic
    case muted
}

public struct PointOfInterestCategories: Hashable {
    enum Storage: Hashable {
        case all
        case including([String])
        case excluding([String])
    }

    let storage: Storage

    public static let all = PointOfInterestCategories(storage: .all)
    public static let none = PointOfInterestCategories(storage: .including([]))

    public static func including(_ categories: [MKPointOfInterestCategory]) -> PointOfInterestCategories {
        PointOfInterestCategories(storage: .including(categories.map(\.rawValue)))
    }

    public static func excluding(_ categories: [MKPointOfInterestCategory]) -> PointOfInterestCategories {
        PointOfInterestCategories(storage: .excluding(categories.map(\.rawValue)))
    }

    var pointOfInterestFilter: MKPointOfInterestFilter? {
        switch storage {
        case .all:
            return nil
        case .including(let names):
            return MKPointOfInterestFilter(including: names.map(MKPointOfInterestCategory.init(rawValue:)))
        case .excluding(let names):
            return names.isEmpty ? nil : MKPointOfInterestFilter(excluding: names.map(MKPointOfInterestCategory.init(rawValue:)))
        }
    }

    var showsPointsOfInterest: Bool {
        if case .including(let names) = storage, names.isEmpty { return false }
        return true
    }

    func apply(to mapView: MKMapView) {
        mapView._mapSetFlag("showsPointsOfInterest", showsPointsOfInterest)
        mapView._mapSetValue("pointOfInterestFilter", pointOfInterestFilter)
    }
}

extension MKMapType {
    static let mutedStandardType = MKMapType(rawValue: 5)!
    static let satelliteFlyoverType = MKMapType(rawValue: 3)!
    static let hybridFlyoverType = MKMapType(rawValue: 4)!
}

public struct StandardMapStyle: MapStyle {
    let elevation: MapStyle.Elevation
    let emphasis: MapStyle.StandardEmphasis
    let pointsOfInterest: PointOfInterestCategories
    let showsTraffic: Bool

    public func _apply(to mapView: MKMapView) {
        mapView.mapType = emphasis == .muted ? MKMapType.mutedStandardType : MKMapType.standard
        mapView.showsBuildings = elevation == .realistic
        pointsOfInterest.apply(to: mapView)
        mapView._mapSetFlag("showsTraffic", showsTraffic)
    }
}

public struct HybridMapStyle: MapStyle {
    let elevation: MapStyle.Elevation
    let pointsOfInterest: PointOfInterestCategories
    let showsTraffic: Bool

    public func _apply(to mapView: MKMapView) {
        mapView.mapType = elevation == .realistic ? MKMapType.hybridFlyoverType : MKMapType.hybrid
        mapView.showsBuildings = elevation == .realistic
        pointsOfInterest.apply(to: mapView)
        mapView._mapSetFlag("showsTraffic", showsTraffic)
    }
}

public struct ImageryMapStyle: MapStyle {
    let elevation: MapStyle.Elevation

    public func _apply(to mapView: MKMapView) {
        mapView.mapType = elevation == .realistic ? MKMapType.satelliteFlyoverType : MKMapType.satellite
        mapView.showsBuildings = elevation == .realistic
        mapView._mapSetFlag("showsPointsOfInterest", false)
        mapView._mapSetFlag("showsTraffic", false)
    }
}

extension MapStyle where Self == StandardMapStyle {
    public static func standard(
        elevation: MapStyle.Elevation = .automatic,
        emphasis: MapStyle.StandardEmphasis = .automatic,
        pointsOfInterest: PointOfInterestCategories = .all,
        showsTraffic: Bool = false
    ) -> StandardMapStyle {
        StandardMapStyle(elevation: elevation, emphasis: emphasis, pointsOfInterest: pointsOfInterest, showsTraffic: showsTraffic)
    }
}

extension MapStyle where Self == HybridMapStyle {
    public static func hybrid(
        elevation: MapStyle.Elevation = .automatic,
        pointsOfInterest: PointOfInterestCategories = .all,
        showsTraffic: Bool = false
    ) -> HybridMapStyle {
        HybridMapStyle(elevation: elevation, pointsOfInterest: pointsOfInterest, showsTraffic: showsTraffic)
    }
}

extension MapStyle where Self == ImageryMapStyle {
    public static func imagery(elevation: MapStyle.Elevation = .automatic) -> ImageryMapStyle {
        ImageryMapStyle(elevation: elevation)
    }
}

struct _MapStyleKey: EnvironmentKey { static var defaultValue: (any MapStyle)? { nil } }

extension EnvironmentValues {
    var _mapStyle: (any MapStyle)? {
        get { self[_MapStyleKey.self] }
        set { self[_MapStyleKey.self] = newValue }
    }
}

extension View {
    public func mapStyle<Style: MapStyle>(_ style: Style) -> some View {
        environment(\._mapStyle, style as any MapStyle)
    }
}
