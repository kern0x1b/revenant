// MKLocalPointsOfInterestRequest, iOS 14's own object and the object of that release alone: a search
// of the MAP'S OWN points of interest over a circle or a region, narrowed to the categories a filter
// names. Its two initialisers, its three read-only members and its filter are all here, and nothing
// else of release 14 is in this file.
//
// MEASURED FIRST, and it decides what this file can be. The class is not the release's:
//
//     CHARON_ROOT=<worktree> xmake l tools/corpus/cache-census.lua MKLocalPointsOfInterest 6.1.3 4.3 16.0
//     6.1.3  images 524,  classes 11378,  of which MKLocalPointsOfInterest* 0
//     4.3    images 354,  classes 7187,   of which MKLocalPointsOfInterest* 0
//     16.0   images 2664, classes 143137, of which MKLocalPointsOfInterest* 1 (MKLocalPointsOfInterestRequest)
//     control: 1 name(s) beginning MKLocalPointsOfInterest found in this run, so a zero on another
//     rung is the release's and not the reader's
//
// and neither release has the class's own entry points either: grep -cxF on each release's selector
// table (~/.charon/dyld/6.1.3/selectors_armv7.txt and .../4.3/selectors_armv7.txt) answers 0 for
// initWithCenterCoordinate:radius:, 0 for initWithCoordinateRegion: and 0 for pointOfInterestCategory.
// So this is the port's own class, defined under Apple's own name, and the 16.0 rung is the control
// that says the reader finds the name when the release has it.
//
// WHAT THE RELEASE DOES HAVE, measured on the armv7 cache of 6.1.3 with apple.objc.inventory, and
// this is the correction of what this library used to claim here. The rows of this class used to say
// "a MAP'S OWN points of interest ... arrive with a map that has them. This release's map has none",
// and that is false. The release's own MKLocalSearchRequest carries -naturalLanguageQuery and
// -region with their setters, its own MKLocalSearch carries -initWithRequest: and
// -startWithCompletionHandler:, its own MKLocalSearchResponse carries -mapItems, and its own
// MKMapItem carries -name, -placemark, -isBusiness, -rating, -numberOfRatings, -numberOfReviews and
// -attributions. Those last four are the fields of a BUSINESS, which is what a point of interest is
// on a release whose map knows places: this release's own search answers a question about points of
// interest. What the release has no member for is the request that describes one, so the request is
// carried here and the search stays the release's.
//
// THE HONEST LIMIT, and it is why every row of this class is `inert` and not `implemented`: nothing
// in this library applies the request yet. The one caller a program has is
// -[MKLocalSearch initWithPointsOfInterestRequest:], whose row is not this object's and whose
// implementation makes the release's own search with an EMPTY request and drops its argument
// (MKLocalSearchRequest13.m, and the registry row for it says so in its own words). So the symbols
// here load and answer exactly what the caller gave them, and the release's own search is still
// asked with no query. That is what `inert` means, and it is the whole of the effect until the
// search reads a request. Where a caller hands the request something -- the three initialisers and
// the filter -- the object says so ONCE in the log, which is what the registry README asks of an
// inert entry, so a program that reaches it leaves a line instead of quietly getting a search with
// no query. The four members that only read back what was set do not say anything: they answer the
// caller exactly.
//
// AND WHAT IT DOES NOT DO: the header also declares MKPointsOfInterestRequestMaxRadius, which Apple's
// own framework holds as 2000 metres and which this library already carries (MKPointOfInterestCategories16.m,
// measured out of the host's own MapKit). A request is NOT clamped to it here. What a release's own
// search does with a radius above its own maximum is that release's answer and not this port's to
// invent, so the object records the radius the caller gave and the search -- the release's own -- is
// the one that decides.
//
// WHAT IS REAL INSTEAD OF HELD FOR ITS OWN SAKE: the circle and the region answer each other through
// the RELEASE'S OWN PROJECTION, not through a constant of this port's -- MKMapPointForCoordinate,
// MKMapPointsPerMeterAtLatitude and MKCoordinateRegionForMapRect are all in the armv7 cache of 3.2
// and later. A request made of a circle answers a region that encloses it, and a request made of a
// region answers the circle that covers it, so the two initialisers agree on the same place -- and
// they agree with the HOST'S OWN class of this name to the last printed digit, which is what
// tests/backports/host/mapkit-poi-request measures and what its mutant shows can see a wrong value.
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import "CharonMapKit.h"

// The region that encloses a circle of the given radius, in the release's own projection: the circle
// is measured in metres at the circle's own latitude, which is what MKMapPointsPerMeterAtLatitude is
// for, and the enclosing rectangle is turned back into a region by the release's own
// MKCoordinateRegionForMapRect.
static MKCoordinateRegion CharonRegionAroundCoordinate(CLLocationCoordinate2D coordinate, CLLocationDistance radius)
{
    MKMapPoint centre = MKMapPointForCoordinate(coordinate);
    double reach = MKMapPointsPerMeterAtLatitude(coordinate.latitude) * (double)radius;
    MKMapRect area = MKMapRectMake(centre.x - reach, centre.y - reach, reach * 2.0, reach * 2.0);
    return MKCoordinateRegionForMapRect(area);
}

// The circle that COVERS a region: the larger of the region's two half-spans, in the release's own
// projection. Two details of that projection are what make it right, and both were measured against
// the host's own class of the same name (tests/backports/host/mapkit-poi-request, whose transcripts
// are compared value for value):
//
//   - MapKit's y grows SOUTHWARDS, so the half-height is the southern edge's y LESS the northern
//     edge's y. Taking that difference the other way round gives a negative height, and a radius read
//     off it is 0 -- which is what an earlier version of this file answered for every region.
//   - the reading is the LARGER half-span and not the diagonal, because a circle and a region are two
//     spellings of one place and the round trip has to be exact: a request made of a circle of 500 m
//     answers a region whose half-spans are both 500 m, and that region answers 500 m back, which is
//     what this file measures. For a region of uneven sides the larger half-span is also what the
//     HOST'S OWN class answers (measured in the same probe: a region taller than it is wide reads
//     69,394 m there and 69,538 m here, and a region wider than it is tall reads 43,192 m and
//     43,278 m) -- and the host's own round trip does NOT close, because its radius comes from an
//     earth model of Apple's own rather than from MapKit's projection: 500.000 m at the equator reads
//     back as 503.378 m there. So the two differ by at most 0.671% on that one member and not at all
//     on the coordinate or the region, and the probe's mutant (the diagonal) is 41% out.
static CLLocationDistance CharonRadiusAroundRegion(MKCoordinateRegion region)
{
    double perMetre = MKMapPointsPerMeterAtLatitude(region.center.latitude);
    if (!(perMetre > 0.0) || !(region.span.latitudeDelta >= 0.0) || !(region.span.longitudeDelta >= 0.0)) {
        // A span that is not a span, which MKCoordinateRegionMake cannot produce and a caller can:
        // there is no circle to read out of it, and 0 is the answer that says so.
        return 0.0;
    }
    double halfWidth = (double)MKMapSizeWorld.width * region.span.longitudeDelta / 360.0 / 2.0 / perMetre;
    CLLocationCoordinate2D north = region.center;
    north.latitude += region.span.latitudeDelta / 2.0;
    CLLocationCoordinate2D south = region.center;
    south.latitude -= region.span.latitudeDelta / 2.0;
    double halfHeight = fabs(MKMapPointForCoordinate(south).y - MKMapPointForCoordinate(north).y) / 2.0 / perMetre;
    return halfWidth > halfHeight ? halfWidth : halfHeight;
}

@implementation MKLocalPointsOfInterestRequest {
    CLLocationCoordinate2D _coordinate;
    CLLocationDistance _radius;
    MKCoordinateRegion _region;
    MKPointOfInterestFilter *_pointOfInterestFilter;
}

// Apple's own header marks -init unavailable, because a request has to say which place it is about.
// It is answered anyway, the way this library answers every unavailable initialiser it carries (see
// MKIconStyle's -init in MKPointOfInterestFilter.m): a caller that reaches it through the runtime
// gets a request and not a crash. A request nobody placed is the whole world, which is the same
// region MKLocalSearchRequest13.m's query-only initialiser uses for a request with no query.
- (instancetype)init
{
    // Through the header's own designated initialiser, which is where a convenience initialiser of a
    // class with designated initialisers has to go: the whole world, which is the region of a request
    // nobody placed.
    charon_sayOnce(@"[MKLocalPointsOfInterestRequest init]",
                   @"it answers the whole world, and the release's own search is asked with no query: "
                   @"MKLocalSearchRequest13.m's -initWithPointsOfInterestRequest: drops its argument");
    return [self initWithCoordinateRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(0.0, 0.0),
                                                                 MKCoordinateSpanMake(180.0, 360.0))];
}

// The header's designated initialiser, and the request's own circle: the centre and the radius are
// what the caller gave, and the region is the one the release's own projection says encloses them.
- (instancetype)initWithCenterCoordinate:(CLLocationCoordinate2D)coordinate radius:(CLLocationDistance)radius
{
    charon_sayOnce(@"[MKLocalPointsOfInterestRequest initWithCenterCoordinate:radius:]",
                   @"the circle is recorded and answered back, and the release's own search is asked "
                   @"with no query: MKLocalSearchRequest13.m's -initWithPointsOfInterestRequest: drops "
                   @"its argument");
    self = [super init];
    if (self) {
        _coordinate = coordinate;
        _radius = radius < 0.0 ? 0.0 : radius;
        _region = CharonRegionAroundCoordinate(coordinate, _radius);
    }
    return self;
}

// The header's other designated initialiser, and the same request read the other way round: the
// region is what the caller gave, and the centre and the radius are read back out of it, so a
// request made of a region answers the circle that covers it.
- (instancetype)initWithCoordinateRegion:(MKCoordinateRegion)region
{
    charon_sayOnce(@"[MKLocalPointsOfInterestRequest initWithCoordinateRegion:]",
                   @"the region is recorded and answered back, and the release's own search is asked "
                   @"with no query: MKLocalSearchRequest13.m's -initWithPointsOfInterestRequest: drops "
                   @"its argument");
    self = [super init];
    if (self) {
        _region = region;
        _coordinate = region.center;
        _radius = CharonRadiusAroundRegion(region);
    }
    return self;
}

- (CLLocationCoordinate2D)coordinate
{
    return _coordinate;
}

- (CLLocationDistance)radius
{
    return _radius;
}

- (MKCoordinateRegion)region
{
    return _region;
}

// The filter is the port's own MKPointOfInterestFilter, whose including and excluding sets are
// Apple's own MKPointOfInterestCategory strings, and it is held beside the request the way the
// release's own request has no room for one. It is held, not applied: the release's own search
// cannot be asked for a category (its request carries no filter member and its map item carries no
// category, both measured on the armv7 cache of 6.1.3), and nothing in this library reads the filter
// off this request yet -- see the HONEST LIMIT above.
- (nullable MKPointOfInterestFilter *)pointOfInterestFilter
{
    return _pointOfInterestFilter;
}

- (void)setPointOfInterestFilter:(nullable MKPointOfInterestFilter *)pointOfInterestFilter
{
    charon_sayOnce(@"MKLocalPointsOfInterestRequest.pointOfInterestFilter",
                   @"the filter is kept and answered back and nothing asks the release's own search "
                   @"with it: the release's own request has no filter member and its own map item has "
                   @"no category, both measured on the armv7 cache of 6.1.3");
    _pointOfInterestFilter = [pointOfInterestFilter copy];
}

// NSCopying, which the header's own declaration gives the class: a copy is the same circle, the same
// region and the same filter, which is what a caller archiving or handing the request on expects.
- (id)copyWithZone:(nullable NSZone *)zone
{
    MKLocalPointsOfInterestRequest *copied = [[[self class] allocWithZone:zone] initWithCenterCoordinate:_coordinate
                                                                                              radius:_radius];
    copied->_region = _region;
    copied->_pointOfInterestFilter = [_pointOfInterestFilter copy];
    return copied;
}

@end
