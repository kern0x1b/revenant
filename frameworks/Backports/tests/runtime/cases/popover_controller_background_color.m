#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@interface RevenantOwnPopoverBackground : UIPopoverBackgroundView
@end

@implementation RevenantOwnPopoverBackground
+ (CGFloat)arrowBase
{
    return 20;
}
+ (CGFloat)arrowHeight
{
    return 10;
}
+ (UIEdgeInsets)contentViewInsets
{
    return UIEdgeInsetsZero;
}
- (CGFloat)arrowOffset
{
    return 0;
}
- (void)setArrowOffset:(CGFloat)offset
{
}
- (UIPopoverArrowDirection)arrowDirection
{
    return UIPopoverArrowDirectionUp;
}
- (void)setArrowDirection:(UIPopoverArrowDirection)direction
{
}
@end

static NSString *revenant_drawn(Class background, UIColor *color)
{
    UIPopoverBackgroundView *view = [[background alloc] initWithFrame:CGRectMake(0, 0, 320, 253)];
    view.arrowDirection = UIPopoverArrowDirectionUp;
    view.arrowOffset = 0;
    [view layoutIfNeeded];
    for (CALayer *layer in view.layer.sublayers) {
        if (![layer isKindOfClass:[CAShapeLayer class]])
            continue;
        CAShapeLayer *shape = (CAShapeLayer *)layer;
        if (!CGColorEqualToColor(shape.fillColor, color.CGColor))
            return @"filled with another color";
        CGRect box = CGPathGetPathBoundingBox(shape.path);
        if (fabs(box.origin.x) > 0.5 || fabs(box.origin.y) > 0.5 || fabs(box.size.width - 320) > 0.5 || fabs(box.size.height - 253) > 0.5)
            return [NSString stringWithFormat:@"covers %@", NSStringFromCGRect(box)];
        return @"drawn";
    }
    return @"no shape";
}

REVENANT_CASE(popover_controller_background_color)
{
    UIPopoverController *popover = [UIPopoverController alloc];
    CFBridgingRetain(popover);
    UIColor *red = [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
    UIColor *blue = [UIColor colorWithRed:0 green:0 blue:1 alpha:1];

    popover.backgroundColor = red;
    Class first = popover.popoverBackgroundViewClass;
    revenant_expect_true(@"the color is read back", [popover.backgroundColor isEqual:red] != (BOOL)negative,
                         [popover.backgroundColor description] ?: @"nil");
    revenant_expect_true(@"the popover takes a background view class",
                         (first && [first isSubclassOfClass:[UIPopoverBackgroundView class]]) != (BOOL)negative,
                         first ? NSStringFromClass(first) : @"nil");
    revenant_expect_true(@"the class gives the arrow a size",
                         (first && [first arrowBase] > 0 && [first arrowHeight] > 0) != (BOOL)negative, @"no arrow");
    NSString *drawn = first ? revenant_drawn(first, red) : @"no class";
    revenant_expect_true(@"its view fills the body and the arrow with the color", [drawn isEqualToString:@"drawn"] != (BOOL)negative, drawn);

    popover.backgroundColor = blue;
    Class second = popover.popoverBackgroundViewClass;
    NSString *again = second ? revenant_drawn(second, blue) : @"no class";
    revenant_expect_true(@"another color is drawn by another class",
                         (second != first && [again isEqualToString:@"drawn"]) != (BOOL)negative, again);
    popover.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
    revenant_expect_true(@"an equal color takes the same class again", (popover.popoverBackgroundViewClass == first) != (BOOL)negative,
                         NSStringFromClass(popover.popoverBackgroundViewClass) ?: @"nil");

    popover.backgroundColor = nil;
    revenant_expect_true(@"nil brings back the default background",
                         (!popover.backgroundColor && !popover.popoverBackgroundViewClass) != (BOOL)negative,
                         NSStringFromClass(popover.popoverBackgroundViewClass) ?: @"nil");

    popover.popoverBackgroundViewClass = [RevenantOwnPopoverBackground class];
    popover.backgroundColor = red;
    revenant_expect_true(@"an application's own background view class stays",
                         (popover.popoverBackgroundViewClass == [RevenantOwnPopoverBackground class] && [popover.backgroundColor isEqual:red]) != (BOOL)negative,
                         NSStringFromClass(popover.popoverBackgroundViewClass) ?: @"nil");
}
