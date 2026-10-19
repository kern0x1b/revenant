// The request objects the search and the routing are asked with, as categories on the release's own
// classes and as the one new class the map's own points of interest need.
//
// The release HAS MKLocalSearchRequest, MKDirectionsRequest, MKLocalSearch and
// MKLocalSearchCompleter (apple.objc.inventory on the armv7 cache of 6.1.3: the request carries
// -naturalLanguageQuery and -region and their setters, the search carries -initWithRequest:,
// -startWithCompletionHandler:, -cancel and -isSearching), so what iOS 7 and later added to them is a
// CATEGORY on a class the release carries, and the gate's own check names each member because a
// caller's member is reached through the category -- the same rule the CPListItem rows needed.
//
// What is implemented and what is the wall, and the wall is one class:
//
//   -naturalLanguageQuery:region:, -initWithNaturalLanguageQuery:region:, -initWithCompletion:,
//   -resultTypes, -pointOfInterestFilter, -addressFilter, -regionPriority
//       the release's own search, and its own two properties, doing the work: the query and the
//       region are the release's, the result types and the filters narrow what the release's search
//       is asked for, and the completion and the initialisers are the header's own shapes.
//
//   -transportType, -requestsAlternateRoutes, -departureDate, -arrivalDate, -tollPreference,
//   -highwayPreference
//       the release's own MKDirections request, extended with the members the routing this port
//       already does reads: MKDirections7.m asks for the transport type and the departure date, and
//       an alternate-routes request is what its own `alternatives=true` is.
//
//   -initWithPointsOfInterestRequest:                the release's own search, over the wall below.
//
//   -completerDidUpdateResults: and -completer:didFailWithError:
//       the completer delegate, which the port's own MKLocalSearchCompleter already sends both of
//       (MKLocalSearchCompleter.m calls the update message and the failure one through the runtime).
//
//   MKLocalPointsOfInterestRequest, and its four members
//       **absent**, and that is the one wall in this file: the points of interest are a MAP'S OWN --
//       the restaurants and stations a map knows about, which arrive with a map that has them. This
//       release's map has none, so there is no centre and radius to search around, and the class is
//       registered absent with that reason rather than built as a request for nothing.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "CharonMapKit.h"

NS_ASSUME_NONNULL_BEGIN

// The two members the release's own request does not have, and the 16.4 header does not declare:
// -addressFilter and -regionPriority, both iOS 18. A category cannot add an ivar, so the two are held
// beside the request through the runtime, and the accessors are this port's own -- so the gate reads
// them as members a caller's member is reached through, which is the rule the CPListItem rows needed.
@interface MKLocalSearchRequest (CharonOptions)
@property (nonatomic, copy, nullable) MKAddressFilter *addressFilter;
@property (nonatomic, assign) NSInteger regionPriority;
@end

// -resultTypes and -pointOfInterestFilter, both iOS 13.0, and the release's own request has NEITHER:
// its whole surface in the armv7 cache of 6.1.3 is -naturalLanguageQuery, -region, their setters and
// the two initialisers, so the earlier claim that "the release carries -resultTypes" was false --
// this file's own comment named both while its category implemented neither, which is exactly what
// the 6.1.3 gate reports: "listed as implemented, but nothing of that name is built".
//
// A category cannot add an ivar, so both are held beside the request through the runtime, the same
// mechanism -addressFilter and -regionPriority use. The effect is real rather than a value held for
// the getter's sake: a search of the request is ASKED for what the two say.
@interface MKLocalSearchRequest (CharonResultTypes)
@property (nonatomic, assign) MKLocalSearchResultType resultTypes;
@property (nonatomic, copy, nullable) MKPointOfInterestFilter *pointOfInterestFilter;
@end

// The host guard the rest of this port's own declarations use, for the two 18.0 filters the host's
// MapKit also declares.
#if !CHARON_HOST_PROBE
@interface MKLocalSearchRequest (CharonRequest)
- (instancetype)initWithNaturalLanguageQuery:(NSString *)query
                                      region:(MKCoordinateRegion)region;
- (instancetype)initWithCompletion:(void (^)(MKLocalSearchResponse *response, NSError *error))completionHandler;
@end

@interface MKLocalSearch (CharonRequest)
- (instancetype)initWithPointsOfInterestRequest:(id)request;
@end
#endif

@implementation MKLocalSearchRequest (CharonRequest)

// The release's own -init and its own -setNaturalLanguageQuery:, and nothing of this category's. The
// release has NO -initWithNaturalLanguageQuery: of either shape (a search of the armv7 cache of 6.1.3
// for the selector string finds 0, and finds -setNaturalLanguageQuery: twice), so both initialisers
// are this category's own. An earlier version had each call the other, and every request initialiser
// recursed:
//
//     frame #0: libport.dylib`-[MKLocalSearchRequest(CharonRequest) initWithNaturalLanguageQuery:] + 44
//
// The version after it called -initWithNaturalLanguageQuery: through the runtime as "the release's
// own", which on the release is a selector nothing answers, and it dropped the query-only initialiser
// the registry lists (the stack 14 gate at 6.1.3: "listed as implemented, but nothing of that name is
// built"). Both now end here, where no initialiser of this category is called.
static id CharonRequestInit(MKLocalSearchRequest *request, NSString *query)
{
    request = [request init];
    [request setNaturalLanguageQuery:query];
    return request;
}

- (instancetype)initWithNaturalLanguageQuery:(NSString *)query
{
    // The header's query-only initialiser: the release's query with the whole world as the region, as
    // its registry row says, so the release's search is asked with no narrower a place than any.
    self = CharonRequestInit(self, query);
    if (self) {
        [self setRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(0.0, 0.0), MKCoordinateSpanMake(180.0, 360.0))];
    }
    return self;
}

- (instancetype)initWithNaturalLanguageQuery:(NSString *)query region:(MKCoordinateRegion)region
{
    // The release's own -init and query, as above, and its own -setRegion:, which is all this
    // initialiser adds, and the release's own storage for both.
    self = CharonRequestInit(self, query);
    if (self) {
        [self setRegion:region];
    }
    return self;
}

- (instancetype)initWithCompletion:(MKLocalSearchCompletion *)completion
{
    // The header's own shape, which is NOT a block: a request made over a completion that is
    // ALREADY FINISHED, so the release's own search is not asked for anything at all. The release
    // has no such request, so the release's own empty query is the base and the completion is held,
    // and the port's own MKLocalSearchCompleter reads it back through -[MKLocalSearchCompletion
    // title] when the caller asks the completer for its results.
    self = CharonRequestInit(self, @"");
    if (self) {
        objc_setAssociatedObject(self, (const void *)"charonFinishedCompletion", completion,
                                 OBJC_ASSOCIATION_RETAIN);
    }
    return self;
}

// The finished completion this request was made over, which is what a search of it answers with
// without the release's own search being asked. Charon's own, so it carries no API.
- (nullable MKLocalSearchCompletion *)charon_finishedCompletion
{
    return objc_getAssociatedObject(self, (const void *)"charonFinishedCompletion");
}

#if !CHARON_HOST_PROBE
// The iOS 18 address filter and region priority, which the release's own request has no room for.
- (void)setAddressFilter:(nullable MKAddressFilter *)filter
{
    objc_setAssociatedObject(self, (const void *)"charonAddressFilter", filter,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (nullable MKAddressFilter *)addressFilter
{
    return objc_getAssociatedObject(self, (const void *)"charonAddressFilter");
}

- (void)setRegionPriority:(NSInteger)regionPriority
{
    objc_setAssociatedObject(self, (const void *)"charonRegionPriority",
                             [NSNumber numberWithInteger:regionPriority], OBJC_ASSOCIATION_RETAIN);
}

- (NSInteger)regionPriority
{
    // Zero is MKLocalSearchRegionPriorityDefault, which is the header's own default, so a request
    // nobody has set a priority on answers the default rather than a number of this port's.
    id value = objc_getAssociatedObject(self, (const void *)"charonRegionPriority");
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

#endif
// -resultTypes, iOS 13.0, and what it means is NARROWING WHAT THE SEARCH IS ASKED FOR: the header's
// own enumeration is MKLocalSearchResultTypeAddress = 1 << 0 and MKLocalSearchResultTypePointOfInterest
// = 1 << 1, so a caller that asks for addresses gets an address search and one that asks for points
// of interest gets a points search. The release's own request cannot express that, so this narrows
// the QUERY the release is asked and the answer the caller receives -- see -charon_applyResultTypesTo:.
//
// The default is the header's own default: both types, 1 << 0 | 1 << 1 = 3. A request nobody has set
// a result type on is asked for everything, which is what the release's own search does anyway.
- (void)setResultTypes:(MKLocalSearchResultType)resultTypes
{
    objc_setAssociatedObject(self, (const void *)"charonResultTypes",
                             [NSNumber numberWithUnsignedInteger:resultTypes], OBJC_ASSOCIATION_RETAIN);
}

- (MKLocalSearchResultType)resultTypes
{
    id value = objc_getAssociatedObject(self, (const void *)"charonResultTypes");
    return [value isKindOfClass:[NSNumber class]]
        ? (MKLocalSearchResultType)[value unsignedIntegerValue]
        : (MKLocalSearchResultType)(MKLocalSearchResultTypeAddress | MKLocalSearchResultTypePointOfInterest);
}

// -pointOfInterestFilter, iOS 13.0. The filter is this port's own MKPointOfInterestFilter, whose own
// including and excluding sets are Apple's own MKPointOfInterestCategory strings, and what it does
// here is FILTER THE RELEASE'S OWN ANSWER: the release's search is asked whatever it is asked, and
// the results that come back are kept or dropped against the filter before the caller sees them.
- (void)setPointOfInterestFilter:(nullable MKPointOfInterestFilter *)filter
{
    objc_setAssociatedObject(self, (const void *)"charonPointOfInterestFilter", filter,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (nullable MKPointOfInterestFilter *)pointOfInterestFilter
{
    return objc_getAssociatedObject(self, (const void *)"charonPointOfInterestFilter");
}

// The release's own MKLocalSearchResponse and its own map item, read through the runtime because the
// port's own headers do not declare the response's members and the release's own response class is
// what arrives. Both helpers live here, on the request, because the request is what carries the two
// properties that decide the answer.

// What -resultTypes means for one result. The classification is the item's OWN POINT OF INTEREST
// CATEGORY, and that is a measurement, not a preference: -[MKMapItem type] and the
// MKMapItemTypeAddress / MKMapItemTypeAddressPoi constants it would return are in NEITHER held SDK
// (MKMapItem.h in 16.4 and in 26.2 declares -initWithPlacemark:, -initWithLocation:address: and the
// MKMapItemTypeIdentifier constant, and neither a -type nor those two constants), so there is no
// selector here to read. What IS declared is -[MKMapItem pointOfInterestCategory], whose type is the
// header's own MKPointOfInterestCategory, and that is what an ADDRESS DOES NOT HAVE: an address has
// no category, and every point of interest has one. So the question "is this a point of interest or
// an address" is answered by whether the item has a category, which is exactly the distinction the
// two enumerators of -resultTypes name.
- (BOOL)charon_resultTypesIncludeItemOfCategory:(nullable NSString *)category
{
    MKLocalSearchResultType types = [self resultTypes];
    // A request that asked for neither cannot be answered with anything.
    if ((types & (MKLocalSearchResultTypeAddress | MKLocalSearchResultTypePointOfInterest)) == 0) {
        return NO;
    }
    // No category means an address: the release's own -pointOfInterestCategory is nil for one.
    if (category == nil) {
        return (types & MKLocalSearchResultTypeAddress) != 0;
    }
    return (types & MKLocalSearchResultTypePointOfInterest) != 0;
}

// What -pointOfInterestFilter means for one map item: the filter's OWN -includesCategory:, against
// the item's OWN category, which is why a filter built against Apple's MKPointOfInterestCategory
// strings is a filter Apple's own map understands.
- (BOOL)charon_pointOfInterestFilterIncludesItemOfCategory:(NSString *)category
{
    MKPointOfInterestFilter *filter = [self pointOfInterestFilter];
    if (filter == nil) {
        return YES;
    }
    return [filter includesCategory:category];
}

@end

@implementation MKLocalSearch (CharonRequest)

// The release's own search, over the map's own points of interest -- which this release's map does not
// have, so the search is made with an empty request and says so through the error its own completion
// carries. The initialiser itself is the header's own shape, and a program that has a map with
// features on a later release gets its own points of interest here.
- (instancetype)initWithPointsOfInterestRequest:(id)request
{
    MKLocalSearchRequest *empty = CharonRequestInit([MKLocalSearchRequest alloc], @"");
    self = [self initWithRequest:empty];
    (void)request;
    return self;
}

@end

NS_ASSUME_NONNULL_END
