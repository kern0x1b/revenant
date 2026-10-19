#import <UIKit/UIKit.h>
#import <CoreGraphics/CGPath.h>

// The three that arrived in iOS 7.0, in their own file because an object carries the API of one
// release. The reasons each answers as it does, and the measurements behind them, are in
// facts/UIKit/AccessibilityQueries.md.

// The transform from one view to another is read off three converted points rather than assumed to
// be a scale and a shift, so a rotated or flipped view is converted as it really is; the window's
// own space into the screen's is read the same way, which is what -convertRect:toWindow:nil means.
static CGAffineTransform CharonTransform(UIView *from, UIView *to)
{
    CGPoint origin = [from convertPoint:CGPointZero toView:to];
    CGPoint alongX = [from convertPoint:CGPointMake(1, 0) toView:to];
    CGPoint alongY = [from convertPoint:CGPointMake(0, 1) toView:to];
    return CGAffineTransformMake(alongX.x - origin.x, alongX.y - origin.y,
                                 alongY.x - origin.x, alongY.y - origin.y,
                                 origin.x, origin.y);
}

static CGAffineTransform CharonWindowToScreen(UIWindow *window)
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
    CGAffineTransform toScreen = CGAffineTransformConcat(CharonWindowToScreen(window), CharonTransform(view, window));
    // iOS has no -bezierPathByApplyingTransform:, so the transform is applied to the path's CGPath
    // with CGPathCreateMutableCopyByTransformingPath and the result is read back into a UIBezierPath,
    // which is the only way to transform one here.
    CGMutablePathRef moved = CGPathCreateMutableCopyByTransformingPath(path.CGPath, &toScreen);
    if (!moved)
        return path;
    UIBezierPath *result = [UIBezierPath bezierPathWithCGPath:moved];
    CGPathRelease(moved);
    return result;
}

void UIAccessibilityRequestGuidedAccessSession(BOOL enable, void (^handler)(BOOL success))
{
    // A guided access session is a state the system puts the whole device into, and only the
    // system's own guided access starts one; an application asking is answered as an application
    // that did not get one. The handler is called, so a caller waiting on one is not left waiting.
    if (handler)
        handler(NO);
}

UIGuidedAccessRestrictionState UIGuidedAccessRestrictionStateForIdentifier(NSString *identifier)
{
    // Whether one named restriction allows what it guards. The release keeps its restrictions where
    // an application cannot read them and exposes no query for one, so the answer is that the
    // restriction allows, which is the header's own initial state for every restriction and what a
    // device outside guided access answers.
    (void)identifier;
    return UIGuidedAccessRestrictionStateAllow;
}
