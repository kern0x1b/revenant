import UIKit
import MapKit

enum _MapControlKind: Hashable {
    case compass
    case scale
    case pitch
    case userLocation
}

protocol _MapControlView {
    var _controlKind: _MapControlKind { get }
}

public struct MapCompass: View, PrimitiveView, _MapControlView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init() {}
    var _controlKind: _MapControlKind { .compass }
    func makeNode(_ env: EnvironmentValues) -> Node { EmptyView().makeNode(env) }
}

public struct MapScaleView: View, PrimitiveView, _MapControlView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init() {}
    var _controlKind: _MapControlKind { .scale }
    func makeNode(_ env: EnvironmentValues) -> Node { EmptyView().makeNode(env) }
}

public struct MapPitchToggle: View, PrimitiveView, _MapControlView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init() {}
    var _controlKind: _MapControlKind { .pitch }
    func makeNode(_ env: EnvironmentValues) -> Node { EmptyView().makeNode(env) }
}

public struct MapUserLocationButton: View, PrimitiveView, _MapControlView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init() {}
    var _controlKind: _MapControlKind { .userLocation }
    func makeNode(_ env: EnvironmentValues) -> Node { EmptyView().makeNode(env) }
}

func _mapControlKinds(in view: any View) -> Set<_MapControlKind> {
    if let control = view as? _MapControlView { return [control._controlKind] }
    if let group = view as? GroupView {
        return group.childViews.reduce(into: Set<_MapControlKind>()) { $0.formUnion(_mapControlKinds(in: $1)) }
    }
    return []
}

struct _MapControlsKey: EnvironmentKey { static var defaultValue: Set<_MapControlKind> { [] } }

extension EnvironmentValues {
    var _mapControls: Set<_MapControlKind> {
        get { self[_MapControlsKey.self] }
        set { self[_MapControlsKey.self] = newValue }
    }
}

extension View {
    public func mapControls<Controls: View>(@ViewBuilder _ controls: () -> Controls) -> some View {
        _MapControlsModifier(base: self, kinds: _mapControlKinds(in: controls()))
    }
}

public struct _MapControlsModifier<Base: View>: View {
    let base: Base
    let kinds: Set<_MapControlKind>

    public var body: some View {
        base.environment(\._mapControls, kinds)
    }
}

public struct MapFeatureSelectionAccessory: Hashable {
    enum Storage: Hashable {
        case automatic
        case hidden
    }

    let storage: Storage

    public static let automatic = MapFeatureSelectionAccessory(storage: .automatic)
    public static let hidden = MapFeatureSelectionAccessory(storage: .hidden)
}

extension View {
    public func mapFeatureSelectionAccessory(_ accessory: MapFeatureSelectionAccessory?) -> some View {
        ignored(self, "mapFeatureSelectionAccessory", "MapKit has no selectable map features before iOS 18; points of interest are not selectable")
    }
}

final class _MapLookAroundController: MKLookAroundViewController {
    var disappeared: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disappeared?()
    }
}

struct _MapLookAround {
    let isPresented: Binding<Bool>
    let scene: MKLookAroundScene?
    let allowsNavigation: Bool
    let showsRoadLabels: Bool
    let pointsOfInterest: PointOfInterestCategories
    let onDismiss: (() -> Void)?
}

struct _MapLookAroundKey: EnvironmentKey { static var defaultValue: _MapLookAround? { nil } }

extension EnvironmentValues {
    var _mapLookAround: _MapLookAround? {
        get { self[_MapLookAroundKey.self] }
        set { self[_MapLookAroundKey.self] = newValue }
    }
}

extension View {
    public func lookAroundViewer(
        isPresented: Binding<Bool>,
        initialScene: MKLookAroundScene?,
        allowsNavigation: Bool = true,
        showsRoadLabels: Bool = true,
        pointsOfInterest: PointOfInterestCategories = .all,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        environment(\._mapLookAround, _MapLookAround(
            isPresented: isPresented,
            scene: initialScene,
            allowsNavigation: allowsNavigation,
            showsRoadLabels: showsRoadLabels,
            pointsOfInterest: pointsOfInterest,
            onDismiss: onDismiss
        ))
    }
}
