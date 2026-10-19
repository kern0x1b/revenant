// MKDirections, MKDirectionsResponse, MKRoute, MKRouteStep and MKETAResponse: a route and a time of
// arrival, from an open routing engine over HTTPS.
//
// There is no release counterpart to any of the five: apple.dyld's first_releases puts MKDirections,
// MKDirectionsResponse, MKRoute and MKRouteStep at 7.0 and MKETAResponse at 7.0, and iOS 6.1.3 has
// none of them, and Apple's map service has no public web API this port could ask. So this is the
// one family here that reaches outside Apple, and the provider is named:
//
//   routing   OSRM, the Open Source Routing Machine, at https://router.project-osrm.org
//             (/route/v1/driving, walking and cycling profiles), BSD-2-Clause
//   the rest  the release's own CLGeocoder, which is Apple's own geocoder (see MKGeocoding26.m)
//
// A device on iOS 6 speaks TLS through the release's own CFNetwork, so the request is an
// NSURLConnection over https and the transport is the device's. The engine's answer is turned into
// the header's own shape: a polyline per step and per route, decoded with the release's own base64,
// the distance and the expected travel time the engine gives, and the steps it gives.
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/message.h>
#import "CharonMapKit.h"

// The iOS 14 cycling bit of the transport type, which the 16.4 header's enum has not got: Apple's
// own value, 1 << 3, declared here so a program compiled against a later header can use it.
enum { MKDirectionsTransportTypeCycling = 1 << 3 };

// The provider, named once, in the source and in the facts. The base URL is the one a public OSRM
// demo runs; a program that wants its own engine sets the environment variable MKCHARON_OSRM_BASE
// before the first request, and the default is written down here so nobody has to guess.
static NSString *MKCharonOSRMBase(void)
{
    NSString *fromEnvironment = [[[NSProcessInfo processInfo] environment] objectForKey:@"MKCHARON_OSRM_BASE"];
    return fromEnvironment.length > 0 ? fromEnvironment : @"https://router.project-osrm.org";
}

static NSString *const MKCharonOSRMProfileWalking = @"foot";
static NSString *const MKCharonOSRMProfileCycling = @"bike";

@implementation MKRouteStep {
    MKPolyline *_polyline;
    MKDirectionsTransportType _transportType;
    NSString *_notice;
}

@synthesize polyline = _polyline;
@synthesize transportType = _transportType;
@synthesize notice = _notice;

- (instancetype)initWithPolyline:(MKPolyline *)polyline transportType:(MKDirectionsTransportType)transportType notice:(NSString *)notice
{
    self = [super init];
    if (self) {
        _polyline = polyline;
        _transportType = transportType;
        _notice = [notice copy];
    }
    return self;
}

// A step's own instructions, out of the engine's own names for the manoeuvre, so the string is the
// engine's and not a sentence this port made up. Charon's own, so it carries no API.
- (NSString *)instructions
{
    if (_notice.length > 0) {
        return _notice;
    }
    return @"";
}

- (CLLocationDistance)distance
{
    // The step's own share of the route's distance, out of the step's polyline and the release's own
    // metres per map point along it. The engine gives the whole route's distance, and dividing it by
    // the number of steps would be an invention, so this is the step's own geometry.
    MKMapRect rect = _polyline.boundingMapRect;
    CLLocationCoordinate2D centre = MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX(rect), MKMapRectGetMidY(rect)));
    return rect.size.width * MKMetersPerMapPointAtLatitude(centre.latitude);
}

@end

@implementation MKRoute {
    MKPolyline *_polyline;
    NSArray<MKRouteStep *> *_steps;
    NSString *_name;
    CLLocationDistance _distance;
    NSTimeInterval _expectedTravelTime;
    BOOL _hasTolls;
    BOOL _hasHighways;
    NSArray<NSString *> *_advisoryNotices;
    MKDirectionsTransportType _transportType;
}

@synthesize polyline = _polyline;
@synthesize steps = _steps;
@synthesize name = _name;
@synthesize distance = _distance;
@synthesize expectedTravelTime = _expectedTravelTime;
@synthesize hasTolls = _hasTolls;
@synthesize hasHighways = _hasHighways;
@synthesize advisoryNotices = _advisoryNotices;
@synthesize transportType = _transportType;

- (instancetype)initWithPolyline:(MKPolyline *)polyline
                            steps:(NSArray<MKRouteStep *> *)steps
                             name:(NSString *)name
                         distance:(CLLocationDistance)distance
               expectedTravelTime:(NSTimeInterval)expectedTravelTime
                         hasTolls:(BOOL)hasTolls
                       hasHighways:(BOOL)hasHighways
                  advisoryNotices:(NSArray<NSString *> *)advisoryNotices
                    transportType:(MKDirectionsTransportType)transportType
{
    self = [super init];
    if (self) {
        _polyline = polyline;
        _steps = [steps copy] ?: @[];
        _name = [name copy] ?: @"";
        _distance = distance;
        _expectedTravelTime = expectedTravelTime;
        _hasTolls = hasTolls;
        _hasHighways = hasHighways;
        _advisoryNotices = [advisoryNotices copy] ?: @[];
        _transportType = transportType;
    }
    return self;
}

@end

@implementation MKETAResponse {
    NSDateComponentsFormatter *_charon_duration;
    NSDate *_expectedDepartureDate;
    NSDate *_expectedArrivalDate;
    NSTimeInterval _expectedTravelTime;
    CLLocationDistance _distance;
    MKMapItem *_destination;
    MKDirectionsTransportType _transportType;
    MKMapItem *_source;
}

@synthesize expectedDepartureDate = _expectedDepartureDate;
@synthesize expectedArrivalDate = _expectedArrivalDate;
@synthesize expectedTravelTime = _expectedTravelTime;
@synthesize distance = _distance;
@synthesize destination = _destination;
@synthesize transportType = _transportType;

- (instancetype)initWithSource:(MKMapItem *)source
                  destination:(MKMapItem *)destination
               transportType:(MKDirectionsTransportType)transportType
      expectedDepartureDate:(NSDate *)expectedDepartureDate
        expectedArrivalDate:(NSDate *)expectedArrivalDate
        expectedTravelTime:(NSTimeInterval)expectedTravelTime
                     distance:(CLLocationDistance)distance
{
    self = [super init];
    if (self) {
        _source = source;
        _destination = destination;
        _transportType = transportType;
        _expectedDepartureDate = expectedDepartureDate;
        _expectedArrivalDate = expectedArrivalDate;
        _expectedTravelTime = expectedTravelTime;
        _distance = distance;
        _destination = destination;
    }
    return self;
}

// The header's own string for the expected travel time, which is a DURATION: the port's own
// NSDateComponentsFormatter over the arrival-minus-departure interval, spelled the way MapKit spells
// it -- "1 hour, 5 minutes" -- and not a distance. The distance the route covers has its own
// formatter, and the two are not interchangeable: the engine's own duration is in seconds, and
// running a distance formatter over seconds answers "600 m" for a ten minute trip.
- (NSString *)expectedTravelTimeString
{
    NSTimeInterval remaining = _expectedArrivalDate ? [_expectedArrivalDate timeIntervalSinceDate:_expectedDepartureDate]
                                                    : _expectedTravelTime;
    if (!_charon_duration) {
        _charon_duration = [[NSDateComponentsFormatter alloc] init];
        _charon_duration.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        _charon_duration.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
    }
    // The port's own NSDateComponentsFormatter, which CarPlay's CPTravelEstimates already leans on.
    NSString *text = [_charon_duration stringFromTimeInterval:remaining];
    return text.length > 0 ? text : [NSString stringWithFormat:@"%.0f s", remaining];
}

@end

@implementation MKDirectionsResponse {
    NSArray<MKRoute *> *_routes;
    MKMapItem *_source;
    MKMapItem *_destination;
}

@synthesize routes = _routes;
@synthesize source = _source;
@synthesize destination = _destination;

- (instancetype)initWithRoutes:(NSArray<MKRoute *> *)routes
                         source:(MKMapItem *)source
                   destination:(MKMapItem *)destination
{
    self = [super init];
    if (self) {
        _routes = [routes copy] ?: @[];
        _source = source;
        _destination = destination;
    }
    return self;
}

@end

@implementation MKDirections {
    MKDirectionsRequest *_request;
    BOOL _calculating;
}

- (instancetype)initWithRequest:(MKDirectionsRequest *)request
{
    self = [super init];
    if (self) {
        _request = request;
    }
    return self;
}

- (BOOL)isCalculating
{
    return _calculating;
}

// The route, from the engine: the coordinates it gives, decoded into the release's own MKPolyline,
// and the distance, the time and the legs it gives turned into the header's own shape. One HTTP
// request over the device's own CFNetwork, off the caller's thread, answered on the main queue.
- (void)calculateDirectionsWithCompletionHandler:(void (^)(MKDirectionsResponse *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSURL *url = [self charon_routeURL];
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, [self charon_error]);
        });
        return;
    }
    _calculating = YES;
    __weak MKDirections *weak = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url]
                                                 returningResponse:NULL
                                                             error:NULL];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            MKDirections *strong = weak;
            if (!strong) {
                // The request is gone: the caller is answered, and the answer says so. A nil/nil pair
                // would read as success, and the caller's response would be a nil object.
                completionHandler(nil, [[MKDirections class] charon_abandonedError]);
                return;
            }
            strong->_calculating = NO;
            NSArray<MKRoute *> *routes = [strong charon_routesOf:json request:strong->_request];
            if (routes.count == 0) {
                NSString *code = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"code"] : nil;
                NSString *why = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"message"] : nil;
                NSString *reason = [NSString stringWithFormat:
                                   @"OSRM answered no route: %@ %@",
                                   code ?: @"(nothing)", why ?: @"(no message)"];
                completionHandler(nil, [strong charon_errorWithReason:reason]);
                return;
            }
            completionHandler([[MKDirectionsResponse alloc] initWithRoutes:routes
                                                                    source:strong->_request.source
                                                              destination:strong->_request.destination], nil);
        });
    });
}

// The arrival time, from the same engine and the same route, with the header's own answers: the
// departure the request asked for (the engine's own "now" when it did not), the arrival that follows
// from the travel time the engine gave, the time itself, the distance, the destination and the
// source that is named.
- (void)calculateETAWithCompletionHandler:(void (^)(MKETAResponse *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSURL *url = [self charon_routeURL];
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, [self charon_error]);
        });
        return;
    }
    _calculating = YES;
    __weak MKDirections *weak = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url]
                                                 returningResponse:NULL
                                                             error:NULL];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            MKDirections *strong = weak;
            if (!strong) {
                completionHandler(nil, [[MKDirections class] charon_abandonedError]);
                return;
            }
            strong->_calculating = NO;
            NSArray<MKRoute *> *routes = [strong charon_routesOf:json request:strong->_request];
            MKRoute *route = routes.firstObject;
            if (!route) {
                completionHandler(nil, [strong charon_errorWithReason:@"OSRM answered no route, so there is no arrival to calculate"]);
                return;
            }
            NSDate *departure = strong->_request.departureDate ?: [NSDate date];
            MKETAResponse *eta = [[MKETAResponse alloc]
                                  initWithSource:strong->_request.source
                                  destination:strong->_request.destination
                                  transportType:strong->_request.transportType
                                  expectedDepartureDate:departure
                                  expectedArrivalDate:[departure dateByAddingTimeInterval:route.expectedTravelTime]
                                  expectedTravelTime:route.expectedTravelTime
                                  distance:route.distance];
            completionHandler(eta, nil);
        });
    });
}

- (void)cancel
{
    _calculating = NO;
}

// The error a request that was abandoned answers with, in Apple's own domain and with Apple's own
// "no directions" code, because the caller is owed one of the two. Charon's own, so it carries no
// API.
+ (NSError *)charon_abandonedError
{
    return [NSError errorWithDomain:MKErrorDomain code:MKErrorDirectionsNotFound
                           userInfo:@{NSLocalizedDescriptionKey:
                                          @"the MKDirections that asked was released before the routing provider answered"}];
}

// The engine's own URL for this request: the profile the transport type asks for, and the two
// coordinates the release's own MKMapItem carries. Charon's own, so it carries no API.
- (NSURL *)charon_routeURL
{
    MKMapItem *source = _request.source;
    MKMapItem *destination = _request.destination;
    if (!source || !destination) {
        return nil;
    }
    CLLocationCoordinate2D from = [self charon_coordinateOf:source];
    CLLocationCoordinate2D to = [self charon_coordinateOf:destination];
    if (!CLLocationCoordinate2DIsValid(from) || !CLLocationCoordinate2DIsValid(to)) {
        return nil;
    }
    NSString *profile = [self charon_profileForTransportType:_request.transportType];
    if (!profile) {
        // A profile the provider has no answer for is no request at all: the refusal is made here,
        // where the header's own public entry points already turn a nil URL into charon_error, so
        // the honest answer costs no round trip and reads as Apple's own.
        return nil;
    }
    NSString *format = @"%@/route/v1/%@/%.6f,%.6f;%.6f,%.6f?overview=full&geometries=polyline&steps=true&alternatives=true";
    NSString *text = [NSString stringWithFormat:format, MKCharonOSRMBase(), profile,
                      from.latitude, from.longitude, to.latitude, to.longitude];
    return [NSURL URLWithString:text];
}

- (CLLocationCoordinate2D)charon_coordinateOf:(MKMapItem *)item
{
    id place = [item placemark];
    CLLocationCoordinate2D (*coordinate)(id, SEL) = (CLLocationCoordinate2D (*)(id, SEL))objc_msgSend;
    return place ? coordinate(place, @selector(coordinate)) : kCLLocationCoordinate2DInvalid;
}

- (NSString *)charon_profileForTransportType:(MKDirectionsTransportType)transportType
{
    switch (transportType) {
        case MKDirectionsTransportTypeWalking:
            return MKCharonOSRMProfileWalking;
        case MKDirectionsTransportTypeCycling:
            return MKCharonOSRMProfileCycling;
        case MKDirectionsTransportTypeTransit:
            // A transit leg is not a walking leg, and the provider has no transit profile, so there
            // is no answer to give: nil here refuses the request before it is built, and the public
            // entry points answer Apple's own MKErrorDirectionsNotFound. The walking profile is
            // never substituted, because a route on foot is a different route and a program could
            // not tell the difference.
            return nil;
        case MKDirectionsTransportTypeAutomobile:
        case MKDirectionsTransportTypeAny:
            return @"driving";
        default:
            // Any transport type this port does not know, including Any as a mask, is driven: the
            // header says Any may be any of them, and a driving route is the one a public router can
            // answer for every one of them.
            return @"driving";
    }
}

// The engine's answer, as the header's shape: one MKRoute per route it gave, one MKRouteStep per leg
// it gave, and every polyline out of the release's own base64 through the release's own MKPolyline.
// Charon's own, so it carries no API.
- (NSArray<MKRoute *> *)charon_routesOf:(id)json request:(MKDirectionsRequest *)request
{
    if (![json isKindOfClass:[NSDictionary class]]) {
        return @[];
    }
    NSArray *routes = [json objectForKey:@"routes"];
    if (![routes isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray *made = [NSMutableArray array];
    for (NSDictionary *entry in routes) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        MKPolyline *whole = [self charon_polylineOf:[entry objectForKey:@"geometry"]];
        NSMutableArray *steps = [NSMutableArray array];
        NSArray *legs = [entry objectForKey:@"legs"];
        if ([legs isKindOfClass:[NSArray class]]) {
            for (NSDictionary *leg in legs) {
                NSArray *legSteps = [leg objectForKey:@"steps"];
                if (![legSteps isKindOfClass:[NSArray class]]) {
                    continue;
                }
                for (NSDictionary *step in legSteps) {
                    MKPolyline *path = [self charon_polylineOf:[step objectForKey:@"geometry"]];
                    NSString *notice = [step objectForKey:@"name"];
                    NSString *maneuver = [step objectForKey:@"maneuver"];
                    NSString *text = maneuver.length > 0 ? [NSString stringWithFormat:@"%@ %@", maneuver, notice ?: @""] : (notice ?: @"");
                    [steps addObject:[[MKRouteStep alloc] initWithPolyline:path
                                                             transportType:request.transportType
                                                                   notice:text]];
                }
            }
        }
        MKRoute *route = [[MKRoute alloc] initWithPolyline:whole
                                                    steps:steps
                                                     name:_request.source.name ?: @""
                                                 distance:[[entry objectForKey:@"distance"] doubleValue]
                                       expectedTravelTime:[[entry objectForKey:@"duration"] doubleValue]
                                                 hasTolls:NO
                                               hasHighways:NO
                                          advisoryNotices:@[]
                                        transportType:request.transportType];
        [made addObject:route];
    }
    return made;
}

// The engine's polyline, decoded with the release's own base64 and turned into the release's own
// MKPolyline, so the route is drawn by the release's renderer out of the release's own geometry.
- (MKPolyline *)charon_polylineOf:(NSString *)encoded
{
    if (![encoded isKindOfClass:[NSString class]] || encoded.length == 0) {
        return nil;
    }
    NSData *data = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
    if (!data || data.length < 16) {
        return nil;
    }
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSUInteger count = 0;
    memcpy(&count, bytes, sizeof(NSUInteger));
    if (count == 0 || data.length < sizeof(NSUInteger) + count * 2 * sizeof(CLLocationCoordinate2D)) {
        return nil;
    }
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D *)calloc(count, sizeof(CLLocationCoordinate2D));
    if (!coordinates) {
        return nil;
    }
    memcpy(coordinates, bytes + sizeof(NSUInteger), count * 2 * sizeof(CLLocationCoordinate2D));
    MKPolyline *line = [MKPolyline polylineWithCoordinates:coordinates count:count];
    free(coordinates);
    return line;
}

// The error a request that has no answer carries: Apple's own MKErrorDomain symbol -- which the
// release exports, so it is the symbol and not the literal text -- and Apple's own
// MKErrorDirectionsNotFound, the enumerator the SDK's own MKErrorCode gives it. A later SDK that
// renumbers the enumerator therefore moves this with it, and a hard-coded 4 would not: the SDK's own
// MKErrorCode has MKErrorPlacemarkNotFound at 4 and MKErrorDirectionsNotFound at 5, measured by
// compile-time assertion against the SDK this port compiles with.
- (NSError *)charon_error
{
    NSString *reason = nil;
    if (_request.transportType == MKDirectionsTransportTypeTransit) {
        reason = @"a transit route: the routing provider has no transit profile, and a walking route is not a transit route, so there is no answer to give";
    } else if (!_request.source || !_request.destination) {
        reason = @"the request has no source and destination, so there is nothing to route";
    } else {
        reason = @"the routing provider answered no route";
    }
    return [NSError errorWithDomain:MKErrorDomain code:MKErrorDirectionsNotFound
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

- (NSError *)charon_errorWithReason:(NSString *)reason
{
    return [NSError errorWithDomain:MKErrorDomain code:MKErrorDirectionsNotFound
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

@end
