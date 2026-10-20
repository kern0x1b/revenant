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
