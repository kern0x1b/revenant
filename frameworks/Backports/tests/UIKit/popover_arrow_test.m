#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "RevenantPopoverArrow.h"
#import "check.h"

static void expect_shape(const char *name, int direction, CGFloat offset, CGRect body, CGPoint tip, CGPoint first, CGPoint second)
{
    RevenantPopoverShape shape = RevenantPopoverShapeMake(CGRectMake(0, 0, 320, 240), direction, offset, 36, 12);
    BOOL same = CGRectEqualToRect(shape.body, body) && CGPointEqualToPoint(shape.tip, tip) && CGPointEqualToPoint(shape.first, first) && CGPointEqualToPoint(shape.second, second);
    revenant_check(same, name, [NSString stringWithFormat:@"body %@ tip %@ base %@ %@", NSStringFromRect(NSRectFromCGRect(shape.body)),
        NSStringFromPoint(NSPointFromCGPoint(shape.tip)), NSStringFromPoint(NSPointFromCGPoint(shape.first)), NSStringFromPoint(NSPointFromCGPoint(shape.second))]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        expect_shape("an arrow that points up takes the top edge", 1, 0, CGRectMake(0, revenant_negative ? 0 : 12, 320, 228),
                     CGPointMake(160, 0), CGPointMake(142, 12), CGPointMake(178, 12));
        expect_shape("an arrow that points down takes the bottom edge", 2, 40, CGRectMake(0, 0, 320, 228),
                     CGPointMake(200, 240), CGPointMake(182, 228), CGPointMake(218, 228));
        expect_shape("an arrow that points left takes the left edge", 4, -30, CGRectMake(12, 0, 308, 240),
                     CGPointMake(0, 90), CGPointMake(12, 72), CGPointMake(12, 108));
        expect_shape("an arrow that points right takes the right edge", 8, 25, CGRectMake(0, 0, 308, 240),
                     CGPointMake(320, 145), CGPointMake(308, 127), CGPointMake(308, 163));
        expect_shape("no arrow leaves the whole of the bounds", 0, 10, CGRectMake(0, 0, 320, 240),
                     CGPointZero, CGPointZero, CGPointZero);
    }
    return revenant_finish();
}
