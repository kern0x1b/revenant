// MKMapCamera: where the map is looking, from which point, in which direction and at what angle.
// The release's MKMapView is a flat, north-up, unrotated map with a region, so the camera is the
// iOS 7 way of saying the same thing plus the two freedoms the release's map view has not: a
// heading and a pitch. Every number here is derived from the release's own projection
// (MKMapPointForCoordinate, MKCoordinateForMapPoint, MKMetersPerMapPointAtLatitude) so a camera
// this class builds and a region the release's own MKMapView builds agree.
#import <MapKit/MKMapCamera.h>
#import <MapKit/MKMapItem.h>
#import <objc/message.h>
#import <math.h>
#import "CharonMapKit.h"

@implementation MKMapCamera

@synthesize centerCoordinate = _centerCoordinate;
@synthesize centerCoordinateDistance = _centerCoordinateDistance;
@synthesize heading = _heading;
@synthesize pitch = _pitch;
@synthesize altitude = _altitude;

// One camera from the four numbers the class stores, whatever order they arrive in. Charon's own,
// so it carries no API.
+ (instancetype)charon_cameraAtCoordinate:(CLLocationCoordinate2D)coordinate
                                distance:(CLLocationDistance)distance
                                   pitch:(CGFloat)pitch
                                 heading:(CLLocationDirection)heading
{
    MKMapCamera *camera = [[self alloc] init];
    camera->_centerCoordinate = coordinate;
    camera->_centerCoordinateDistance = distance > 0.0 ? distance : 0.0;
    camera->_heading = heading;
    camera->_pitch = pitch;
    // The altitude is the camera's own height above the centre, which is the distance the camera
    // looks across times the cosine of its pitch -- the identity measured above, and the one the
    // two setters below keep.
    camera->_altitude = camera->_centerCoordinateDistance * cos((double)pitch * M_PI / 180.0);
    return camera;
}

+ (instancetype)camera
{
    // The documented default: the whole world, looking straight down, north up.
    return [self charon_cameraAtCoordinate:CLLocationCoordinate2DMake(0.0, 0.0)
                                  distance:16000000.0
                                     pitch:0.0
                                   heading:0.0];
}

// The camera a release's own eye and altitude make, and the CONVENTION is measured, not assumed.
//
// Four cases measured against the host's own MapKit (tests/backports/host/mapkit, the eye/centre
// pairs and altitudes it prints) give two identities that hold to the last digit, for all four:
//
//   altitude == centerCoordinateDistance * cos(pitch)
//   sqrt(centerCoordinateDistance^2 - altitude^2) == the great-circle distance between the eye
//       and the centre
//
// so PITCH IS MEASURED FROM THE VERTICAL -- 0 is straight down, which is what the SDK's own comment
// on MKMapCamera.pitch says -- and the distance is the HYPOTENUSE of that great circle and the eye
// altitude, not the great circle itself. An earlier version of this file took the distance to be the
// great circle and the pitch to be the angle above the ground, which is the complement of Apple's
// and was wrong by 90 degrees minus the true angle.
+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                             fromEyeCoordinate:(CLLocationCoordinate2D)eyeCoordinate
                                   eyeAltitude:(CLLocationDistance)eyeAltitude
{
    CLLocation *eye = [[CLLocation alloc] initWithLatitude:eyeCoordinate.latitude longitude:eyeCoordinate.longitude];
    CLLocation *centre = [[CLLocation alloc] initWithLatitude:centerCoordinate.latitude longitude:centerCoordinate.longitude];
    // The distance the release's own CLLocation measures between the two, and the altitude the
    // caller put the eye at, which is the height above the centre.
    CLLocationDistance ground = [eye distanceFromLocation:centre];
    double altitude = eyeAltitude > 0.0 ? eyeAltitude : 0.0;
    CLLocationDistance distance = sqrt(ground * ground + altitude * altitude);
    // The pitch from the vertical, which is the angle whose cosine is the altitude over the distance.
    double ratio = distance > 0.0 ? altitude / (double)distance : 0.0;
    if (ratio > 1.0) {
        ratio = 1.0;
    }
    CGFloat pitch = (CGFloat)(acos(ratio) * 180.0 / M_PI);
    // The heading, the INITIAL bearing of the great circle, which is what the host's own answers on
    // the short legs: London->Paris the two differ by 0.97 degrees, and the port and the host agree
    // there. Across the Atlantic they differ by 26.8 degrees and the port does not pretend to know
    // the host's rule; the differential asserts that divergence is still live and names it.
    CLLocationDirection heading = [CharonMapKit charon_bearingFromCoordinate:eyeCoordinate
                                                                 toCoordinate:centerCoordinate];
    return [self charon_cameraAtCoordinate:centerCoordinate distance:distance pitch:pitch heading:heading];
}

+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                                    fromDistance:(CLLocationDistance)distance
                                           pitch:(CGFloat)pitch
                                         heading:(CLLocationDirection)heading
{
    return [self charon_cameraAtCoordinate:centerCoordinate distance:distance pitch:pitch heading:heading];
}

+ (instancetype)cameraLookingAtMapItem:(MKMapItem *)mapItem
                            forViewSize:(CGSize)viewSize
                             allowPitch:(BOOL)allowPitch
{
    // The release's own map item carries a placemark: -placemark is in the armv7 cache of 6.1.3
    // (measured with apple.objc.inventory), so a map item made by the release's own search, or by
    // this port's geocoding, has the coordinate to frame. A map item with no placemark has none, and
    // the honest answer then is the whole world, which is what fits in the view at this size.
    CLLocationCoordinate2D centre = CLLocationCoordinate2DMake(0.0, 0.0);
    double span = 360.0;
    id item = mapItem;
    if (item && [item respondsToSelector:@selector(placemark)]) {
        id (*placemark)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id place = placemark(item, @selector(placemark));
        CLLocationCoordinate2D (*coordinate)(id, SEL) = (CLLocationCoordinate2D (*)(id, SEL))objc_msgSend;
        if (place) {
            centre = coordinate(place, @selector(coordinate));
            span = 0.02;
        }
    }
    double aspect = viewSize.height > 0.0 ? (double)viewSize.width / (double)viewSize.height : 1.0;
    MKMapCamera *camera = [self charon_cameraAtCoordinate:centre
                                                 distance:[self charon_distanceForLatitudeSpan:span * aspect]
                                                    pitch:allowPitch ? 45.0 : 0.0
                                                  heading:0.0];
    return camera;
}

// The centre-coordinate distance at which a span of that many degrees of latitude fills the view,
// through the release's own metres-per-map-point at the equator, which is the one place the two
// measures are the same everywhere.
+ (CLLocationDistance)charon_distanceForLatitudeSpan:(double)latitudeDegrees
{
    MKMapPoint centre = MKMapPointForCoordinate(CLLocationCoordinate2DMake(0.0, 0.0));
    MKMapPoint edge = MKMapPointForCoordinate(CLLocationCoordinate2DMake(0.0, latitudeDegrees));
    return fabs(edge.y - centre.y) * MKMetersPerMapPointAtLatitude(0.0);
}

- (instancetype)init
{
    _centerCoordinate = CLLocationCoordinate2DMake(0.0, 0.0);
    _centerCoordinateDistance = 0.0;
    _heading = 0.0;
    _pitch = 0.0;
    _altitude = 0.0;
    return self;
}

// The two spellings of one fact, as measured: the altitude is the distance the camera looks across
// times the cosine of its pitch. So setting one sets the other, and neither invents a number.
- (void)setAltitude:(CLLocationDistance)altitude
{
    _altitude = altitude;
    if (_pitch > 0.0) {
        _centerCoordinateDistance = altitude / cos((double)_pitch * M_PI / 180.0);
    }
}

- (void)setCenterCoordinateDistance:(CLLocationDistance)distance
{
    _centerCoordinateDistance = distance;
    if (distance > 0.0) {
        _altitude = distance * cos((double)_pitch * M_PI / 180.0);
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    MKMapCamera *copy = [[self class] allocWithZone:zone];
    copy->_centerCoordinate = _centerCoordinate;
    copy->_centerCoordinateDistance = _centerCoordinateDistance;
    copy->_heading = _heading;
    copy->_pitch = _pitch;
    copy->_altitude = _altitude;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        _centerCoordinate = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"MKCenterCoordinateLat"],
                                                        [coder decodeDoubleForKey:@"MKCenterCoordinateLon"]);
        _centerCoordinateDistance = [coder decodeDoubleForKey:@"MKCenterCoordinateDistance"];
        _heading = [coder decodeDoubleForKey:@"MKHeading"];
        _pitch = (CGFloat)[coder decodeDoubleForKey:@"MKPitch"];
        _altitude = [coder decodeDoubleForKey:@"MKAltitude"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_centerCoordinate.latitude forKey:@"MKCenterCoordinateLat"];
    [coder encodeDouble:_centerCoordinate.longitude forKey:@"MKCenterCoordinateLon"];
    [coder encodeDouble:_centerCoordinateDistance forKey:@"MKCenterCoordinateDistance"];
    [coder encodeDouble:_heading forKey:@"MKHeading"];
    [coder encodeDouble:(double)_pitch forKey:@"MKPitch"];
    [coder encodeDouble:_altitude forKey:@"MKAltitude"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKMapCamera: %p centre %.6f, %.6f distance %.1f heading %.1f pitch %.1f>",
            self, _centerCoordinate.latitude, _centerCoordinate.longitude, _centerCoordinateDistance, _heading, _pitch];
}

@end
