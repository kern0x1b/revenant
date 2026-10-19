// MKIconStyle and MKMapFeatureAnnotation, which iOS 16.0 added: the icon a map feature is drawn with,
// and the annotation a map feature is dropped on the map as. MKPointOfInterestFilter, of iOS 13.4, is
// in MKPointOfInterestFilter134.m.
#import <MapKit/MapKit.h>
#import <MapKit/MKIconStyle.h>
#import <MapKit/MKMapFeatureAnnotation.h>
#import <UIKit/UIKit.h>

@implementation MKIconStyle {
    UIColor *_backgroundColor;
    UIImage *_image;
}

@synthesize backgroundColor = _backgroundColor;
@synthesize image = _image;

- (instancetype)init
{
    // The header marks this unavailable: an icon style is what a map feature annotation brings with
    // it, made by whoever made the feature. It is still answered, so a caller that reaches it
    // through the runtime gets an empty style and not a crash.
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    MKIconStyle *copy = [[[self class] allocWithZone:zone] init];
    copy->_backgroundColor = _backgroundColor;
    copy->_image = _image;
    return copy;
}

@end

@implementation MKMapFeatureAnnotation {
    MKMapFeatureType _featureType;
    MKIconStyle *_iconStyle;
    MKPointOfInterestCategory _pointOfInterestCategory;
}

@synthesize featureType = _featureType;
@synthesize iconStyle = _iconStyle;
@synthesize pointOfInterestCategory = _pointOfInterestCategory;

- (instancetype)init
{
    return [super init];
}

- (CLLocationCoordinate2D)coordinate
{
    // A map feature is something the map itself knows about, not a place the caller gave a point
    // for: the annotation the release's map view holds for one has no coordinate of its own until
    // the map is asked for it, and this one is only ever dropped on a map that has the answer.
    return kCLLocationCoordinate2DInvalid;
}

- (NSString *)title
{
    return nil;
}

- (NSString *)subtitle
{
    return nil;
}

@end
