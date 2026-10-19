#import <UIKit/UIKit.h>
#import <CoreGraphics/CGPath.h>

static CGAffineTransform RevenantTransform(UIView *from, UIView *to)
{
    CGPoint origin = [from convertPoint:CGPointZero toView:to];
    CGPoint alongX = [from convertPoint:CGPointMake(1, 0) toView:to];
    CGPoint alongY = [from convertPoint:CGPointMake(0, 1) toView:to];
    return CGAffineTransformMake(alongX.x - origin.x, alongX.y - origin.y,
                                 alongY.x - origin.x, alongY.y - origin.y,
                                 origin.x, origin.y);
}

static CGAffineTransform RevenantWindowToScreen(UIWindow *window)
{
    CGPoint origin = [window convertPoint:CGPointZero toView:nil];
    CGPoint alongX = [window convertPoint:CGPointMake(1, 0) toView:nil];
    CGPoint alongY = [window convertPoint:CGPointMake(0, 1) toView:nil];
    return CGAffineTransformMake(alongX.x - origin.x, alongX.y - origin.y,
                                 alongY.x - origin.x, alongY.y - origin.y,
                                 origin.x, origin.y);
}

UIBezierPath *UIAccessibilityConvertPathToScreenCoordinates(UIBezierPath *path, UIView *view)
{
    if (!path || !view)
        return nil;
    UIWindow *window = view.window;
    if (!window)
        return path;
    CGAffineTransform toScreen = CGAffineTransformConcat(RevenantWindowToScreen(window), RevenantTransform(view, window));
    CGMutablePathRef moved = CGPathCreateMutableCopyByTransformingPath(path.CGPath, &toScreen);
    if (!moved)
        return path;
    UIBezierPath *result = [UIBezierPath bezierPathWithCGPath:moved];
    CGPathRelease(moved);
    return result;
}

void UIAccessibilityRequestGuidedAccessSession(BOOL enable, void (^handler)(BOOL success))
{
    if (handler)
        handler(NO);
}

UIGuidedAccessRestrictionState UIGuidedAccessRestrictionStateForIdentifier(NSString *identifier)
{
    (void)identifier;
    return UIGuidedAccessRestrictionStateAllow;
}
