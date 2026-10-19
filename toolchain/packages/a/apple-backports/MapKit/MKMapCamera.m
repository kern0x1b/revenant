#import <MapKit/MKMapCamera.h>
#import <MapKit/MKMapItem.h>
#import <objc/message.h>
#import <math.h>
#import "RevenantMapKit.h"

@implementation MKMapCamera

@synthesize centerCoordinate = _centerCoordinate;
@synthesize centerCoordinateDistance = _centerCoordinateDistance;
@synthesize heading = _heading;
@synthesize pitch = _pitch;
@synthesize altitude = _altitude;

+ (instancetype)revenant_cameraAtCoordinate:(CLLocationCoordinate2D)coordinate
                                distance:(CLLocationDistance)distance
                                   pitch:(CGFloat)pitch
                                 heading:(CLLocationDirection)heading
{
    MKMapCamera *camera = [[self alloc] init];
    camera->_centerCoordinate = coordinate;
    camera->_centerCoordinateDistance = distance > 0.0 ? distance : 0.0;
    camera->_heading = heading;
    camera->_pitch = pitch;
    camera->_altitude = camera->_centerCoordinateDistance * cos((double)pitch * M_PI / 180.0);
    return camera;
}

+ (instancetype)camera
{
    return [self revenant_cameraAtCoordinate:CLLocationCoordinate2DMake(0.0, 0.0)
                                  distance:16000000.0
                                     pitch:0.0
                                   heading:0.0];
}

+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                             fromEyeCoordinate:(CLLocationCoordinate2D)eyeCoordinate
                                   eyeAltitude:(CLLocationDistance)eyeAltitude
{
    CLLocation *eye = [[CLLocation alloc] initWithLatitude:eyeCoordinate.latitude longitude:eyeCoordinate.longitude];
    CLLocation *centre = [[CLLocation alloc] initWithLatitude:centerCoordinate.latitude longitude:centerCoordinate.longitude];
    CLLocationDistance ground = [eye distanceFromLocation:centre];
    double altitude = eyeAltitude > 0.0 ? eyeAltitude : 0.0;
    CLLocationDistance distance = sqrt(ground * ground + altitude * altitude);
    double ratio = distance > 0.0 ? altitude / (double)distance : 0.0;
    if (ratio > 1.0) {
        ratio = 1.0;
    }
    CGFloat pitch = (CGFloat)(acos(ratio) * 180.0 / M_PI);
    CLLocationDirection heading = [RevenantMapKit revenant_bearingFromCoordinate:eyeCoordinate
                                                                 toCoordinate:centerCoordinate];
    return [self revenant_cameraAtCoordinate:centerCoordinate distance:distance pitch:pitch heading:heading];
}

+ (instancetype)cameraLookingAtCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                                    fromDistance:(CLLocationDistance)distance
                                           pitch:(CGFloat)pitch
                                         heading:(CLLocationDirection)heading
{
    return [self revenant_cameraAtCoordinate:centerCoordinate distance:distance pitch:pitch heading:heading];
}

+ (instancetype)cameraLookingAtMapItem:(MKMapItem *)mapItem
                            forViewSize:(CGSize)viewSize
                             allowPitch:(BOOL)allowPitch
{
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
    MKMapCamera *camera = [self revenant_cameraAtCoordinate:centre
                                                 distance:[self revenant_distanceForLatitudeSpan:span * aspect]
                                                    pitch:allowPitch ? 45.0 : 0.0
                                                  heading:0.0];
    return camera;
}

+ (CLLocationDistance)revenant_distanceForLatitudeSpan:(double)latitudeDegrees
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
