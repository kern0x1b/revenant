#import <MapKit/MapKit.h>
#import "check.h"

static MKMapItem *revenant_item(double latitude, double longitude)
{
    MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) addressDictionary:nil];
    return [[MKMapItem alloc] initWithPlacemark:placemark];
}

static NSString *revenant_type(MKDirectionsTransportType type)
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)type];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
        revenant_check(request.transportType == MKDirectionsTransportTypeAny, "a new request accepts any transport type", revenant_type(request.transportType));
        revenant_check(!request.requestsAlternateRoutes, "a new request asks for one route", @"alternate routes requested");
        revenant_check(request.departureDate == nil && request.arrivalDate == nil, "a new request has no departure or arrival date", @"a date is set");

        request.transportType = MKDirectionsTransportTypeWalking;
        revenant_check(request.transportType == MKDirectionsTransportTypeWalking, "walking reads back", revenant_type(request.transportType));

        MKDirectionsTransportType mixed = MKDirectionsTransportTypeAutomobile | MKDirectionsTransportTypeTransit;
        request.transportType = mixed;
        revenant_check(request.transportType == mixed, "a combination of transport types reads back", revenant_type(request.transportType));

        request.transportType = MKDirectionsTransportTypeAny;
        revenant_check(request.transportType == MKDirectionsTransportTypeAny, "any reads back after a narrower value", revenant_type(request.transportType));

        MKDirectionsRequest *other = [[MKDirectionsRequest alloc] init];
        request.transportType = MKDirectionsTransportTypeTransit;
        revenant_check(other.transportType == MKDirectionsTransportTypeAny && request.transportType == MKDirectionsTransportTypeTransit, "requests keep their own transport type", @"the value is shared");

        request.requestsAlternateRoutes = YES;
        revenant_check(request.requestsAlternateRoutes && !other.requestsAlternateRoutes, "alternate routes are per request", @"the value is shared or lost");
        request.requestsAlternateRoutes = NO;
        revenant_check(!request.requestsAlternateRoutes, "alternate routes can be switched off", @"still requested");

        NSDate *departure = [NSDate dateWithTimeIntervalSinceReferenceDate:1000];
        NSDate *arrival = [NSDate dateWithTimeIntervalSinceReferenceDate:5000];
        request.departureDate = departure;
        request.arrivalDate = arrival;
        revenant_check([request.departureDate isEqualToDate:departure] && [request.arrivalDate isEqualToDate:arrival], "the departure and arrival dates read back", [NSString stringWithFormat:@"%@ %@", request.departureDate, request.arrivalDate]);
        revenant_check(other.departureDate == nil && other.arrivalDate == nil, "the dates are per request", @"a date is shared");
        request.departureDate = nil;
        revenant_check(request.departureDate == nil && request.arrivalDate != nil, "a date can be cleared on its own", @"the other date changed");

        MKMapItem *source = revenant_item(37.33, -122.03);
        MKMapItem *destination = revenant_item(37.78, -122.41);
        request.source = source;
        request.destination = destination;
        revenant_check(request.source == source && request.destination == destination, "the system's source and destination are unaffected", @"the endpoints changed");

        for (int index = 0; index < 1000; index++) {
            @autoreleasepool {
                MKDirectionsRequest *scratch = [[MKDirectionsRequest alloc] init];
                scratch.transportType = MKDirectionsTransportTypeWalking;
                scratch.departureDate = [NSDate date];
                scratch.requestsAlternateRoutes = YES;
            }
        }
        MKDirectionsRequest *fresh = [[MKDirectionsRequest alloc] init];
        revenant_check(fresh.transportType == MKDirectionsTransportTypeAny && fresh.departureDate == nil && !fresh.requestsAlternateRoutes, "a request made after a thousand released ones starts with the defaults", revenant_type(fresh.transportType));
    }
    return revenant_finish();
}
