#import <MapKit/MapKit.h>
#import <MapKit/MKMapConfiguration.h>
#import <MapKit/MKStandardMapConfiguration.h>
#import <MapKit/MKHybridMapConfiguration.h>
#import <MapKit/MKImageryMapConfiguration.h>
#import <MapKit/MKPointOfInterestFilter.h>

@implementation MKMapConfiguration

@synthesize elevationStyle = _elevationStyle;

- (instancetype)init
{
    _elevationStyle = MKMapElevationStyleFlat;
    return [super init];
}

- (instancetype)revenant_baseInit
{
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    MKMapConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy.elevationStyle = _elevationStyle;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[MKMapConfiguration class]]) {
        return NO;
    }
    return [other isKindOfClass:[self class]] && ((MKMapConfiguration *)other).elevationStyle == _elevationStyle;
}

- (NSUInteger)hash
{
    return (NSUInteger)_elevationStyle;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_elevationStyle forKey:@"MKMapElevationStyle"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        _elevationStyle = (MKMapElevationStyle)[coder decodeIntegerForKey:@"MKMapElevationStyle"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@implementation MKStandardMapConfiguration {
    MKPointOfInterestFilter *_pointOfInterestFilter;
}

@synthesize emphasisStyle = _emphasisStyle;
@synthesize showsTraffic = _showsTraffic;

- (void)setPointOfInterestFilter:(MKPointOfInterestFilter *)filter
{
    _pointOfInterestFilter = [filter copy];
}

- (MKPointOfInterestFilter *)pointOfInterestFilter
{
    return _pointOfInterestFilter;
}

- (instancetype)init
{
    self = [self revenant_baseInit];
    if (self) {
        _emphasisStyle = MKStandardMapEmphasisStyleDefault;
        _showsTraffic = NO;
    }
    return self;
}

- (instancetype)initWithElevationStyle:(MKMapElevationStyle)elevationStyle
{
    self = [self init];
    if (self) {
        self.elevationStyle = elevationStyle;
    }
    return self;
}

- (instancetype)initWithElevationStyle:(MKMapElevationStyle)elevationStyle emphasisStyle:(MKStandardMapEmphasisStyle)emphasisStyle
{
    self = [self init];
    if (self) {
        self.elevationStyle = elevationStyle;
        _emphasisStyle = emphasisStyle;
    }
    return self;
}

- (instancetype)initWithEmphasisStyle:(MKStandardMapEmphasisStyle)emphasisStyle
{
    return [self initWithElevationStyle:MKMapElevationStyleFlat emphasisStyle:emphasisStyle];
}

@end

@implementation MKHybridMapConfiguration {
    MKPointOfInterestFilter *_pointOfInterestFilter;
}

@synthesize showsTraffic = _showsTraffic;

- (void)setPointOfInterestFilter:(MKPointOfInterestFilter *)filter
{
    _pointOfInterestFilter = [filter copy];
}

- (MKPointOfInterestFilter *)pointOfInterestFilter
{
    return _pointOfInterestFilter;
}

- (instancetype)init
{
    self = [self revenant_baseInit];
    if (self) {
        _showsTraffic = NO;
    }
    return self;
}

- (instancetype)initWithElevationStyle:(MKMapElevationStyle)elevationStyle
{
    self = [self init];
    if (self) {
        self.elevationStyle = elevationStyle;
    }
    return self;
}

@end

@implementation MKImageryMapConfiguration

- (instancetype)init
{
    return [self revenant_baseInit];
}

- (instancetype)initWithElevationStyle:(MKMapElevationStyle)elevationStyle
{
    self = [self init];
    if (self) {
        self.elevationStyle = elevationStyle;
    }
    return self;
}

@end
