#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@implementation CIFilterShape {
    CGRect _extent;
}

@synthesize extent = _extent;

- (instancetype)initWithRect:(CGRect)rect
{
    if ((self = [super init]))
        _extent = CGRectIntegral(CGRectStandardize(rect));
    return self;
}

+ (instancetype)shapeWithRect:(CGRect)rect
{
    return [[CIFilterShape alloc] initWithRect:rect];
}

- (CIFilterShape *)intersectWith:(CIFilterShape *)otherFilterShape
{
    return [CIFilterShape shapeWithRect:CGRectIntersection(_extent, otherFilterShape.extent)];
}

- (CIFilterShape *)intersectWithRect:(CGRect)rect
{
    return [CIFilterShape shapeWithRect:CGRectIntersection(_extent, rect)];
}

- (CIFilterShape *)unionWith:(CIFilterShape *)otherFilterShape
{
    return [CIFilterShape shapeWithRect:CGRectUnion(_extent, otherFilterShape.extent)];
}

- (CIFilterShape *)unionWithRect:(CGRect)rect
{
    return [CIFilterShape shapeWithRect:CGRectUnion(_extent, rect)];
}

- (CIFilterShape *)insetByX:(int)dx Y:(int)dy
{
    return [CIFilterShape shapeWithRect:CGRectInset(_extent, dx, dy)];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[CIFilterShape allocWithZone:zone] initWithRect:_extent];
}

- (CIFilterShape *)transformBy:(CGAffineTransform)transform interior:(BOOL)interior
{
    CGRect bounds = CGRectApplyAffineTransform(_extent, transform);
    if (!interior)
        return [CIFilterShape shapeWithRect:bounds];
    return [CIFilterShape shapeWithRect:CGRectIntersection(_extent, bounds)];
}

@end
