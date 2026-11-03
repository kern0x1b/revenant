import UIKit
import MapKit

public struct Map<Content: MapContent>: View {
    let position: Binding<MapCameraPosition>
    let interactionModes: MapInteractionModes
    let selection: _MapSelectionLink?
    let content: Content

    public init(position: Binding<MapCameraPosition>, interactionModes: MapInteractionModes = .all, @MapContentBuilder content: () -> Content) {
        self.position = position
        self.interactionModes = interactionModes
        self.selection = nil
        self.content = content()
    }

    public init<Value: Hashable>(
        position: Binding<MapCameraPosition>,
        interactionModes: MapInteractionModes = .all,
        selection: Binding<MapSelection<Value>?>,
        @MapContentBuilder content: () -> Content
    ) {
        self.position = position
        self.interactionModes = interactionModes
        self.selection = _MapSelectionLink(
            current: { selection.wrappedValue.map { AnyHashable($0) } },
            assign: { value in selection.wrappedValue = value?.base as? MapSelection<Value> }
        )
        self.content = content()
    }

    public var body: some View {
        _MapRepresentable(position: position, interactionModes: interactionModes, selection: selection, content: content)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct _MapSelectionLink {
    let current: () -> AnyHashable?
    let assign: (AnyHashable?) -> Void
}

final class _MapProxyBox {
    weak var view: MKMapView?
}

struct _MapProxyKey: EnvironmentKey { static var defaultValue: _MapProxyBox? { nil } }

extension EnvironmentValues {
    var _mapProxy: _MapProxyBox? {
        get { self[_MapProxyKey.self] }
        set { self[_MapProxyKey.self] = newValue }
    }
}

public struct MapProxy {
    let box: _MapProxyBox

    public func convert(_ point: CGPoint, from space: CoordinateSpace) -> CLLocationCoordinate2D? {
        guard let view = box.view else { return nil }
        switch space {
        case .local:
            return view.convert(point, toCoordinateFrom: view)
        case .global:
            guard let window = view.window else { return nil }
            return view.convert(window.convert(point, to: view), toCoordinateFrom: view)
        case .named:
            return nil
        }
    }

    public func convert(_ coordinate: CLLocationCoordinate2D, to space: CoordinateSpace) -> CGPoint? {
        guard let view = box.view else { return nil }
        let point = view.convert(coordinate, toPointTo: view)
        switch space {
        case .local:
            return point
        case .global:
            guard let window = view.window else { return nil }
            return view.convert(point, to: window)
        case .named:
            return nil
        }
    }
}

public struct MapReader<Content: View>: View {
    @State private var box = _MapProxyBox()
    let content: (MapProxy) -> Content

    public init(@ViewBuilder content: @escaping (MapProxy) -> Content) {
        self.content = content
    }

    public var body: some View {
        content(MapProxy(box: box)).environment(\._mapProxy, box)
    }
}

struct _MapUpdate {
    let elements: [_MapElement]
    let position: Binding<MapCameraPosition>
    let interactionModes: MapInteractionModes
    let selection: _MapSelectionLink?
    let style: (any MapStyle)?
    let controls: Set<_MapControlKind>
    let cameraChange: _MapCameraChange?
    let lookAround: _MapLookAround?
    let proxy: _MapProxyBox?
}

struct _MapRepresentable<Content: MapContent>: UIViewRepresentable {
    typealias UIViewType = MKMapView
    typealias Coordinator = MapCoordinator

    let position: Binding<MapCameraPosition>
    let interactionModes: MapInteractionModes
    let selection: _MapSelectionLink?
    let content: Content

    func makeCoordinator() -> MapCoordinator { MapCoordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let view = MKMapView(frame: .zero)
        view.delegate = context.coordinator
        context.coordinator.install(on: view)
        return view
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        let environment = context.environment
        context.coordinator.update(view, _MapUpdate(
            elements: content._mapElements(_MapElementStyle()),
            position: position,
            interactionModes: interactionModes,
            selection: selection,
            style: environment._mapStyle,
            controls: environment._mapControls,
            cameraChange: environment._mapCameraChange,
            lookAround: environment._mapLookAround,
            proxy: environment._mapProxy
        ))
    }
}
