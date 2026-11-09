#import <MapKit/MapKit.h>
#import <objc/runtime.h>

static const char revenant_transport_type_key;
static const char revenant_alternate_routes_key;
static const char revenant_departure_date_key;
static const char revenant_arrival_date_key;

@implementation MKDirectionsRequest (RevenantRequestOptions7)

- (MKDirectionsTransportType)transportType
{
    NSNumber *stored = objc_getAssociatedObject(self, &revenant_transport_type_key);
    return stored ? (MKDirectionsTransportType)stored.unsignedIntegerValue : MKDirectionsTransportTypeAny;
}

- (void)setTransportType:(MKDirectionsTransportType)transportType
{
    objc_setAssociatedObject(self, &revenant_transport_type_key, @(transportType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)requestsAlternateRoutes
{
    return [objc_getAssociatedObject(self, &revenant_alternate_routes_key) boolValue];
}

- (void)setRequestsAlternateRoutes:(BOOL)requestsAlternateRoutes
{
    objc_setAssociatedObject(self, &revenant_alternate_routes_key, @(requestsAlternateRoutes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDate *)departureDate
{
    return objc_getAssociatedObject(self, &revenant_departure_date_key);
}

- (void)setDepartureDate:(NSDate *)departureDate
{
    objc_setAssociatedObject(self, &revenant_departure_date_key, departureDate, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSDate *)arrivalDate
{
    return objc_getAssociatedObject(self, &revenant_arrival_date_key);
}

- (void)setArrivalDate:(NSDate *)arrivalDate
{
    objc_setAssociatedObject(self, &revenant_arrival_date_key, arrivalDate, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
