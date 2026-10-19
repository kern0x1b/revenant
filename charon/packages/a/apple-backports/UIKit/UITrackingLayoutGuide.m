#import <UIKit/UIKit.h>

// UITrackingLayoutGuide, iOS 15. A layout guide that holds two sets of constraints, one for each side of its owning view it may be near or
// away from. The sets are stored per edge: a set on one edge leaves the other alone, removeAllTrackedConstraints clears both, a read of an
// edge with nothing set answers an empty array, and a nil set raises NSInvalidArgumentException, as the host does (measured by
// tests/backports/host/layout-guides). The constraints are not yet activated as the guide moves near or away from an edge: the host's rule
// for that did not reduce to a position test in the measurement, so it is owed (facts/UIKit/UIKeyboardLayoutGuide.md).
@implementation UITrackingLayoutGuide {
    NSMutableDictionary *_nearConstraints;
    NSMutableDictionary *_awayConstraints;
}

- (NSMutableDictionary *)charon_near
{
    if (!_nearConstraints)
        _nearConstraints = [NSMutableDictionary dictionary];
    return _nearConstraints;
}

- (NSMutableDictionary *)charon_away
{
    if (!_awayConstraints)
        _awayConstraints = [NSMutableDictionary dictionary];
    return _awayConstraints;
}

- (void)setConstraints:(NSArray<NSLayoutConstraint *> *)trackingConstraints activeWhenNearEdge:(NSDirectionalRectEdge)edge
{
    [[self charon_near] setObject:trackingConstraints forKey:@(edge)];
}

- (NSArray<NSLayoutConstraint *> *)constraintsActiveWhenNearEdge:(NSDirectionalRectEdge)edge
{
    return [self charon_near][@(edge)] ?: @[];
}

- (void)setConstraints:(NSArray<NSLayoutConstraint *> *)trackingConstraints activeWhenAwayFromEdge:(NSDirectionalRectEdge)edge
{
    [[self charon_away] setObject:trackingConstraints forKey:@(edge)];
}

- (NSArray<NSLayoutConstraint *> *)constraintsActiveWhenAwayFromEdge:(NSDirectionalRectEdge)edge
{
    return [self charon_away][@(edge)] ?: @[];
}

- (void)removeAllTrackedConstraints
{
    [_nearConstraints removeAllObjects];
    [_awayConstraints removeAllObjects];
}

@end
