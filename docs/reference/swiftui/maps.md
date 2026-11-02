# Maps

The map types of SwiftUI, in `frameworks/SwiftUI/src/Map*.swift` (`MapContent.swift`, `MapMarks.swift`, `MapCamera.swift`,
`MapStyles.swift`, `MapControls.swift`, `Map.swift`, `MapCoordinator.swift`, `MapCompat.swift`). Each is drawn by MapKit of
the backports (`frameworks/Backports/src/MapKit`, library `MapKitBackports`): `Map` is an `MKMapView`, its content becomes
annotations and overlays of that view, and the camera, the style and the controls are properties of it. The reason and
the design are in [the explanation](../../explanation/swiftui/maps.md).

The list below is what `expo-maps` (its SwiftUI views of `AppleMapsView`, `AppleMapsViewiOS17` and `AppleMapsViewiOS18`)
takes from SwiftUI, plus the initializers and modifiers that go with it. A type not in the list is not in the module.

## Types

| Type | Shape | iOS 6 behaviour |
| --- | --- | --- |
| `Map` | `init(position:interactionModes:content:)`, `init(position:interactionModes:selection:content:)` | a `UIViewRepresentable` over `MKMapView`, sized to its container |
| `MapContent` | protocol, one requirement `_mapElements(_:)` | the elements a value of it becomes, see below |
| `MapContentBuilder` | result builder: expressions, blocks, `if`, `if`/`else`, `#available` | builds a `TupleMapContent`, `_MapConditionalContent` or an optional |
| `EmptyMapContent`, `TupleMapContent` | the results of the builder | no element, and the elements of their parts in order |
| `ForEach` | `MapContent` where its content is | expands to its elements in order, with the same `id` rules as `ForEach` of views |
| `Marker` | `init(_:coordinate:)`, `init(_:systemImage:coordinate:)`, `init(_:monogram:coordinate:)` | `MKPinAnnotationView` in the tint nearest to red, green or purple, the title in the callout, the monogram or the symbol as the left accessory |
| `Annotation` | `init(_:coordinate:anchor:content:)` | a `UIHostingController`'s view in an `MKAnnotationView`, moved by `anchor` (default `.center`) |
| `MapPolyline` | `init(coordinates:contourStyle:)`, `init(_: MKPolyline)`; `ContourStyle` `.straight`, `.geodesic` | `MKPolylineRenderer`, or `MKGeodesicPolyline` for `.geodesic` |
| `MapPolygon` | `init(coordinates:)`, `init(_: MKPolygon)` | `MKPolygonRenderer` |
| `MapCircle` | `init(center:radius:)` | `MKCircleRenderer` |
| `UserAnnotation` | `init()` | MapKit's own blue dot (`showsUserLocation`) |
| `MapCameraPosition` | `.automatic`, `.region`, `.camera`, `.userLocation(fallback:)`, `.item`, `.rect` | see [camera](#camera) |
| `MapCamera` | `MKMapCamera` (a type alias), with `init(centerCoordinate:distance:heading:pitch:)` | the backport's `MKMapCamera` |
| `MapCameraUpdateContext` | `camera`, `region`, `rect`, `animated` | the state of the map when the update is reported |
| `MapCameraUpdateFrequency` | `.onEnd`, `.continuous` | see [camera](#camera) |
| `MapInteractionModes` | `pan`, `zoom`, `rotate`, `pitch`, `all` | the view's `scrollEnabled`, `zoomEnabled`, `rotateEnabled`, `pitchEnabled` |
| `MapSelection` | `init(_:)`, `value` | the tag that a marker, an annotation or a shape carries; the selection is the one of the binding |
| `MapReader`, `MapProxy` | `MapProxy.convert(_:from:)`, `convert(_:to:)` | the map's own conversion, in `.local` and `.global` (`.named` gives nil) |
| `MapStyle` | protocol, with `Elevation` (`.automatic`, `.flat`, `.realistic`) and `StandardEmphasis` (`.automatic`, `.muted`) | `_apply(to:)` sets the map type, the buildings and the points of interest |
| `StandardMapStyle`, `HybridMapStyle`, `ImageryMapStyle` | from `.standard(...)`, `.hybrid(...)`, `.imagery(...)` | the map types `standard`, `hybrid` and `satellite`, with the flyover types for `.realistic` and the muted type for `.muted` |
| `PointOfInterestCategories` | `.all`, `.none`, `including(_:)`, `excluding(_:)` | `showsPointsOfInterest` and the `MKPointOfInterestFilter` of the categories |
| `MapCompass`, `MapScaleView`, `MapPitchToggle`, `MapUserLocationButton` | views for `mapControls` | MapKit's compass, scale, pitch and user-tracking buttons, shown only when listed |
| `MapFeatureSelectionAccessory` | `.automatic`, `.hidden` | ignored, see [ignored](#ignored) |

The helper types that the builder produces (`_MapElement`, `_MapElementStyle`, `_MarkerElement`, `_AnnotationElement`,
`_PolylineElement`, `_PolygonElement`, `_CircleElement`, `_MarkerGlyph`) are public because `MapContent` is: an app does not
name them.

## Modifiers

| Modifier | Applies to | Behaviour |
| --- | --- | --- |
| `tag(_:)` | any `MapContent` | the value a tap selects; `MapSelection` is what a `Map(selection:)` binding holds |
| `tint(_:)` | a marker and what contains it | the pin's colour, nearest of three |
| `stroke(_:lineWidth:)` | polyline, polygon, circle | the stroke colour, and width in points (default 1) |
| `foregroundStyle(_:)` | polygon, circle | the fill colour; the default fill is blue at a quarter of its alpha |
| `mapStyle(_:)` | any view, read by the maps in it | the style of each `Map` below it; the default is `.standard()` |
| `mapControls { }` | any view, read by the maps in it | the controls listed in the builder are shown; the rest are not |
| `onMapCameraChange(frequency:_:)` | any view, read by the maps in it | called with a `MapCameraUpdateContext` |
| `lookAroundViewer(isPresented:initialScene:allowsNavigation:showsRoadLabels:pointsOfInterest:onDismiss:)` | any view, read by the maps in it | presents `MKLookAroundViewController` from the top controller; it clears `isPresented` when it is dismissed |
| `mapFeatureSelectionAccessory(_:)` | any view | ignored |

## Elements and the default look

- A polyline's default stroke is blue, 1 point. A polygon or a circle has a blue fill at a quarter of its alpha and a blue
  stroke, 1 point. Each default is what MapKit draws with nothing else set.
- A marker without a tint is red.
- `Annotation` draws its content only: its title is not shown, as in SwiftUI.
- `Marker(_:systemImage:coordinate:)` draws the symbol with `SymbolGlyphs`, the module's own drawing of the common SF Symbols;
  a name it does not know is drawn as the placeholder.

## Camera

`MapCameraPosition` is compared by value: two regions with the same centre and span are the same position, and so are two
cameras with the same centre, distance, heading and pitch.

- The position is applied when it changes from the last one applied. `.automatic` fits the overlays and the annotations (with a
  margin of a tenth); with nothing to fit, the map keeps its region. `.userLocation(fallback:)` centres on the user's location
  when it is known, and applies the fallback otherwise.
- When the user moves the map and the bound position is a `.region` or a `.camera`, the binding is written with the map's
  region (or its camera, when the heading or the pitch is not zero), so the binding follows the user.
- `.onEnd` reports when MapKit's region change ends. `.continuous` reports on each display frame while the region changes
  (a `CADisplayLink`, from the start of the change until its end), and once more at the end.

## Selection

A marker or an annotation with a tag is selected when the user taps it, and the binding holds its tag. A polyline, polygon or circle
with a tag is selected when a tap falls on it (on a line, within 20 points; in a polygon or a circle, anywhere inside). A tap on
nothing clears the selection. A binding set to a tag selects its annotation, and one set to nil deselects them all.

## Ignored

`mapFeatureSelectionAccessory(_:)` is declared and ignored. MapKit on iOS 6 has no selectable map features (the points of
interest of iOS 18), so the points of interest are not selectable, and the call says so in the log.

## Tests

- `frameworks/SwiftUI/tests/typechecks/maps/positive.swift` takes the calls that `expo-maps` makes, and must compile.
  `maps-negative` refuses a `Marker` as a `View`. Both are targets of `SwiftUITypeChecks`.
- `frameworks/SwiftUI/tests/main.swift`, the last section: the builder's elements, their tags and tints, the strokes and the
  fills, and the equality of the camera positions. It runs in the emulator (`emulate.lua tests`).
