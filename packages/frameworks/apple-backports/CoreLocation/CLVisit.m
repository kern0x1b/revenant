#import <CoreLocation/CoreLocation.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CLVisit {
    NSDate *_arrivalDate;
    NSDate *_departureDate;
    CLLocationCoordinate2D _coordinate;
    CLLocationAccuracy _horizontalAccuracy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _arrivalDate = [NSDate distantPast];
        _departureDate = [NSDate distantFuture];
        _coordinate = CLLocationCoordinate2DMake(-180, -180);
        _horizontalAccuracy = -1;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        _arrivalDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"arrivalDate"] ?: _arrivalDate;
        _departureDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"departureDate"] ?: _departureDate;
        _coordinate = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"latitude"], [coder decodeDoubleForKey:@"longitude"]);
        _horizontalAccuracy = [coder decodeDoubleForKey:@"horizontalAccuracy"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_arrivalDate forKey:@"arrivalDate"];
    [coder encodeObject:_departureDate forKey:@"departureDate"];
    [coder encodeDouble:_coordinate.latitude forKey:@"latitude"];
    [coder encodeDouble:_coordinate.longitude forKey:@"longitude"];
    [coder encodeDouble:_horizontalAccuracy forKey:@"horizontalAccuracy"];
}

- (id)copyWithZone:(NSZone *)zone
{
    CLVisit *copy = [[[self class] allocWithZone:zone] init];
    copy->_arrivalDate = _arrivalDate;
    copy->_departureDate = _departureDate;
    copy->_coordinate = _coordinate;
    copy->_horizontalAccuracy = _horizontalAccuracy;
    return copy;
}

- (NSDate *)arrivalDate
{
    return _arrivalDate;
}

- (NSDate *)departureDate
{
    return _departureDate;
}

- (CLLocationCoordinate2D)coordinate
{
    return _coordinate;
}

- (CLLocationAccuracy)horizontalAccuracy
{
    return _horizontalAccuracy;
}

@end
