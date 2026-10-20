#import <UIKit/UIKit.h>

@implementation UITrackingLayoutGuide {
    NSMutableDictionary *_nearConstraints;
    NSMutableDictionary *_awayConstraints;
}

- (NSMutableDictionary *)revenant_near
{
    if (!_nearConstraints)
        _nearConstraints = [NSMutableDictionary dictionary];
    return _nearConstraints;
}

- (NSMutableDictionary *)revenant_away
{
    if (!_awayConstraints)
        _awayConstraints = [NSMutableDictionary dictionary];
    return _awayConstraints;
}

- (void)setConstraints:(NSArray<NSLayoutConstraint *> *)trackingConstraints activeWhenNearEdge:(NSDirectionalRectEdge)edge
{
    [[self revenant_near] setObject:trackingConstraints forKey:@(edge)];
}

- (NSArray<NSLayoutConstraint *> *)constraintsActiveWhenNearEdge:(NSDirectionalRectEdge)edge
{
    return [self revenant_near][@(edge)] ?: @[];
}

- (void)setConstraints:(NSArray<NSLayoutConstraint *> *)trackingConstraints activeWhenAwayFromEdge:(NSDirectionalRectEdge)edge
{
    [[self revenant_away] setObject:trackingConstraints forKey:@(edge)];
}

- (NSArray<NSLayoutConstraint *> *)constraintsActiveWhenAwayFromEdge:(NSDirectionalRectEdge)edge
{
    return [self revenant_away][@(edge)] ?: @[];
}

- (void)removeAllTrackedConstraints
{
    [_nearConstraints removeAllObjects];
    [_awayConstraints removeAllObjects];
}

@end
