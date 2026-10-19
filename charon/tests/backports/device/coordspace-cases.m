#import "coordspace-cases.h"

static NSString *point(CGPoint p)
{
    return [NSString stringWithFormat:@"%g,%g", p.x, p.y];
}

static NSString *rect(CGRect r)
{
    return [NSString stringWithFormat:@"%g,%g,%g,%g", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

void coordspace_run(UIWindow *window, CoordSpaceRecorder record)
{
    UIViewController *root = [[UIViewController alloc] init];
    window.rootViewController = root;
    [window layoutIfNeeded];
    UIView *outer = [[UIView alloc] initWithFrame:CGRectMake(20, 30, 200, 300)];
    UIView *inner = [[UIView alloc] initWithFrame:CGRectMake(15, 25, 100, 100)];
    UIView *sibling = [[UIView alloc] initWithFrame:CGRectMake(150, 200, 60, 60)];
    [window addSubview:outer];
    [outer addSubview:inner];
    [window addSubview:sibling];
    UIScreen *screen = window.screen;
    id<UICoordinateSpace> rotating = screen.coordinateSpace;
    id<UICoordinateSpace> fixed = screen.fixedCoordinateSpace;
    record(@"conforms view", [NSString stringWithFormat:@"%d", [inner conformsToProtocol:@protocol(UICoordinateSpace)]]);
    record(@"conforms window", [NSString stringWithFormat:@"%d", [window conformsToProtocol:@protocol(UICoordinateSpace)]]);
    record(@"conforms rotating", [NSString stringWithFormat:@"%d", [(id)rotating conformsToProtocol:@protocol(UICoordinateSpace)]]);
    record(@"conforms fixed", [NSString stringWithFormat:@"%d", [(id)fixed conformsToProtocol:@protocol(UICoordinateSpace)]]);
    record(@"rotating is stable", [NSString stringWithFormat:@"%d", screen.coordinateSpace == rotating]);
    record(@"fixed is stable", [NSString stringWithFormat:@"%d", screen.fixedCoordinateSpace == fixed]);
    record(@"rotating differs from fixed", [NSString stringWithFormat:@"%d", (id)rotating != (id)fixed]);
    record(@"view bounds", rect(inner.bounds));
    record(@"view bounds space", rect([(id<UICoordinateSpace>)inner bounds]));
    record(@"fixed bounds size", [NSString stringWithFormat:@"%d", CGSizeEqualToSize(fixed.bounds.size, screen.bounds.size)]);
    record(@"fixed bounds origin", point(fixed.bounds.origin));

    record(@"inner point to outer", point([inner convertPoint:CGPointMake(5, 6) toCoordinateSpace:outer]));
    record(@"inner point from outer", point([inner convertPoint:CGPointMake(30, 40) fromCoordinateSpace:outer]));
    record(@"inner rect to sibling", rect([inner convertRect:CGRectMake(1, 2, 30, 40) toCoordinateSpace:sibling]));
    record(@"inner rect from sibling", rect([inner convertRect:CGRectMake(1, 2, 30, 40) fromCoordinateSpace:sibling]));
    record(@"inner point to window", point([inner convertPoint:CGPointMake(5, 6) toCoordinateSpace:window]));
    record(@"inner point from window", point([inner convertPoint:CGPointMake(50, 60) fromCoordinateSpace:window]));
    record(@"inner point to itself", point([inner convertPoint:CGPointMake(7, 8) toCoordinateSpace:inner]));

    CGPoint viaRotating = [inner convertPoint:CGPointMake(5, 6) toCoordinateSpace:rotating];
    CGPoint viaWindow = [inner convertPoint:CGPointMake(5, 6) toView:nil];
    record(@"to rotating is the window's", [NSString stringWithFormat:@"%d", fabs(viaRotating.x - viaWindow.x) < 0.01 && fabs(viaRotating.y - viaWindow.y) < 0.01]);
    CGPoint viaFixed = [inner convertPoint:CGPointMake(5, 6) toCoordinateSpace:fixed];
    CGPoint screenPoint = [window convertPoint:viaWindow toWindow:nil];
    record(@"to fixed is the screen's", [NSString stringWithFormat:@"%d", fabs(viaFixed.x - screenPoint.x) < 0.01 && fabs(viaFixed.y - screenPoint.y) < 0.01]);
    CGPoint back = [inner convertPoint:viaRotating fromCoordinateSpace:rotating];
    record(@"rotating round trip", point(back));
    CGPoint backFixed = [inner convertPoint:viaFixed fromCoordinateSpace:fixed];
    record(@"fixed round trip", point(backFixed));
    CGRect frame = [inner convertRect:inner.bounds toCoordinateSpace:rotating];
    CGRect viaViews = [inner convertRect:inner.bounds toView:nil];
    record(@"rect to rotating is the window's", [NSString stringWithFormat:@"%d", CGRectEqualToRect(CGRectIntegral(frame), CGRectIntegral(viaViews))]);
    CGRect roundRect = [inner convertRect:frame fromCoordinateSpace:rotating];
    record(@"rect round trip", rect(roundRect));
    CGPoint screenToRotating = [rotating convertPoint:CGPointMake(10, 20) fromCoordinateSpace:fixed];
    CGPoint rotatingToFixed = [rotating convertPoint:screenToRotating toCoordinateSpace:fixed];
    record(@"screen spaces round trip", point(rotatingToFixed));
    record(@"space to space in portrait", point(screenToRotating));
    record(@"screen space to view", point([rotating convertPoint:CGPointMake(50, 60) toCoordinateSpace:inner]));
    record(@"screen space rect to view", rect([rotating convertRect:CGRectMake(50, 60, 10, 10) toCoordinateSpace:inner]));
    record(@"view rect to screen space size", [NSString stringWithFormat:@"%g,%g", [inner convertRect:CGRectMake(0, 0, 40, 50) toCoordinateSpace:fixed].size.width, [inner convertRect:CGRectMake(0, 0, 40, 50) toCoordinateSpace:fixed].size.height]);
}
