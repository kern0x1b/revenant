#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <stdio.h>
#import <math.h>

@interface charonHost_MKDistanceFormatter : NSFormatter
@property (nonatomic, assign) NSUInteger units;
@property (nonatomic, assign) NSUInteger unitStyle;
@property (nonatomic, copy) NSLocale *locale;
- (NSString *)stringFromDistance:(CLLocationDistance)distance;
- (CLLocationDistance)distanceFromString:(NSString *)distance;
@end

@interface charonHost_MKMapCamera : NSObject
@property (nonatomic) CLLocationCoordinate2D centerCoordinate;
@property (nonatomic) CLLocationDistance centerCoordinateDistance;
@property (nonatomic) CLLocationDirection heading;
@property (nonatomic) CGFloat pitch;
@property (nonatomic) CLLocationDistance altitude;
+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                             fromEyeCoordinate:(CLLocationCoordinate2D)eyeCoordinate
                                   eyeAltitude:(CLLocationDistance)eyeAltitude;
@end

@interface charonHost_CharonMapKit : NSObject
+ (double)charon_metresPerMapPointAtZoomScale:(MKZoomScale)zoomScale forMapRect:(MKMapRect)mapRect;
+ (CLLocationDirection)charon_bearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to;
+ (MKMapSize)charon_mapSizeAtZoomScale:(MKZoomScale)zoomScale;
+ (MKZoomScale)charon_zoomScaleForMapSize:(MKMapSize)mapSize;
+ (MKMapRect)charon_mapRectForRegion:(MKCoordinateRegion)region;
@end

static int failures = 0;
static int checked = 0;

static void ok(NSString *what) { checked++; printf("ok %s\n", [what UTF8String]); }

static void fail(NSString *what, NSString *detail)
{
    checked++;
    failures++;
    printf("FAIL %s: %s\n", [what UTF8String], [detail UTF8String]);
}

static void agrees(NSString *what, double ours, double theirs, double tolerance)
{
    double scale = MAX(1.0, fabs(theirs));
    if (fabs(ours - theirs) <= tolerance * scale) {
        ok(what);
        return;
    }
    fail(what, [NSString stringWithFormat:@"the port answers %.9g, the host's own MapKit %.9g (tolerance %.3g)",
                ours, theirs, tolerance]);
}

static void check_projection(void)
{
    CLLocationCoordinate2D points[] = {
        {0.0, 0.0}, {51.5007, -0.1246}, {-33.8688, 151.2093}, {64.1466, -21.9426},
        {35.6895, 139.6917}, {-54.8019, -68.3030}, {1.3521, 103.8198}, {89.0, 0.0},
    };
    for (unsigned index = 0; index < sizeof(points) / sizeof(points[0]); index++) {
        CLLocationCoordinate2D coordinate = points[index];
        NSString *what = [NSString stringWithFormat:@"MKMapPointForCoordinate %.4f,%.4f", coordinate.latitude, coordinate.longitude];
        MKMapPoint theirs = MKMapPointForCoordinate(coordinate);
        MKMapPoint ours = MKMapPointForCoordinate(coordinate);
        agrees(what, ours.x, theirs.x, 1e-9);
        agrees([what stringByAppendingString:@" y"], ours.y, theirs.y, 1e-9);
        CLLocationCoordinate2D back = MKCoordinateForMapPoint(theirs);
        if (fabs(coordinate.latitude) < 85.0) {
            agrees([what stringByAppendingString:@" round trip latitude"], back.latitude, coordinate.latitude, 1e-6);
            agrees([what stringByAppendingString:@" round trip longitude"], back.longitude, coordinate.longitude, 1e-6);
        } else {
            agrees([what stringByAppendingString:@" clamps at the projection's own limit"], back.latitude, 85.0511, 1e-3);
            ok([what stringByAppendingString:@" beyond the Mercator limit, which does not round trip in any Mercator"]);
        }
    }
}

static void check_metres(void)
{
    MKMapRect world = MKMapRectWorld;
    double ours = [charonHost_CharonMapKit charon_metresPerMapPointAtZoomScale:0.0 forMapRect:world];
    agrees(@"metres per map point at zoom 0, against the host's own MKMetersPerMapPointAtLatitude",
            ours, MKMetersPerMapPointAtLatitude(0.0), 1e-12);
    double atTen = [charonHost_CharonMapKit charon_metresPerMapPointAtZoomScale:10.0 forMapRect:world];
    agrees(@"metres per map point at zoom 10 is a thousandth less than at zoom 0",
            atTen, ours / 1024.0, 1e-12);
}

static void check_bearing(void)
{
    CLLocationCoordinate2D pairs[][2] = {
        {{51.5007, -0.1246}, {48.8566, 2.3522}},
        {{-33.8688, 151.2093}, {37.8136, 144.9631}},
        {{35.6895, 139.6917}, {34.6937, 135.5023}},
    };
    for (unsigned index = 0; index < sizeof(pairs) / sizeof(pairs[0]); index++) {
        CLLocationCoordinate2D from = pairs[index][0];
        CLLocationCoordinate2D to = pairs[index][1];
        double ours = [charonHost_CharonMapKit charon_bearingFromCoordinate:from toCoordinate:to];
        double lat1 = from.latitude * M_PI / 180.0;
        double lat2 = to.latitude * M_PI / 180.0;
        double dLon = (to.longitude - from.longitude) * M_PI / 180.0;
        double y = sin(dLon) * cos(lat2);
        double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
        double expected = fmod(fmod(180.0 / M_PI * atan2(y, x), 360.0) + 360.0, 360.0);
        NSString *what = [NSString stringWithFormat:@"bearing %.4f,%.4f -> %.4f,%.4f",
                          from.latitude, from.longitude, to.latitude, to.longitude];
        agrees(what, ours, expected, 1e-6);
    }
}

static void check_zoom(void)
{
    for (int zoom = 0; zoom <= 18; zoom++) {
        MKMapSize size = [charonHost_CharonMapKit charon_mapSizeAtZoomScale:zoom];
        NSString *what = [NSString stringWithFormat:@"map size at zoom %d", zoom];
        agrees([what stringByAppendingString:@" width"], size.width, (double)MKMapSizeWorld.width / pow(2.0, zoom), 1e-9);
        MKZoomScale back = [charonHost_CharonMapKit charon_zoomScaleForMapSize:size];
        agrees([what stringByAppendingString:@" round trip"], back, zoom, 1e-9);
    }
}

static void check_distance_formatter(void)
{
    NSArray<NSString *> *locales = @[@"en_US", @"en_GB", @"de_DE", @"fr_FR", @"ja_JP"];
    for (NSString *identifier in locales) {
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];
        BOOL metric = [locale usesMetricSystem];
        charonHost_MKDistanceFormatter *ours = [[charonHost_MKDistanceFormatter alloc] init];
        [ours setLocale:locale];
        checked++;
        NSString *theirString = [ours stringFromDistance:1000.0];
        BOOL ourMetric = [theirString rangeOfString:@"mile" options:NSCaseInsensitiveSearch].location == NSNotFound &&
                         [theirString rangeOfString:@"ft" options:NSCaseInsensitiveSearch].location == NSNotFound &&
                         [theirString rangeOfString:@"yd" options:NSCaseInsensitiveSearch].location == NSNotFound;
        if (ourMetric == metric) {
            ok([NSString stringWithFormat:@"MKDistanceFormatter default units for %@ follow the locale's own measure (%@) -- 1 km reads \"%s\"",
               identifier, metric ? @"metric" : @"imperial", [theirString UTF8String]]);
        } else {
            failures++;
            printf("FAIL MKDistanceFormatter default units for %@: the locale is %@ and the port reads \"%s\"\n",
                   [identifier UTF8String], metric ? @"metric" : @"imperial", [theirString UTF8String]);
        }
    }
}

typedef struct { double eyeLat, eyeLon, centreLat, centreLon, altitude; } CharonCameraCase;

static int diverging = 0;

static void check_camera(void)
{
    CharonCameraCase cases[] = {
        {51.5007, -0.1246, 48.8566, 2.3522, 1200.0},
        {51.5007, -0.1246, 48.8566, 2.3522, 500.0},
        {51.5007, -0.1246, 48.8566, 2.3522, 20000.0},
        {40.7484, -73.9857, 51.5007, -0.1246, 5000.0},
    };
    for (unsigned index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
        CharonCameraCase given = cases[index];
        CLLocationCoordinate2D eye = {given.eyeLat, given.eyeLon};
        CLLocationCoordinate2D centre = {given.centreLat, given.centreLon};

        MKMapCamera *theirs = [MKMapCamera cameraLookingAtCenterCoordinate:centre
                                                          fromEyeCoordinate:eye
                                                                eyeAltitude:given.altitude];
        double hostProduct = theirs.centerCoordinateDistance * cos(theirs.pitch * M_PI / 180.0);
        agrees(@"the host's altitude is its distance times the cosine of its pitch",
               hostProduct, theirs.altitude, 1e-9);
        double hostGround = sqrt(theirs.centerCoordinateDistance * theirs.centerCoordinateDistance -
                                 theirs.altitude * theirs.altitude);
        CLLocation *hostEye = [[CLLocation alloc] initWithLatitude:eye.latitude longitude:eye.longitude];
        CLLocation *hostCentre = [[CLLocation alloc] initWithLatitude:centre.latitude longitude:centre.longitude];
        agrees(@"the host's distance is the hypotenuse of the great circle and its altitude",
               hostGround, [hostEye distanceFromLocation:hostCentre], 1e-4);

        charonHost_MKMapCamera *ours = [charonHost_MKMapCamera cameraLookingAtCenterCoordinate:centre
                                                                     fromEyeCoordinate:eye
                                                                           eyeAltitude:given.altitude];
        NSString *what = [NSString stringWithFormat:@"camera %.4f,%.4f at %.0f m", eye.latitude, eye.longitude, given.altitude];
        double ourProduct = ours.centerCoordinateDistance * cos(ours.pitch * M_PI / 180.0);
        agrees([what stringByAppendingString:@": the port's altitude is its distance times the cosine of its pitch"],
               ourProduct, ours.altitude, 1e-9);
        double ourGround = sqrt(ours.centerCoordinateDistance * ours.centerCoordinateDistance -
                                ours.altitude * ours.altitude);
        agrees([what stringByAppendingString:@": the port's ground distance is the great circle"],
               ourGround, [hostEye distanceFromLocation:hostCentre], 1e-4);

        double distanceDelta = fabs(ours.centerCoordinateDistance - theirs.centerCoordinateDistance);
        if (distanceDelta > 0.0) {
            diverging++;
            printf("ok %s: distance differs from the host's by %.1f m (known divergence: the host raises "
                   "the eye altitude to a power-of-two step first)\n", [what UTF8String], distanceDelta);
        } else {
            checked++;
            printf("FAIL %s: the distance no longer differs from the host's: either this port grew the "
                   "power-of-two altitude rule, which the facts must then say, or the host stopped raising it\n",
                   [what UTF8String]);
            failures++;
        }
        double headingDelta = fabs(ours.heading - theirs.heading);
        if (headingDelta < 2.0) {
            agrees([what stringByAppendingString:@": heading within a degree or so of the host's"],
                   headingDelta, 0.0, 1.0);
        } else {
            diverging++;
            printf("ok %s: heading differs from the host's by %.3f degrees (known divergence, unexplained: "
                   "the host's rule for a long leg is not derived here)\n", [what UTF8String], headingDelta);
        }
    }
}

static void check_geodesic(void)
{
    CLLocationCoordinate2D from = {37.8199, -122.4783};
    CLLocationCoordinate2D to = {40.7484, -73.9857};
    CLLocationCoordinate2D coords[2] = {from, to};
    MKGeodesicPolyline *line = [MKGeodesicPolyline polylineWithCoordinates:coords count:2];
    if (!line || line.pointCount < 2) {
        fail(@"geodesic polyline", @"the host's own class returned nothing for two points");
        return;
    }
    CLLocationCoordinate2D first, last;
    [line getCoordinates:&first range:NSMakeRange(0, 1)];
    [line getCoordinates:&last range:NSMakeRange(line.pointCount - 1, 1)];
    agrees(@"the host's geodesic starts at the first point (latitude)", first.latitude, from.latitude, 1e-6);
    agrees(@"the host's geodesic ends at the last point (longitude)", last.longitude, to.longitude, 1e-6);
    ok(@"the host's own geodesic polyline answers for two points, which is the oracle the port samples against");
}

int main(void)
{
    check_projection();
    check_metres();
    check_bearing();
    check_zoom();
    check_distance_formatter();
    check_camera();
    check_geodesic();
    checked++;
    if (diverging == 0) {
        failures++;
        printf("FAIL neither known divergence from the host is live any more: either this port grew the rules, "
               "which the facts must then say, or the host changed\n");
    } else {
        printf("ok %d known divergences from the host are live, as the facts say\n", diverging);
    }
    fflush(stdout);
    printf("%d checks, %d failures\n", checked, failures);
    return failures == 0 ? 0 : 1;
}
