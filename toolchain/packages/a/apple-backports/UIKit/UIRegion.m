#import <UIKit/UIKit.h>
#include <math.h>

static const float CharonRegionPTM = 100.0f;
static const float CharonRegionInversePTM = 0.01f;

enum {
    CharonRegionInfinite = 1,
    CharonRegionEllipse = 2,
    CharonRegionRectangle = 3,
};

enum {
    CharonRegionAlone = 0,
    CharonRegionUnion = 1,
    CharonRegionMinus = 2,
    CharonRegionIntersection = 3,
};

typedef struct {
    int shape;
    BOOL exclusive;
    float halfWidth, halfHeight;
    int operation;
    int secondShape;
    float secondHalfWidth, secondHalfHeight;
} CharonRegion;

static float charon_region_ellipse(float halfWidth, float halfHeight, CGPoint point)
{
    float x = halfWidth > 0 ? (float)(point.x / (double)halfWidth) : 0;
    float y = halfHeight > 0 ? (float)(point.y / (double)halfHeight) : 0;
    return fmaf(x, x, y * y);
}

static BOOL charon_region_inside(int shape, float halfWidth, float halfHeight, CGPoint point)
{
    switch (shape) {
    case CharonRegionInfinite:
        return YES;
    case CharonRegionEllipse:
        return charon_region_ellipse(halfWidth, halfHeight, point) <= 1.0f;
    case CharonRegionRectangle:
        return fabsf((float)point.x) < halfWidth && fabsf((float)point.y) < halfHeight;
    }
    return NO;
}

static BOOL charon_region_not_outside(int shape, float halfWidth, float halfHeight, CGPoint point)
{
    switch (shape) {
    case CharonRegionInfinite:
        return YES;
    case CharonRegionEllipse:
        return !(charon_region_ellipse(halfWidth, halfHeight, point) > 1.0f);
    case CharonRegionRectangle:
        return !(fabsf((float)point.x) > halfWidth) && !(fabsf((float)point.y) > halfHeight);
    }
    return NO;
}

static BOOL charon_region_contains(const CharonRegion *region, CGPoint point)
{
    BOOL first = charon_region_inside(region->shape, region->halfWidth, region->halfHeight, point) != region->exclusive;
    switch (region->operation) {
    case CharonRegionUnion:
        return first || charon_region_inside(region->secondShape, region->secondHalfWidth, region->secondHalfHeight, point);
    case CharonRegionMinus:
        return first && !charon_region_inside(region->secondShape, region->secondHalfWidth, region->secondHalfHeight, point);
    case CharonRegionIntersection:
        return first && charon_region_not_outside(region->secondShape, region->secondHalfWidth, region->secondHalfHeight, point);
    }
    return first;
}

@implementation UIRegion {
    BOOL _defined;
    CharonRegion _region;
}

+ (UIRegion *)infiniteRegion
{
    static UIRegion *infinite;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        infinite = [[UIRegion alloc] charon_initWithRegion:(CharonRegion){.shape = CharonRegionInfinite}];
    });
    return infinite;
}

- (instancetype)charon_initWithRegion:(CharonRegion)region __attribute__((objc_method_family(init)))
{
    if (!(self = [super init]))
        return nil;
    _defined = YES;
    _region = region;
    return self;
}

- (instancetype)initWithRadius:(CGFloat)radius
{
    float extent = (float)(radius * (double)CharonRegionPTM) * CharonRegionInversePTM;
    return [self charon_initWithRegion:(CharonRegion){.shape = CharonRegionEllipse, .halfWidth = extent, .halfHeight = extent}];
}

- (instancetype)initWithSize:(CGSize)size
{
    float halfWidth = (float)(size.width * (double)CharonRegionPTM * 0.5 * (double)CharonRegionInversePTM);
    float halfHeight = (float)(size.height * (double)CharonRegionPTM * 0.5 * (double)CharonRegionInversePTM);
    return [self charon_initWithRegion:(CharonRegion){.shape = CharonRegionRectangle, .halfWidth = halfWidth, .halfHeight = halfHeight}];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIRegion *copy = [[[self class] allocWithZone:zone] init];
    copy->_defined = _defined;
    copy->_region = _region;
    return copy;
}

- (instancetype)inverseRegion
{
    UIRegion *inverse = [self copy];
    if (_defined)
        inverse->_region.exclusive = !_region.exclusive;
    return inverse;
}

- (instancetype)charon_regionBy:(int)operation inverted:(int)inverted with:(UIRegion *)other selector:(SEL)selector
{
    if (!other || !other->_defined)
        [NSException raise:NSInvalidArgumentException format:@"-[%@ %@]: %@ is not a region with a shape", [self class], NSStringFromSelector(selector), other];
    UIRegion *result = [self copy];
    if (!_defined)
        return result;
    result->_region.secondShape = other->_region.shape;
    result->_region.secondHalfWidth = other->_region.halfWidth;
    result->_region.secondHalfHeight = other->_region.halfHeight;
    result->_region.operation = other->_region.exclusive ? inverted : operation;
    return result;
}

- (instancetype)regionByUnionWithRegion:(UIRegion *)region
{
    return [self charon_regionBy:CharonRegionUnion inverted:CharonRegionMinus with:region selector:_cmd];
}

- (instancetype)regionByDifferenceFromRegion:(UIRegion *)region
{
    return [self charon_regionBy:CharonRegionMinus inverted:CharonRegionUnion with:region selector:_cmd];
}

- (instancetype)regionByIntersectionWithRegion:(UIRegion *)region
{
    return [self charon_regionBy:CharonRegionIntersection inverted:CharonRegionIntersection with:region selector:_cmd];
}

- (BOOL)containsPoint:(CGPoint)point
{
    return _defined && charon_region_contains(&_region, point);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_defined forKey:@"UIRegionDefined"];
    [coder encodeInt:_region.shape forKey:@"UIRegionShape"];
    [coder encodeBool:_region.exclusive forKey:@"UIRegionExclusive"];
    [coder encodeFloat:_region.halfWidth forKey:@"UIRegionHalfWidth"];
    [coder encodeFloat:_region.halfHeight forKey:@"UIRegionHalfHeight"];
    [coder encodeInt:_region.operation forKey:@"UIRegionOperation"];
    [coder encodeInt:_region.secondShape forKey:@"UIRegionSecondShape"];
    [coder encodeFloat:_region.secondHalfWidth forKey:@"UIRegionSecondHalfWidth"];
    [coder encodeFloat:_region.secondHalfHeight forKey:@"UIRegionSecondHalfHeight"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super init]))
        return nil;
    _defined = [coder decodeBoolForKey:@"UIRegionDefined"];
    _region.shape = [coder decodeIntForKey:@"UIRegionShape"];
    _region.exclusive = [coder decodeBoolForKey:@"UIRegionExclusive"];
    _region.halfWidth = [coder decodeFloatForKey:@"UIRegionHalfWidth"];
    _region.halfHeight = [coder decodeFloatForKey:@"UIRegionHalfHeight"];
    _region.operation = [coder decodeIntForKey:@"UIRegionOperation"];
    _region.secondShape = [coder decodeIntForKey:@"UIRegionSecondShape"];
    _region.secondHalfWidth = [coder decodeFloatForKey:@"UIRegionSecondHalfWidth"];
    _region.secondHalfHeight = [coder decodeFloatForKey:@"UIRegionSecondHalfHeight"];
    return self;
}

@end
