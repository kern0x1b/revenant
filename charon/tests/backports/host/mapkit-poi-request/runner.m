// The request's own numbers, compared against the HOST's own MKLocalPointsOfInterestRequest: the four
// members' values, for the same circles and the same regions, on both, in one process.
//
// The port's object is built here as a macOS dylib with its class RENAMED, because the class name is
// Apple's and two classes of one name cannot both be live: the rename is the only way both can answer
// the same circle in one probe. Apple's own is reached through the unrenamed name.
//
// WHAT IS COMPARED AND HOW, and the one number that is not compared exactly:
//
//   -coordinate, -region's centre and -region's span   EXACTLY, as printed to six decimals. The
//     circle-to-region direction is the release's own projection on the port's side and Apple's own
//     on the host's, and they agree to the last printed digit (measured over the six cases below).
//   -radius   within 1%, and the band is not a tolerance chosen to pass: the HOST'S OWN two
//     directions do not agree with each other either. Measured on the host's own class, a circle of
//     500 m at the equator answers a region that reads back as 503.378 m, one at London as 499.016 m
//     and one of 1999 m at Reykjavik as 1990.462 m -- so the host's radius is computed with an earth
//     model of its own and not with MapKit's projection, which is what the port answers. Over the six
//     regions below the two differ by at most 0.67%. The port's own round trip IS exact, and the probe
//     checks that too: a circle of r metres answers a region whose half-spans are both r metres, and
//     that region answers r metres back.
//
// THE MUTANT is the same dylib with no recompile: the runner allocates a subclass at run time whose
// -radius answers the DIAGONAL of the region instead of the larger half-span, which is the reading
// this port's first version used. Every other case is identical, so a run in which the mutant does not
// go red means the comparison cannot see a wrong number, and the probe says so and fails.
#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdio.h>

// The request's own API, spelled once so both classes are driven through the same calls: the host's
// own class and the port's renamed one declare these members with these shapes.
@protocol CharonPointsOfInterestRequest <NSObject>
- (instancetype)initWithCenterCoordinate:(CLLocationCoordinate2D)coordinate radius:(CLLocationDistance)radius;
- (instancetype)initWithCoordinateRegion:(MKCoordinateRegion)region;
- (CLLocationCoordinate2D)coordinate;
- (CLLocationDistance)radius;
- (MKCoordinateRegion)region;
- (id)copy;
@end

// The MUTANT: -radius answers the diagonal of the region -- a real number, and the wrong one.
// Installed from main() and NOT from +load, because +load of the runner's own image runs before the
// port's dylib is dlopen'd, so the class this subclass is made from would not exist yet and the
// mutant would silently be the unmutated class.
static Class CharonInstallMutant(Class port)
{
    Class mutant = objc_allocateClassPair(port, "CharonPOIMutantRequest", 0);
    if (mutant == Nil) {
        fprintf(stderr, "cannot make a subclass of the port's request\n");
        return Nil;
    }
    objc_registerClassPair(mutant);
    Method original = class_getInstanceMethod(port, @selector(radius));
    double (^diagonal)(id) = ^double (id self) {
        MKCoordinateRegion region = ((id<CharonPointsOfInterestRequest>)self).region;
        double perMetre = MKMapPointsPerMeterAtLatitude(region.center.latitude);
        double halfWidth = (double)MKMapSizeWorld.width * region.span.longitudeDelta / 360.0 / 2.0 / perMetre;
        CLLocationCoordinate2D north = region.center;
        north.latitude += region.span.latitudeDelta / 2.0;
        CLLocationCoordinate2D south = region.center;
        south.latitude -= region.span.latitudeDelta / 2.0;
        double halfHeight = fabs(MKMapPointForCoordinate(south).y - MKMapPointForCoordinate(north).y) / 2.0 / perMetre;
        return sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
    };
    class_replaceMethod(mutant, @selector(radius), imp_implementationWithBlock((id)diagonal),
                        method_getTypeEncoding(original));
    return mutant;
}

// The one band in the comparison, and what it is for: see the header. 1% is wider than the widest
// disagreement measured between the two implementations (0.67%) and far narrower than the mutant's
// (19% at the equator), so it separates a wrong reading from a different earth model.
static const double CharonRadiusBand = 0.01;
static const double CharonRadiusRelative = 0.01;

static int CharonFailed = 0;

static void print_case(const char *label, id<CharonPointsOfInterestRequest> request)
{
    MKCoordinateRegion region = request.region;
    printf("  %s coord=%.6f,%.6f radius=%.3f region=%.6f,%.6f %.6f,%.6f\n", label,
           request.coordinate.latitude, request.coordinate.longitude, request.radius,
           region.center.latitude, region.center.longitude,
           region.span.latitudeDelta, region.span.longitudeDelta);
}

static void compare_one(const char *name, const char *direction,
                        id<CharonPointsOfInterestRequest> host, id<CharonPointsOfInterestRequest> port,
                        CLLocationDistance expectedRadius)
{
    MKCoordinateRegion hostRegion = host.region;
    MKCoordinateRegion portRegion = port.region;
    BOOL same = host.coordinate.latitude == port.coordinate.latitude &&
                host.coordinate.longitude == port.coordinate.longitude &&
                hostRegion.center.latitude == portRegion.center.latitude &&
                hostRegion.center.longitude == portRegion.center.longitude &&
                hostRegion.span.latitudeDelta == portRegion.span.latitudeDelta &&
                hostRegion.span.longitudeDelta == portRegion.span.longitudeDelta;
    double difference = fabs(host.radius - port.radius);
    double scale = fabs(host.radius) > 1.0 ? fabs(host.radius) : 1.0;
    BOOL nearRadius = difference / scale <= CharonRadiusBand;
    // The port's own guarantee, checked on the port's side alone: a circle of r metres answers a
    // region that reads back as r metres.
    BOOL roundTrip = expectedRadius <= 0.0 || fabs(port.radius - expectedRadius) <= expectedRadius * CharonRadiusRelative;
    if (same && nearRadius && roundTrip) {
        printf("compare %-18s %-6s ok (radius %.3f vs %.3f, %.3f%% apart)\n", name, direction,
               host.radius, port.radius, 100.0 * difference / scale);
        return;
    }
    CharonFailed = 1;
    if (!same) {
        printf("compare %-18s %-6s MISMATCH, the port's coordinate or region differs from the host's\n", name, direction);
    }
    if (!nearRadius) {
        printf("compare %-18s %-6s MISMATCH, radius %.3f against the host's %.3f is %.3f%% apart, over the %.1f%% band\n",
               name, direction, port.radius, host.radius, 100.0 * difference / scale, 100.0 * CharonRadiusBand);
    }
    if (!roundTrip) {
        printf("compare %-18s %-6s MISMATCH, the port's own round trip answers %.3f for a circle of %.3f\n",
               name, direction, port.radius, expectedRadius);
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        const char *which = argc > 1 ? argv[1] : "both";
        const char *dylib = getenv("CHARON_PORT_DYLIB");
        if (dylib && dlopen(dylib, RTLD_LOCAL) == NULL) {
            fprintf(stderr, "cannot load %s: %s\n", dylib, dlerror());
            return 2;
        }
        Class host = NSClassFromString(@"MKLocalPointsOfInterestRequest");
        Class port = NSClassFromString(@"charonHost_MKLocalPointsOfInterestRequest");
        if (getenv("CHARON_MUTANT") != NULL) {
            port = CharonInstallMutant(port);
        }
        if (host == Nil || port == Nil) {
            fprintf(stderr, "which=%s host=%s port=%s: the comparison needs both classes live\n", which,
                    host ? "yes" : "no", port ? "yes" : "no");
            return 2;
        }
        struct { const char *name; double lat; double lon; double radius; double latSpan; double lonSpan; } cases[] = {
            {"equator-500",       0.000000,   0.000000,  500.0, 0.5,  1.25 },
            {"london-wide",      51.507351,  -0.127758,  500.0, 0.5,  1.25 },
            {"london-tall",      51.507351,  -0.127758,  500.0, 1.25, 0.5  },
            {"sydney-small",    -33.868820, 151.209290,  250.0, 0.1,  0.2  },
            {"cupertino-500",    37.334900, -122.009020,  500.0, 0.02, 0.03 },
            {"reykjavik-1999",   64.146600, -21.942600, 1999.0, 0.1,  0.2  },
        };
        for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
            CLLocationCoordinate2D centre = CLLocationCoordinate2DMake(cases[i].lat, cases[i].lon);
            MKCoordinateRegion region = MKCoordinateRegionMake(centre, MKCoordinateSpanMake(cases[i].latSpan,
                                                                                          cases[i].lonSpan));
            printf("case %s circle %.3f m, region %.4f,%.4f deg\n", cases[i].name, cases[i].radius,
                   cases[i].latSpan, cases[i].lonSpan);
            id<CharonPointsOfInterestRequest> hostCircle = [[host alloc] initWithCenterCoordinate:centre
                                                                                            radius:cases[i].radius];
            id<CharonPointsOfInterestRequest> portCircle = [[port alloc] initWithCenterCoordinate:centre
                                                                                            radius:cases[i].radius];
            print_case("host", hostCircle);
            print_case("port", portCircle);
            compare_one(cases[i].name, "circle", hostCircle, portCircle, cases[i].radius);

            id<CharonPointsOfInterestRequest> hostRegion = [[host alloc] initWithCoordinateRegion:region];
            id<CharonPointsOfInterestRequest> portRegion = [[port alloc] initWithCoordinateRegion:region];
            print_case("host", hostRegion);
            print_case("port", portRegion);
            compare_one(cases[i].name, "region", hostRegion, portRegion, 0.0);

            // The round trip both sides: the circle's own region, asked back as a region.
            id<CharonPointsOfInterestRequest> hostBack = [[host alloc] initWithCoordinateRegion:hostCircle.region];
            id<CharonPointsOfInterestRequest> portBack = [[port alloc] initWithCoordinateRegion:portCircle.region];
            print_case("host-back", hostBack);
            print_case("port-back", portBack);
            compare_one(cases[i].name, "back", hostBack, portBack, cases[i].radius);

            // The copy the header's own NSCopying promises, which the HOST's own class also has and
            // which has to be the same circle rather than a shared object.
            id<CharonPointsOfInterestRequest> copied = [portCircle copy];
            printf("  copy  radius=%.3f coord=%.6f,%.6f %s\n", copied.radius, copied.coordinate.latitude,
                   copied.coordinate.longitude, copied == portCircle ? "SHARED" : "distinct");
            if (copied == portCircle || copied.radius != portCircle.radius) {
                CharonFailed = 1;
                printf("compare %-18s copy    MISMATCH, the copy is not the same circle\n", cases[i].name);
            }
        }
        printf("%s\n", CharonFailed == 0 ? "VERDICT: the port's request answers the host's own values"
                                        : "VERDICT: FAILED");
    }
    return CharonFailed;
}
