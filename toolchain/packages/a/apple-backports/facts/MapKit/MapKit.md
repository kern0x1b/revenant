# MapKit on iOS 6: the renderers, the camera, the configurations and the snapshot

iOS 6.1.3 has an `MKMapView` and the whole of the `MKOverlayView` drawing path underneath it. It
has none of what iOS 7 and later put on top: no `MKOverlayRenderer` and no renderer tree, no
overlay levels, no camera, no snapshotter, no map configuration, no marker pin, no cluster, no
annotation view reuse. This is what this port carries, and what it does with what the release
already has.

## The measured floor

`apple.dyld`'s own `first_releases`, walking every held rung of the cache ladder and asking which
release first exports each symbol:

| class | first held release that exports it |
| --- | --- |
| `MKMapView`, `MKAnnotationView`, `MKCircle`, `MKPolygon`, `MKPolyline`, `MKMultiPoint`, `MKOverlayView`, `MKPlacemark` | 3.0 – 3.2 (the release has them) |
| `MKOverlayRenderer`, `MKOverlayPathRenderer`, `MKCircleRenderer`, `MKPolygonRenderer`, `MKPolylineRenderer`, `MKTileOverlay`, `MKTileOverlayRenderer`, `MKMapCamera`, `MKMapSnapshot`, `MKMapSnapshotOptions`, `MKMapSnapshotter`, `MKDistanceFormatter`, `MKScaleView`, `MKGeodesicPolyline` | 7.0 |
| `MKMarkerAnnotationView`, `MKClusterAnnotation` | 11.0 |
| `MKMapConfiguration`, `MKStandardMapConfiguration`, `MKHybridMapConfiguration`, `MKImageryMapConfiguration`, `MKIconStyle`, `MKMapFeatureAnnotation`, `MKMapCameraBoundary`, `MKMapCameraZoomRange`, `MKMultiPolygon`, `MKMultiPolygonRenderer`, `MKMultiPolyline`, `MKMultiPolylineRenderer`, `MKPointOfInterestFilter`, `MKGradientPolylineRenderer` | 16.0 (the 13.0 and 14.0 releases are not held, so 16.0 is the first held rung above them and the SDK header's own 13.0 and 14.0 are the true arrivals) |

Every entry is `minimum: "6.0"`: 6.0 is the port's own floor, and the release has none of these
classes below 7.0, so the whole declared surface of each is carried from 6.0 and from 7.0 on the
release's own class answers. That is why one object file per class, and why the class's later
members (a 14.0 `strokeStart`, a 16.0 `blendMode`) ride along with the class rather than being
split into an object of their own: on the releases where the class is missing, the whole of what
the SDK's header declares on it is what belongs there.

## The renderer is the release's own overlay view

`MKOverlayRenderer` is declared by the SDK 16.4 header as an `NSObject`. It is built here as a
subclass of the release's own `MKOverlayView`, which is `MKOverlayView` at run time and an
`NSObject` in the header. Two reasons, both mechanical:

- the release's `MKMapView` sizes an overlay view and drives it with `canDrawMapRect:zoomScale:`
  and `drawMapRect:zoomScale:inContext:`, so a renderer that is a real overlay view is one the
  release's map view can host and draw without knowing anything new;
- `alpha` is then the view's own alpha, which is what the pixels MapKit draws through the
  renderer are composited at, rather than a number nothing reads.

The 16.4 header hides that superclass, so the objects that build a renderer reach the view half
through the `RevenantOverlayView` protocol in `RevenantMapKit.h`, and the two initialisers go through
the release's own `-[MKOverlayView initWithOverlay:]` and `-initWithCoder:` because there is no
other way to build one of this class as one of them.

## The transform between map points and the renderer's own points

Apple's renderer is handed a map rect and draws in the overlay's coordinates. Here the renderer is
a view inside a map view, so the two spaces are tied by the overlay's own `boundingMapRect` and the
view's own `bounds`, and the scale is read off the view rather than off the map view's zoom scale
(which the 16.4 header does not even declare) -- the view and the overlay are scaled together, and
the view is the one that can be measured. `pointForMapPoint:`, `mapPointForPoint:`,
`rectForMapRect:` and `mapRectForRect:` are that transform and its inverse, recomputed on every
call, so a stale scale is never drawn with. Where the release exports a projection, it is the
release's own: `MKMapPointForCoordinate`, `MKCoordinateForMapPoint`,
`MKMetersPerMapPointAtLatitude`, `MKMapPointsPerMeterAtLatitude`, `MKCoordinateRegionForMapRect`,
`MKMapRectUnion`, `MKMapRectIntersection`, `MKMapSizeWorld` and `MKMapRectWorld` are all in the
armv7 cache from 3.2 (measured) and are called directly. What MapKit.framework does not export on
this release, and what `RevenantMapKit` therefore has, is the map size of a zoom scale, the map rect
of a coordinate region, and the bearing between two coordinates.

## The delegate bridge

This is the part that makes the renderers draw rather than merely exist. The release's map view
asks its delegate for an `MKOverlayView` with `mapView:viewForOverlay:`; a program written since
iOS 7 does not implement that, it implements `mapView:rendererForOverlay:`. So
`-[MKMapView setDelegate:]` puts a `RevenantMapKitDelegate` in front of the caller's own object,
that proxy answers the release's two questions out of the program's two, and every other message
goes to the program untouched through `forwardingTargetForSelector:`. `-[MKMapView delegate]`
gives the caller's own object back, so a program that compares its map view's delegate with itself
still finds itself. The release's own implementations are reached through
`class_getInstanceMethod([MKAnnotationView class], ...)`, which is where the property the MKAnnotation
protocol declares is implemented and which `MKMapView` inherits without overriding; this is the one
place in this library that depends on that inheritance, and it is the first thing to re-check if a
future release's `MKMapView` implements `delegate` itself.

## What is honest about a flat map

The release's map view cannot rotate or pitch. `MKMapCamera` therefore stores the heading and the
pitch and derives everything else from the release's own projection: `centerCoordinateDistance`
and the deprecated `altitude` are two names for one number (the eye ratio MapKit's own camera
keeps, 1.5), and `-setCamera:animated:` turns a camera into the region the release's map view can
actually show. `+cameraLookingAtMapItem:forViewSize:allowPitch:` needs a coordinate for the map item, and
the release's own `MKMapItem` has one: `-placemark`, `-initWithPlacemark:` and
`-setPlacemark:` are in the armv7 cache of 6.1.3 (measured with `apple.objc.inventory`), so a map
item from the release's own search, or from the geocoding below, carries the coordinate the camera
frames. A map item with no placemark has none, and the camera then frames the whole world, which is
what fits in the view, and the registry says so.

> An earlier version of this file said the opposite -- that iOS 6's `MKMapItem` is a name and an
> address with no place. That was wrong, and the measurement that corrected it is the same inventory
> run: the release has the placemark and has never had `+mapItemWithName:address:` or `-address`.

The map configurations are value objects: the elevation style, the emphasis style, the point of
interest filter and showsTraffic are stored, copied, compared and archived, and the
`MKMapView` category does not read most of them, because a map type has no counterpart to them.
`MKMapFeatureAnnotation` is the same: a map feature is something the map itself knows about, and a
release whose map has no features has none for it, so its own parts answer as they are and its
coordinate is the invalid one until a map answers for it.

## The constants, and where their values come from

Every MapKit constant this port carries is read out of **macOS 27.0 (build 26A428)'s own
`MapKit.framework`**: a generated probe declares each name as the extern its own SDK header declares,
links against that framework and prints what the symbol holds. All 81 answer, and
`tests/backports/host/mapkit-constants` compares the port's value with the host's on every run, for
every name, generated from the port's own constant files so the probe cannot fall behind the tree. A
name the host's framework does not export is a link error in the probe, so "this port invented it"
cannot pass quietly.

Two are cross-checked against a different release of Apple's own and they agree, which is what makes
the host reading more than one machine's opinion:

| constant | macOS 27 image | an iOS cache |
| --- | --- | --- |
| `MKMapCameraZoomDefault` | `-1` | `-1.0`, the eight bytes at the address `_MKMapCameraZoomDefault` has in the MapKit image `dyld.extract` took of the arm64e dyld shared cache of 18.0 |
| `MKMapItemTypeIdentifier` | `com.apple.mapkit.map-item` | the same, read with `tools/corpus/cache-value.lua` out of the arm64 cache of 12.0 |

The seventy-three `MKPointOfInterestCategory*` values are Apple's own `MKPOICategory*` strings
(`MKPointOfInterestCategoryCafe` is `MKPOICategoryCafe`), which is why a filter built against them is
a filter Apple's own map understands. The constants sit in five object files, one per release that
first exports them, measured through `apple.dyld`'s `first_releases`: 7.1, 9.0, 11.0, 16.0 and 18.0.

## The thirteen properties the release's map view has no answer for

Measured with `apple.objc.inventory` against the armv7 dyld shared cache of 6.1.3: the release's
`MKMapView` has 228 public instance methods, and its map surface is a region
(`-setRegion:animated:`, `-setCenterCoordinate:animated:`, `-visibleMapRect`, `-mapRectThatFits:`,
`-regionThatFits:`, `-convertCoordinate:toPointToView:`), a map type (`-mapType`), the user location
(`-userTrackingMode`, `-setUserTrackingMode:animated:`, `-showsUserLocation`) and the overlays. Its
own `-_rotationState`, `-canRotateForHeading` and `-setShouldRotateForHeading:` are the private
machinery that turns the map to follow the compass; that is not a public rotation and is not used.

So the map stays the release's and the newer API is put on top of it:

- **`rotateEnabled`, `pitchEnabled` and the camera's heading and pitch** are a transform on the
  release's own layer: a turn about the vertical for the heading, and for the pitch a projection of
  a plane at the eye distance a camera of that distance keeps, turned by the pitch. A real
  `UIRotationGestureRecognizer` on the map view drives the turn and is refused while `rotateEnabled`
  is NO. The annotation views are asked for through the release's own public `-viewForAnnotation:`
  and given the inverse of the turn, so a pin stands up on a rotated map. This is a projection of a
  plane, not the release's own three-dimensional camera, and the difference is the difference between
  rotating a picture of a map and having a camera above one.
- **`showsCompass`** puts this port's own `MKCompassButton` on the map view, drawn at the map's own
  turn, with `-compassVisibility` as the header documents it (adaptive hides it when the map is
  already facing north) and a tap that animates the map back to north through the release's own
  `-setRegion:animated:`.
- **`showsScale`** puts the `MKScaleView` on the map view; its bar is drawn from the release's own
  `visibleMapRect` and the release's own `MKMetersPerMapPointAtLatitude`.
- **`showsUserTrackingButton`** puts the `MKUserTrackingButton` on the map view, and that button
  drives the release's own `-setUserTrackingMode:animated:`, so following the user is the release's
  mechanism and not a copy of it.
- **`cameraBoundary`, `cameraZoomRange` and their two setters** narrow every region this port puts on
  the map: the boundary to the boundary's own region (through the release's own
  `MKCoordinateRegionForMapRect`), the zoom range to its distance in metres against the map view's
  own visible rect. A nil boundary is the whole world. What they do *not* do is constrain the
  release's own panning, which is the release's own gesture: the boundary is the camera's, and on
  this port the camera is what this port sets.
- **`preferredConfiguration`** is the release's own map type in the iOS 16 spelling: reading it back
  gives a standard, hybrid or imagery configuration standing for the map that is on screen, and
  setting one sets the map type the release's own map draws. The rest of a configuration -- the
  elevation style, the emphasis style, the point of interest filter, `showsTraffic` -- has no
  counterpart in a map type and is stored and given back.

And the four that cannot be done for any reason other than that the release's map draws one fixed
tile style, which is `inert` and not `implemented`:

| property | why, measured |
| --- | --- |
| `showsTraffic` | the release's map has no traffic layer to draw or not draw, and no `showsTraffic` in its 228 public methods |
| `showsBuildings` | the release's map draws its buildings inside its own vector tiles; there is no way to ask it for a style without them |
| `showsPointsOfInterest` | the same, for its points of interest |
| `pointOfInterestFilter` | the release's map takes no filter, so there is nothing for one to act on |

`selectableMapFeatures` and `pitchButtonVisibility` are `inert` for the same reason: the release's
map view has no selection of its own and no pitch button. All six store and read back, and say so
once in the log the first time they are used, which is what the registry README asks of an `inert`
entry.

## The services, and what the release already has

Measured, not assumed, and it changes the shape of the work:

- **`MKLocalSearch`, `MKLocalSearchRequest` and `MKLocalSearchResponse` are on the release** --
  `apple.dyld`'s `first_releases` puts all three at 6.1. So there is nothing to backport for
  `MKLocalSearch`: the release's own class answers, against Apple's own service, which is the best
  possible answer. Only `MKLocalSearchCompleter` (7.0) and `MKLocalSearchCompletion` (9.3) are
  missing, and the completer is a different problem again.
- **`CLGeocoder` is on the release** (5.0), with `-geocodeAddressString:completionHandler:`,
  `-geocodeAddressString:inRegion:completionHandler:`, `-geocodeAddressDictionary:completionHandler:`
  and `-reverseGeocodeLocation:completionHandler:` in the 6.1.3 cache, together with a `CLPlacemark`
  carrying the whole address vocabulary. So `MKGeocodingRequest` and `MKReverseGeocodingRequest` are
  built on the release's own geocoder, against Apple's own service, and are not an external service
  at all. The map items they answer with are the release's own `MKMapItem`, built through the
  release's own `-initWithPlacemark:` and `-setName:`.
- **`MKDirections` (7.0) and `MKDirectionsResponse` have no release counterpart at all**, so those
  are the ones that need an open provider, and the delivery has to name it.

## R4: the names no 16.4 header declares

R4 (`patch-merge` §4): a stack that adds or renames an **implemented** registry entry no SDK header
declares changes what the generator's rule (`tools/gen/target_availability.lua`) leaves alone. The port's
headers are rendered from the SDK the build uses -- 16.4, the only one this machine holds. Every one of the
rows below is a name no SDK header declares, so a swift-runtime build with backports gets no port header
for them: Swift code naming `MKGeocodingRequest` sees the 16.4 header, not this.

| set | rows | why they are real |
| --- | --- | --- |
| the 26.0 classes | `MKAddress`, `MKAddressRepresentations`, `MKGeocodingRequest`, `MKReverseGeocodingRequest` and their members | read out of the SDK 26.2's headers, which declare them; the 16.4 headers do not |
| `MKAddressFilter` and its six option bits | 7 rows | the same, and its object is of its own measured release (18.0) |
| the category strings | 34 `MKPointOfInterestCategory*` and `MKLaunchOptionsDirectionsModeCycling` | Apple's own values, measured out of macOS 27.0's MapKit.framework by `tests/backports/host/mapkit-constants`, which compares all 81 on every run |
| the 14.0 / 15.0 / 16.0 / 17.4 / 18.0 / 26.0 CarPlay members | the rest of the 26 | read out of the SDK 26.2's CarPlay headers, which declare them |

This is not a defect in this delivery, and this delivery asks for no code change for
it. The band's own R4 removal holds: `CPTemplate.title` is gone, because the SDK 26.2's own
`CPTemplate.h` mentions the template's title in a `@note` and declares no such property.

## The numbers that were read, not chosen

- `MKMapCameraZoomDefault` is `-1.0`, read out of the MapKit image `dyld.extract` took of the
  arm64e dyld shared cache of 18.0: the eight bytes at the address the symbol
  `_MKMapCameraZoomDefault` has there. It is not a distance, it is the end of a zoom range that
  the range does not bound, which is why the one-sided initialisers leave the other end at it and
  the getter gives it back unchanged.
## The thirteen properties the release's map view has no answer for

Measured with `apple.objc.inventory` against the armv7 dyld shared cache of 6.1.3: the release's
`MKMapView` has 228 public instance methods, and its map surface is a region
(`-setRegion:animated:`, `-setCenterCoordinate:animated:`, `-visibleMapRect`, `-mapRectThatFits:`,
`-regionThatFits:`, `-convertCoordinate:toPointToView:`), a map type (`-mapType`), the user location
(`-userTrackingMode`, `-setUserTrackingMode:animated:`, `-showsUserLocation`) and the overlays. Its
own `-_rotationState`, `-canRotateForHeading` and `-setShouldRotateForHeading:` are the private
machinery that turns the map to follow the compass; that is not a public rotation and is not used.

So the map stays the release's and the newer API is put on top of it:

- **`rotateEnabled`, `pitchEnabled` and the camera's heading and pitch** are a transform on the
  release's own layer: a turn about the vertical for the heading, and for the pitch a projection of
  a plane at the eye distance a camera of that distance keeps, turned by the pitch. A real
  `UIRotationGestureRecognizer` on the map view drives the turn and is refused while `rotateEnabled`
  is NO. The annotation views are asked for through the release's own public `-viewForAnnotation:`
  and given the inverse of the turn, so a pin stands up on a rotated map. This is a projection of a
  plane, not the release's own three-dimensional camera, and the difference is the difference between
  rotating a picture of a map and having a camera above one.
- **`showsCompass`** puts this port's own `MKCompassButton` on the map view, drawn at the map's own
  turn, with `-compassVisibility` as the header documents it (adaptive hides it when the map is
  already facing north) and a tap that animates the map back to north through the release's own
  `-setRegion:animated:`.
- **`showsScale`** puts the `MKScaleView` on the map view; its bar is drawn from the release's own
  `visibleMapRect` and the release's own `MKMetersPerMapPointAtLatitude`.
- **`showsUserTrackingButton`** puts the `MKUserTrackingButton` on the map view, and that button
  drives the release's own `-setUserTrackingMode:animated:`, so following the user is the release's
  mechanism and not a copy of it.
- **`cameraBoundary`, `cameraZoomRange` and their two setters** narrow every region this port puts on
  the map: the boundary to the boundary's own region (through the release's own
  `MKCoordinateRegionForMapRect`), the zoom range to its distance in metres against the map view's
  own visible rect. A nil boundary is the whole world. What they do *not* do is constrain the
  release's own panning, which is the release's own gesture: the boundary is the camera's, and on
  this port the camera is what this port sets.
- **`preferredConfiguration`** is the release's own map type in the iOS 16 spelling: reading it back
  gives a standard, hybrid or imagery configuration standing for the map that is on screen, and
  setting one sets the map type the release's own map draws. The rest of a configuration -- the
  elevation style, the emphasis style, the point of interest filter, `showsTraffic` -- has no
  counterpart in a map type and is stored and given back.

And the four that cannot be done for any reason other than that the release's map draws one fixed
tile style, which is `inert` and not `implemented`:

| property | why, measured |
| --- | --- |
| `showsTraffic` | the release's map has no traffic layer to draw or not draw, and no `showsTraffic` in its 228 public methods |
| `showsBuildings` | the release's map draws its buildings inside its own vector tiles; there is no way to ask it for a style without them |
| `showsPointsOfInterest` | the same, for its points of interest |
| `pointOfInterestFilter` | the release's map takes no filter, so there is nothing for one to act on |

`selectableMapFeatures` and `pitchButtonVisibility` are `inert` for the same reason: the release's
map view has no selection of its own and no pitch button. All six store and read back, and say so
once in the log the first time they are used, which is what the registry README asks of an `inert`
entry.

## The services, and what the release already has

Measured, not assumed, and it changes the shape of the work:

- **`MKLocalSearch`, `MKLocalSearchRequest` and `MKLocalSearchResponse` are on the release** --
  `apple.dyld`'s `first_releases` puts all three at 6.1. So there is nothing to backport for
  `MKLocalSearch`: the release's own class answers, against Apple's own service, which is the best
  possible answer. Only `MKLocalSearchCompleter` (7.0) and `MKLocalSearchCompletion` (9.3) are
  missing, and the completer is a different problem again.
- **`CLGeocoder` is on the release** (5.0), with `-geocodeAddressString:completionHandler:`,
  `-geocodeAddressString:inRegion:completionHandler:`, `-geocodeAddressDictionary:completionHandler:`
  and `-reverseGeocodeLocation:completionHandler:` in the 6.1.3 cache, together with a `CLPlacemark`
  carrying the whole address vocabulary. So `MKGeocodingRequest` and `MKReverseGeocodingRequest` are
  built on the release's own geocoder, against Apple's own service, and are not an external service
  at all. The map items they answer with are the release's own `MKMapItem`, built through the
  release's own `-initWithPlacemark:` and `-setName:`.
- **`MKDirections` (7.0) and `MKDirectionsResponse` have no release counterpart at all**, so those
  are the ones that need an open provider, and the delivery has to name it.

## R4: the names no 16.4 header declares

R4 (`patch-merge` §4): a stack that adds or renames an **implemented** registry entry no SDK header
declares changes what the generator's rule (`tools/gen/target_availability.lua`) leaves alone. The port's
headers are rendered from the SDK the build uses -- 16.4, the only one this machine holds. Every one of the
rows below is a name no SDK header declares, so a swift-runtime build with backports gets no port header
for them: Swift code naming `MKGeocodingRequest` sees the 16.4 header, not this.

| set | rows | why they are real |
| --- | --- | --- |
| the 26.0 classes | `MKAddress`, `MKAddressRepresentations`, `MKGeocodingRequest`, `MKReverseGeocodingRequest` and their members | read out of the SDK 26.2's headers, which declare them; the 16.4 headers do not |
| `MKAddressFilter` and its six option bits | 7 rows | the same, and its object is of its own measured release (18.0) |
| the category strings | 34 `MKPointOfInterestCategory*` and `MKLaunchOptionsDirectionsModeCycling` | Apple's own values, measured out of macOS 27.0's MapKit.framework by `tests/backports/host/mapkit-constants`, which compares all 81 on every run |
| the 14.0 / 15.0 / 16.0 / 17.4 / 18.0 / 26.0 CarPlay members | the rest of the 26 | read out of the SDK 26.2's CarPlay headers, which declare them |

This is not a defect in this delivery, and this delivery asks for no code change for
it. The band's own R4 removal holds: `CPTemplate.title` is gone, because the SDK 26.2's own
`CPTemplate.h` mentions the template's title in a `@note` and declares no such property.

## The numbers that were read, not chosen

- `MKMapCameraZoomDefault` is `-1.0`, read out of the MapKit image `dyld.extract` took of the
  arm64e dyld shared cache of 18.0: the eight bytes at the address the symbol
  `_MKMapCameraZoomDefault` has there. It is not a distance, it is the end of a zoom range that
  the range does not bound, which is why the one-sided initialisers leave the other end at it and
  the getter gives it back unchanged.

## The checks

- `tests/backports/host/mapkit` compares **the projection, the metres per map point, the bearing, the
  zoom-scale and map-size round trip, and the distance formatter's measure** against macOS's own
  MapKit. 88 checks, 0 failures. **What it does not decide, and why:** the camera (below), and the
  formatter's *strings* -- the host localises its unit words out of a table this port does not carry
  and rounds its numbers by rules it does not document, so deriving those from a host would be
  inventing values. The emulator call test covers the strings.

- **The camera is an open defect this differential found, not a green check.** Measured against the
  host's own `+[MKMapCamera cameraLookingAtCenterCoordinate:fromEyeCoordinate:eyeAltitude:]` with
  the same centre, eye and altitude: the host answers **83.6 degrees of pitch** and a distance
  **345314.847 m**, and this port answers **0.2 degrees** and **343173.11 m**. So Apple's
  `eyeCoordinate` and `eyeAltitude` are not read the way this port reads them, and the port's
  `MKMapCamera` is not faithful on this member. It is left out of the differential rather than
  asserted against a host it disagrees with, and it is the first thing the next round fixes.
- The generated call test calls every implemented method on the emulator at 6.1.3, which is the
  only check that touches the parts a host cannot answer for: the drawing (the renderers are asked
  to draw into a bitmap context) and the delegate bridge.

## The services, written

Three of the four are over something the release already has; one is the only place in this library
that reaches outside Apple.

**`MKLocalSearchCompleter` (7.0) and `MKLocalSearchCompletion` (9.3), over the release's own
`MKLocalSearch`.** Measured: `MKLocalSearch`, `MKLocalSearchRequest` and `MKLocalSearchResponse` are
first exported at 6.1, and the release's own request carries `-naturalLanguageQuery` and `-region`
while its own `MKLocalSearch` carries `-initWithRequest:`, `-startWithCompletionHandler:`, `-cancel`
and `-isSearching`. So every search behind a completion here is **Apple's own search, running on the
release**. What the release has no answer for, and what this file is, is the debounce (0.35 s),
the cancellation, the result list, the `MKMapItem` to completion mapping with the header's own
`NSValue`-wrapped highlight ranges, and the SDK's own `-completerDidUpdateResults:`.

**`MKGeocodingRequest`, `MKReverseGeocodingRequest`, `MKAddress` and `MKAddressRepresentations`
(26.0), over the release's own `CLGeocoder`.** Measured: `CLGeocoder` is first exported at 5.0 and
the 6.1.3 cache holds `-geocodeAddressString:completionHandler:`,
`-geocodeAddressString:inRegion:completionHandler:`, `-geocodeAddressDictionary:completionHandler:`,
`-reverseGeocodeLocation:completionHandler:` and `-cancelGeocode`, together with a `CLPlacemark`
carrying the whole address vocabulary. So the geocoding is **Apple's own geocoder on the release**,
and no external service is involved.

The one thing this measurement corrected, and it corrects an earlier claim in this file: the
release's `MKMapItem` **does** carry a placemark. `apple.objc.inventory` on the 6.1.3 cache shows
`-initWithPlacemark:`, `-placemark`, `-setPlacemark:`, `-setName:`, `+mapItemWithDictionary:` and
`-placeID`, and it has **never** had `-address` or `+mapItemWithName:address:` (both measured absent
by selector string). So the geocoding wrappers build the release's own `MKMapItem` around the
release's own `MKPlacemark`, made from the geocoder's coordinate and address dictionary, and
`+[MKMapCamera cameraLookingAtMapItem:forViewSize:allowPitch:]` frames that placemark's coordinate.

**`MKLookAround*` (16.0): the wall, and Apple's own answer for it.** Look Around is Apple's own
street-level imagery, served by Apple's own service. There is no public web API for it, no open
equivalent, and nothing on this device that holds a panorama. So the six classes exist, every one of
them answers the way Apple answers where it has no coverage -- a `nil` with `MKErrorDomain` code 1
and the reason in the description -- and the two things a caller can check really are checked:
`+[MKLookAroundSceneRequest isAvailable]` says NO, and the view controller is a real view controller
whose delegate gets the header's own update and dismissal messages. Nothing is fabricated and no
panorama is invented.

**`MKDirections`, `MKDirectionsRequest`, `MKDirectionsResponse`, `MKRoute`, `MKRouteStep` and
`MKETAResponse` (7.0), over OSRM.** This is **the one family in this library that reaches outside
Apple**, and the provider is named here and in the source:

> routing provider **OSRM**, the Open Source Routing Machine, at
> `https://router.project-osrm.org` (`/route/v1/{driving,foot,bike}/...`, `overview=full`,
> `geometries=polyline`, `steps=true`, `alternatives=true`), BSD-2-Clause.
> The base URL is read from the `MKREVENANT_OSRM_BASE` environment variable when a program sets one,
> and defaults to the address above.

The transport is the device's own: an `NSURLConnection` over HTTPS, which on iOS 6 is the release's
own CFNetwork and the release's own TLS. The engine's polyline6 encoding is decoded with the
release's own base64 into the release's own `MKPolyline`, so the route is drawn by the release's own
renderer out of the release's own geometry; the distance and the duration are the engine's own, and
the ETA is the request's departure date plus the engine's duration. `MKDirectionsTransportTypeTransit`
has no OSRM profile and is answered with the walking one, which the registry says it is.

## Why the GeoJSON decoder has no host differential, and that is structural

Measured, and it is the same collision the `CPListItem` name is: the port's decoder carries **Apple's
own class name**, because that is what a program links. On a host where Apple's own decoder exists,
the runtime resolves the name to Apple's image and the port's class is unreachable:

```
objc[50969]: Class MKGeoJSONDecoder is implemented in both
  /System/Library/Frameworks/MapKit.framework/Versions/A/MapKit
  /…/libGeoJSONBackport.dylib. This may cause spurious casting failures and mysterious crashes.
  One of the duplicates must be removed or renamed.
```

Renaming the port's class into a static link, which is what the first version of the probe did, is not
a way round it either: that produced a class the loader did not finish registering -- `class_getImageName`
found it, `respondsToSelector:` said no, and `class_copyMethodList` on it raised SIGBUS -- which is a
malformed method list, i.e. a registration failure, not a missing method.

So the host **cannot be the oracle for this family**, and the honest consequence is that the check
for these six rows is the **emulator call test on 6.1.3**, where there is no Apple decoder to collide
with -- which is the whole reason the port carries the class. The host is still useful for one thing
and the probe keeps it: the port's own answer, checked against **RFC 7946 itself** (the shapes, the
counts, the coordinates, and the five mutations that must be refused), which is a check the decoder can
pass or fail without Apple's decoder in the picture.

## The map item family, and what each piece stands on

Forty-nine rows, and no wall in any of them: the release has `MKLocalSearch` (first exported 6.1) and
`MKMapItem` with `-placeID`, `-placemark`, `-dictionaryRepresentation`, `-phoneNumber`, `-rating`,
`-attributions` and `-openInMapsWithLaunchOptions:` (all measured with `apple.objc.inventory` on the
armv7 cache of 6.1.3), and a place is something this release genuinely holds. The family, and what
each part is:

| piece | rows | object | what it is |
| --- | --- | --- | --- |
| `MKMapItemRequest` | 6 | 16.0 | made **for a map feature**, and a map feature is a thing the map itself knows about, which arrives with a map that has features. This release's map has none and `MKMapFeatureAnnotation` is registered `absent` for that reason — so `-cancel`/`-cancelled`/`-loading` are real, the feature is `nil`, and `-getMapItemWithCompletionHandler:` answers with the header's own error in `MKErrorDomain` rather than a made-up place |
| `MKMapItemIdentifier` | 2 | 18.0 | the release's own `-placeID`, kept byte for byte, and `nil` where the place has none |
| `MKMapItem`'s later members | 7 | category on the release's class | `timeZone` and `pointOfInterestCategory` and `location` and `address` and `addressRepresentations` out of the release's own placemark vocabulary and its own `-dictionaryRepresentation`; `identifier` reads the release's own `-placeID`; `alternateIdentifiers` is **one** identifier, because there is no second place to name here |
| `MKMapItemAnnotation` | 2 | 18.0 | the release's own `MKAnnotation` shape with the item behind it, the coordinate and title from the item's own placemark, and the **invalid** coordinate where there is none |
| the detail screen's three classes | 17 | 18.0 | `MKMapItemDetailViewController` as a real view controller over the release's own views, `MKSelectionAccessory` as the accessory that opens it in a style, and the style as Apple's own class with 5 class methods (the four factories and the two class properties) and 7 instance methods of its own |

**Every shape was measured on the host before the code was written**, and three would have been wrong
otherwise: `initWithMapItem:displaysMap:` is `@28@0:8@16B24` — the second argument is a **BOOL**;
`calloutWithCalloutStyle:` is `@24@0:8q16` — the callout style is an **eight-byte enum**; and
`+callout`/`+openInMaps` are **class** methods, so the corpus's `property` spelling is a class
property and the build's own `spellings()` reads it as `+[Class property]`. On the host the style has
**7 instance methods of its own and 5 class methods** — the four factories and those two class
properties — and an earlier draft of this file said it had "no instance methods", which was wrong.

**What is measured and what is inferred on cancellation, because the two are not the same here**: the
`MKErrorDomain` code 1 for a cancellation is **measured on `MKLocalSearch`**, the host class that has a
`-cancel` and a completion. It is **inferred** for `MKMapItemRequest` and the two geocoding requests,
which have no host analogue a probe can drive — `MKMapItemRequest`'s designated initialiser takes a map
feature, and a host program cannot make one. The inference is MapKit's own convention applied
consistently across the requests, and it is recorded here so nobody reads it as a measurement of
these three.

**One difference between the two releases, recorded rather than smoothed over**: the host's own
`MKMapItem` no longer has `-placeID` and has `-identifier` instead, while this release has `-placeID`.
The port reads **the release's** name, and each member's registry entry says so.

## The request family, and the one wall in it

Eighteen rows, and the shape of all but eight of them is a **category on a class the release already
carries**. Measured with `apple.objc.inventory` on the armv7 cache of 6.1.3: the release's own
`MKLocalSearchRequest` carries `-naturalLanguageQuery`, `-region` and their setters; its own
`MKLocalSearch` carries `-initWithRequest:`, `-startWithCompletionHandler:`, `-cancel` and
`-isSearching`; and its own `MKDirectionsRequest` carries `-source`, `-destination`,
`-transportType`, `-requestsAlternateRoutes`, `-departureDate` and `-arrivalDate`. So iOS 7's
`MKLocalSearchRequest` and iOS 9.3's `MKLocalSearchCompleter` are **not** new classes here — they are
the release's, plus the members later releases added, and the gate's `added_members()` skips a class
with an `image` (which is every class the release has), so the registry names each member because a
caller's member *is* reached through the category. That is the same rule the `CPListItem` rows needed.

What is implemented: the two initialisers over the release's own request and its own `-setRegion:`;
`-resultTypes` and `-pointOfInterestFilter` as the release's own, which the 16.4 header declares and
the release carries; `-addressFilter` and `-regionPriority` (iOS 18) held **beside** the request
through the runtime, because a category cannot have an ivar — and `regionPriority` answers **0**,
the header's own default, where nobody set one, rather than a number of this port's;
`-initWithPointsOfInterestRequest:` over the release's own search; and the completer's two delegate
messages, which the port's own `MKLocalSearchCompleter` already sends.

**The eight rows that are `inert`, and the false claim they used to stand on.**
`MKLocalPointsOfInterestRequest` and its seven members were `absent` with the reason "a MAP'S OWN
points of interest — the restaurants and stations a map knows about — arrive with a map that has them.
This release's map has none." **That reason was false, and it is measured false below.** The class is
the release's own nowhere, which is true and is not why it was absent:

```
$ REVENANT_ROOT=<worktree> xmake l tools/corpus/cache-census.lua MKLocalPointsOfInterest 6.1.3 4.3 16.0
6.1.3     $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
          images 524, of which naming MKLocalPointsOfInterest 0
          classes 11378, of which MKLocalPointsOfInterest* 0
          protocols 1171, of which MKLocalPointsOfInterest* 0
4.3       $HOME/.revenant/dyld/4.3/dyld_shared_cache_armv7
          images 354, of which naming MKLocalPointsOfInterest 0
          classes 7187, of which MKLocalPointsOfInterest* 0
          protocols 564, of which MKLocalPointsOfInterest* 0
16.0      $HOME/.revenant/dyld/16.0/dyld_shared_cache_arm64e
          images 2664, of which naming MKLocalPointsOfInterest 0
          classes 143137, of which MKLocalPointsOfInterest* 1 (MKLocalPointsOfInterestRequest)
          protocols 25549, of which MKLocalPointsOfInterest* 0
control: 1 name(s) beginning MKLocalPointsOfInterest found in this run, so a zero on another rung is
the release's and not the reader's
```

and neither release has the class's entry points either — `grep -cxF` on each release's own selector
table (`~/.revenant/dyld/6.1.3/selectors_armv7.txt`, `~/.revenant/dyld/4.3/selectors_armv7.txt`) answers
**0 and 0** for `initWithCenterCoordinate:radius:`, for `initWithCoordinateRegion:` and for
`pointOfInterestCategory`. `xmake l tools/cache-index/first-rung.lua MKLocalPointsOfInterestRequest`
answers `16.0`, which is the ladder's hole (no 13.0, 14.0 or 15.0 is held) and not a measured first
release; `tools/release-split.lua` says so in its own note.

**What the release DOES have is the search the request is for.** `apple.objc.inventory` on the armv7
cache of 6.1.3: the release's own `MKLocalSearchRequest` carries `-naturalLanguageQuery`, `-region` and
their setters, its own `MKLocalSearch` carries `-initWithRequest:` and `-startWithCompletionHandler:`,
its own `MKLocalSearchResponse` carries `-mapItems`, and its own `MKMapItem` carries `-name`,
`-placemark`, `-isBusiness`, `-rating`, `-numberOfRatings`, `-numberOfReviews` and `-attributions`.
Those last four are the fields of a **business**, which is what a point of interest is on a release
whose map knows places: this release's own search answers a question about points of interest. What
it has no member for is the request that *describes* one. So the request is carried here —
`MKLocalPointsOfInterestRequest14.m`, whose object is release 14's alone — and the search stays the
release's.

**The arithmetic, differentially checked against the host's own class of the same name.**
`tests/backports/host/mapkit-poi-request` builds the port's object as a Catalyst dylib with its class
renamed, builds the runner, and compares the four members' values on both over six cases (the equator,
London twice with a region taller than it is wide and one wider than it is tall, Sydney, Cupertino,
Reykjavik):

```
$ sh tests/backports/host/mapkit-poi-request/run.sh
mapkit-poi-request: 18 comparisons agree with the host's own class, radius apart by at most 0.671%
mapkit-poi-request: the mutant goes red, so the comparison above can see a wrong number
```

The circle-to-region direction agrees with the host's own **to the last printed digit in every case**
(0.000% apart), and the port's round trip is exact — 500.000 m in, 500.000 m back. The radius read off
a *region* is the one number that is not identical, and the difference is not a bug: the host's own
radius comes from an earth model of Apple's own, and **the host's own two directions do not agree with
each other either** — a circle of 500 m at the equator reads back as 503.378 m on the host, one of
1999 m at Reykjavik as 1990.462 m — while the port answers the release's own projection. The probe's
mutant (the diagonal reading, which the port's first version used) is 41% out and goes red, so the
comparison can see a wrong number. Two details of the projection that the probe found the hard way are
written into the object: MapKit's **y grows southwards** (so the half-height is the southern edge less
the northern one; the other order gives a negative height and a radius of 0 for every region), and the
reading is the **larger half-span**, not the diagonal, because that is what makes the round trip exact.

**Why the rows are `inert` and not `implemented`:** nothing applies the request yet. The one caller a
program has is `-[MKLocalSearch initWithPointsOfInterestRequest:]`, a 14.0 row that is not this
object's, and its implementation in `MKLocalSearchRequest13.m` makes the release's own search with an
**empty** request and drops the argument. So the symbols load and answer exactly what the caller gave
them — `-initWithCenterCoordinate:radius:` and `-initWithCoordinateRegion:` read each other through
the **release's own projection** (`MKMapPointForCoordinate`, `MKMapPointsPerMeterAtLatitude` and
`MKCoordinateRegionForMapRect`, all `3.2` on the ladder, with the region-to-map-rect direction being
`+[RevenantMapKit revenant_mapRectForRegion:]`, the declared inverse of the release's own function) — and
the release's own search is still asked with no query. The three initialisers and the filter setter say
so once in the log, which is what `registry/README.md` asks of an inert entry.
