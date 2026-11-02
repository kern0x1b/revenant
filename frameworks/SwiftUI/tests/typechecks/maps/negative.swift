import SwiftUI
import MapKit

func markerIsNotAView() -> some View {
    Marker("x", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
}
