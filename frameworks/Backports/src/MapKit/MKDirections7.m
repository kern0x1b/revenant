#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/message.h>
#import "RevenantMapKit.h"


static NSString *MKRevenantOSRMBase(void)
{
    NSString *fromEnvironment = [[[NSProcessInfo processInfo] environment] objectForKey:@"MKREVENANT_OSRM_BASE"];
    return fromEnvironment.length > 0 ? fromEnvironment : @"https://router.project-osrm.org";
}

static NSString *const MKRevenantOSRMProfileWalking = @"foot";
static NSString *const MKRevenantOSRMProfileCycling = @"bike";

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

- (NSString *)instructions
{
    if (_notice.length > 0) {
        return _notice;
    }
    return @"";
}

- (CLLocationDistance)distance
{
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
    NSDateComponentsFormatter *_revenant_duration;
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

- (NSString *)expectedTravelTimeString
{
    NSTimeInterval remaining = _expectedArrivalDate ? [_expectedArrivalDate timeIntervalSinceDate:_expectedDepartureDate]
                                                    : _expectedTravelTime;
    if (!_revenant_duration) {
        _revenant_duration = [[NSDateComponentsFormatter alloc] init];
        _revenant_duration.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        _revenant_duration.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
    }
    NSString *text = [_revenant_duration stringFromTimeInterval:remaining];
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

- (void)calculateDirectionsWithCompletionHandler:(void (^)(MKDirectionsResponse *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSURL *url = [self revenant_routeURL];
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, [self revenant_error]);
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
                completionHandler(nil, [[MKDirections class] revenant_abandonedError]);
                return;
            }
            strong->_calculating = NO;
            NSArray<MKRoute *> *routes = [strong revenant_routesOf:json request:strong->_request];
            if (routes.count == 0) {
                NSString *code = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"code"] : nil;
                NSString *why = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"message"] : nil;
                NSString *reason = [NSString stringWithFormat:
                                   @"OSRM answered no route: %@ %@",
                                   code ?: @"(nothing)", why ?: @"(no message)"];
                completionHandler(nil, [strong revenant_errorWithReason:reason]);
                return;
            }
            completionHandler([[MKDirectionsResponse alloc] initWithRoutes:routes
                                                                    source:strong->_request.source
                                                              destination:strong->_request.destination], nil);
        });
    });
}

- (void)calculateETAWithCompletionHandler:(void (^)(MKETAResponse *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSURL *url = [self revenant_routeURL];
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil, [self revenant_error]);
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
                completionHandler(nil, [[MKDirections class] revenant_abandonedError]);
                return;
            }
            strong->_calculating = NO;
            NSArray<MKRoute *> *routes = [strong revenant_routesOf:json request:strong->_request];
            MKRoute *route = routes.firstObject;
            if (!route) {
                completionHandler(nil, [strong revenant_errorWithReason:@"OSRM answered no route, so there is no arrival to calculate"]);
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

+ (NSError *)revenant_abandonedError
{
    return [NSError errorWithDomain:MKErrorDomain code:MKErrorDirectionsNotFound
                           userInfo:@{NSLocalizedDescriptionKey:
                                          @"the MKDirections that asked was released before the routing provider answered"}];
}

- (NSURL *)revenant_routeURL
{
    MKMapItem *source = _request.source;
    MKMapItem *destination = _request.destination;
    if (!source || !destination) {
        return nil;
    }
    CLLocationCoordinate2D from = [self revenant_coordinateOf:source];
    CLLocationCoordinate2D to = [self revenant_coordinateOf:destination];
    if (!CLLocationCoordinate2DIsValid(from) || !CLLocationCoordinate2DIsValid(to)) {
        return nil;
    }
    NSString *profile = [self revenant_profileForTransportType:_request.transportType];
    if (!profile) {
        return nil;
    }
    NSString *format = @"%@/route/v1/%@/%.6f,%.6f;%.6f,%.6f?overview=full&geometries=polyline&steps=true&alternatives=true";
    NSString *text = [NSString stringWithFormat:format, MKRevenantOSRMBase(), profile,
                      from.latitude, from.longitude, to.latitude, to.longitude];
    return [NSURL URLWithString:text];
}

- (CLLocationCoordinate2D)revenant_coordinateOf:(MKMapItem *)item
{
    id place = [item placemark];
    CLLocationCoordinate2D (*coordinate)(id, SEL) = (CLLocationCoordinate2D (*)(id, SEL))objc_msgSend;
    return place ? coordinate(place, @selector(coordinate)) : kCLLocationCoordinate2DInvalid;
}

- (NSString *)revenant_profileForTransportType:(MKDirectionsTransportType)transportType
{
    switch (transportType) {
        case MKDirectionsTransportTypeWalking:
            return MKRevenantOSRMProfileWalking;
        case MKDirectionsTransportTypeCycling:
            return MKRevenantOSRMProfileCycling;
        case MKDirectionsTransportTypeTransit:
            return nil;
        case MKDirectionsTransportTypeAutomobile:
        case MKDirectionsTransportTypeAny:
            return @"driving";
        default:
            return @"driving";
    }
}

- (NSArray<MKRoute *> *)revenant_routesOf:(id)json request:(MKDirectionsRequest *)request
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
        MKPolyline *whole = [self revenant_polylineOf:[entry objectForKey:@"geometry"]];
        NSMutableArray *steps = [NSMutableArray array];
        NSArray *legs = [entry objectForKey:@"legs"];
        if ([legs isKindOfClass:[NSArray class]]) {
            for (NSDictionary *leg in legs) {
                NSArray *legSteps = [leg objectForKey:@"steps"];
                if (![legSteps isKindOfClass:[NSArray class]]) {
                    continue;
                }
                for (NSDictionary *step in legSteps) {
                    MKPolyline *path = [self revenant_polylineOf:[step objectForKey:@"geometry"]];
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

- (MKPolyline *)revenant_polylineOf:(NSString *)encoded
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

- (NSError *)revenant_error
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

- (NSError *)revenant_errorWithReason:(NSString *)reason
{
    return [NSError errorWithDomain:MKErrorDomain code:MKErrorDirectionsNotFound
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

@end
