# Why the maps are built on MapKit

Apple's SwiftUI draws its map with MapKit's own renderer, which is closed to us. On iOS 6 there is no such renderer to reuse,
but there is `MKMapView`, which has been the map of the platform since iOS 3, and the backports of this repository bring
the rest of MapKit that the SwiftUI API needs (the camera of iOS 7, the buttons of iOS 11, the look-around controller of iOS
16, the point-of-interest filter of iOS 13). So a `Map` is an `MKMapView`, and the SwiftUI values are the description it is
given. The map looks like the platform's map, which is what an iOS 6 application should show.

## The content is a description, not a view

A `MapContent` value is not a view. Its `_mapElements(_:)` returns what it stands for: a marker, an annotation, a polyline, a
polygon, a circle or the user's location. The builder makes a tree of these values, and `Map` flattens the tree into one list
in order. Modifiers do not wrap a view: `tint`, `stroke`, `foregroundStyle` and `tag` pass a style down the tree
(`_MapStyledContent` changes the `_MapElementStyle` of its content), so `Marker(...).tint(.green)` and a whole `ForEach` under
`.tint` both reach the elements they apply to, as they do in SwiftUI.

The list is then applied to the map by `MapCoordinator`:

- Overlays (polyline, polygon, circle) are rebuilt only when their shapes or styles differ from the last list, because a
  rebuild removes and adds them and MapKit redraws them.
- Annotations are kept by position in the list. A new annotation object is made where the list grows, and an existing one is
  moved, retitled or given new content where it is still there, so that MapKit moves a pin without removing it. A change of
  kind (a marker where there was an annotation) removes the rest of the list from that point.
- A `Annotation` hosts its SwiftUI content in a `UIHostingController` and places its view by the anchor and the measured size.

## The environment carries what the map needs from its ancestors

The map's style, its controls, its camera-change handler, its look-around request and the reader's proxy are not arguments of
`Map`. They are environment values set by the modifiers `mapStyle`, `mapControls`, `onMapCameraChange`, `lookAroundViewer` and
`MapReader`, which wrap the view that holds the map, as in SwiftUI. The representable reads them in `updateUIView`. This matches
the way the modifiers are written and read: a `.mapStyle` applies to every map below it, and a modifier placed after the map
(as in `Map { ... }.mapStyle(...)`) still applies to it.

`mapControls` is different from the others in one respect: its builder holds views (`MapCompass()` and the rest) that are
never shown. They are read once, for their kinds, by walking the group's children, and the map shows the native button of
each kind listed. The views themselves are primitive views that draw nothing, so a stray one does nothing.

## The camera is a value, not a command

`MapCameraPosition` is the state. The map applies a position when it differs from the last one it applied, and it writes its
own state back when the user moves the map. The write-back is the reason for the comparison: after the map reports a region
the binding holds that region, so the next update finds the position equal to the last one applied and does nothing. Without
it, every move would be applied again, and every application would report the move again.

`.automatic`, `.userLocation(fallback:)` and `.item` are not written back, because they are not a view of the map: the map
keeps the request, and the user's pan is the state it shows.

## Selection goes through the tags

A `MapSelection` tag is an `AnyHashable` on each element, and the binding is type-erased in `Map` to the same `AnyHashable`
(`_MapSelectionLink`). A tap on a marker or an annotation is MapKit's selection, and the coordinator passes its tag to the
binding. A tap on a polyline, polygon or circle is not a MapKit selection, so the coordinator tests the tap against each shape:
a polyline by its distance to each segment, a polygon by the even-odd rule, a circle by its radius in metres. The last shape
that the tap falls on is the one selected. A tap on an annotation view does not reach that test, because MapKit already took it.

## What is not the platform's

- Overlay fills and strokes use the platform's colours, not SwiftUI's `ShapeStyle`: `foregroundStyle` and `stroke` take a
  `Color`.
- Pins are the three colours of `MKPinAnnotationView`, so a tint is drawn as the nearest of them.
- `mapFeatureSelectionAccessory` is ignored, because MapKit on iOS 6 cannot select a point of interest.
- Calls into MapKit members that the SDK declares for later iOS releases go through `NSObject.setValue(_:forKey:)` after a
  `responds(to:)` check (`MapCompat.swift`), as the module's other bridges do: the backports define them at run time, and an
  availability error on the Swift side would stop a call that the platform answers.
- `Map(scope:)`, `MapScope` and the `Map` initializers that take bounds are not in the module; no application that expo-maps
  needs uses them.
