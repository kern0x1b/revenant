#import <UIKit/UIKit.h>
#include <math.h>

// The domain of a UIFieldBehavior (9.0). 9.0's UIRegion holds a PKRegion, and a PKRegion is not a tree:
// it is one primitive shape with an inversion flag, plus at most ONE second shape and the operation that
// joins them. An operation copies the receiver and puts the other region's primitive shape into the second
// slot, replacing whatever the receiver held there, and drops the other region's own second shape; the
// inversion flag belongs to the first shape only. So (a | b) & c is a & c, and the inverse of a | b is
// (not a) | b. This is the host's arithmetic, copied as it is (facts/UIKit/UIFieldBehavior.md §10.6; host
// listings of -[PKRegion containsPoint:], -regionByUnionWithRegion:, -regionByDifferenceFromRegion:,
// -regionByIntersectionWithRegion:, -inverseRegion, -initWithRadius:, -initWithSize:, +infiniteRegion).
// A region made with -init holds no PKRegion on the host and contains nothing.

// PKGet_PTM_RATIO and PKGet_INV_PTM_RATIO: 100 points per metre, as float (facts/UIKit/UIFieldBehavior.md §10.1).
// The host's global ratio is SpriteKit's 150 until the process makes its first UIDynamicAnimator, which sets 100
// for good (measured: PKGet_PTM_RATIO before and after), so a region made before any animator differs from this in
// the last bit of its half extent. The backport cannot know whether a 7.0 animator of the release was ever made,
// and uses the ratio Dynamics runs with.
static const float CharonRegionPTM = 100.0f;
static const float CharonRegionInversePTM = 0.01f;

// PKRegion's _shape: 1 everything, 2 an ellipse of the half extents, 3 a centred rectangle of the half
// extents. 4, a path, is made only by the private -initWithPath: and is not carried.
enum {
    CharonRegionInfinite = 1,
    CharonRegionEllipse = 2,
    CharonRegionRectangle = 3,
};

// PKRegion's _regionOp: 0 the first shape alone, 1 first or second, 2 first and not second, 3 first and
// second. A union with an inverted region is 2, a difference from an inverted region is 1 (host listings).
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

// (x/hw)^2 + (y/hh)^2 as the host computes it: each quotient in double, rounded to float, 0 for a half
// extent that is not positive (so a circle of radius <= 0 contains every point), the sum fused.
static float charon_region_ellipse(float halfWidth, float halfHeight, CGPoint point)
{
    float x = halfWidth > 0 ? (float)(point.x / (double)halfWidth) : 0;
    float y = halfHeight > 0 ? (float)(point.y / (double)halfHeight) : 0;
    return fmaf(x, x, y * y);
}

// The strict test the host uses for the first shape and inside a union or a minus: NaN is outside.
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

// The test inside an intersection is written the other way round in the host listing ("not outside"),
// so it takes the edge of a rectangle and a NaN in: a circle of 50 and a rectangle of 100x50 intersect in
// (50,0) and (0,25), which the rectangle alone does not contain.
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
    // NO for a region made with -init: the host's holds no PKRegion.
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

// UIKit passes (float)(radius * PTM) and PhysicsKit keeps that times INV_PTM, in float, as both half extents.
- (instancetype)initWithRadius:(CGFloat)radius
{
    float extent = (float)(radius * (double)CharonRegionPTM) * CharonRegionInversePTM;
    return [self charon_initWithRegion:(CharonRegion){.shape = CharonRegionEllipse, .halfWidth = extent, .halfHeight = extent}];
}

// UIKit and PhysicsKit each halve the size only for a program linked against the iOS 11 SDK or later
// (dyld_program_sdk_at_least in UIKit, PKGetLinkedOnOrAfter in PhysicsKit), and exactly one of them halves
// it either way, so the half extent is the same for every program: ((size * PTM) * 0.5) * INV_PTM, in
// double, rounded to float.
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

// The host reads the other region's PKRegion without a check: a nil region or one made with -init
// crashes it with a bad access. Here that is an exception instead, with the reason.
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

// Unlike the other two, the host's intersection ignores the other region's inversion.
- (instancetype)regionByIntersectionWithRegion:(UIRegion *)region
{
    return [self charon_regionBy:CharonRegionIntersection inverted:CharonRegionIntersection with:region selector:_cmd];
}

- (BOOL)containsPoint:(CGPoint)point
{
    return _defined && charon_region_contains(&_region, point);
}

// The host archives its PKRegion under "_region", a class this release does not have; the same state is
// written here as plain numbers, so an archive round-trips within the backport only.
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
