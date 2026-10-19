#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// A filter shape is the rectangle a filter is told to work over. It is not the image and not a mask: it
// is the region, and every operation on it is the same operation on that rectangle - two shapes
// intersect where their rectangles do, two shapes take a union where their rectangles do, an inset
// moves each edge in by its own amount, and a transform either bounds the transformed shape or cuts it
// back to its interior, which is the one question the interior flag answers.

@implementation CIFilterShape {
    CGRect _extent;
}

@synthesize extent = _extent;

// The extent is the whole pixels the rect covers, measured against the system over seven rects: the
// origin goes down and the far side goes up, which is CGRectIntegral's own rule. Given 0.25 0.5 1.5
// 1.75 the system answers 0 0 2 3; given -1.5 -2.5 0.5 0.5 it answers -2 -3 1 1; given 1.5 1.5 2.5 2.5
// it answers 1 1 3 3. The port stored the caller's rect verbatim, so it answered 3.5 6.25 where the
// system answers 4 7, and every operation on the shape then started from a different rect than the
// system's did. CGRectStandardize first, so a rect given with a negative side is the rect it names.
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

// The header's own spelling and its own types: an inset of whole numbers, and a capital Y. Written
// with a lower-case y and a floating point amount it is a different selector, and a caller naming the
// header's one would not find it.
- (CIFilterShape *)insetByX:(int)dx Y:(int)dy
{
    return [CIFilterShape shapeWithRect:CGRectInset(_extent, dx, dy)];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[CIFilterShape allocWithZone:zone] initWithRect:_extent];
}

// A transform moves the shape. With the interior asked for, what comes back is the part of the
// transformed shape that is still inside the shape it started as, which for a translation is the
// overlap and for a transform that turns the shape inside out is nothing; without it, what comes back
// is the box the four transformed corners reach, which for a rotation is bigger than the shape.
- (CIFilterShape *)transformBy:(CGAffineTransform)transform interior:(BOOL)interior
{
    CGRect bounds = CGRectApplyAffineTransform(_extent, transform);
    if (!interior)
        return [CIFilterShape shapeWithRect:bounds];
    return [CIFilterShape shapeWithRect:CGRectIntersection(_extent, bounds)];
}

@end
