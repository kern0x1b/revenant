#import "RevenantDynamics.h"

@implementation UIPushBehavior {
    UIPushBehaviorMode _mode;
    BOOL _active;
    CGFloat _angle;
    CGFloat _magnitude;
    CGVector _forceVector;
    NSMutableDictionary *_targetPoints;
}

- (instancetype)init
{
    return [self initWithItems:@[] mode:UIPushBehaviorModeContinuous];
}

- (instancetype)initWithItems:(NSArray *)items mode:(UIPushBehaviorMode)mode
{
    if (!(self = [super revenant_initPrimitive:YES]))
        return nil;
    _mode = mode;
    _active = YES;
    [[self revenant_items] addObjectsFromArray:items ?: @[]];
    return self;
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithString:[super description]];
    [description appendFormat:@" {%f, %f} - <%f,%f> ", _forceVector.dx, _forceVector.dy, _magnitude, _angle];
    for (id item in [self revenant_items])
        [description appendFormat:@"(%@ -> %@)", item, NSStringFromCGPoint([self revenant_offsetForItem:item])];
    return description;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self revenant_items]];
}

- (UIPushBehaviorMode)mode
{
    return _mode;
}

- (BOOL)active
{
    return _active;
}

- (void)setActive:(BOOL)active
{
    if (active == _active)
        return;
    _active = active;
    [[self revenant_context] revenant_tickle];
}

- (CGFloat)angle
{
    return _angle;
}

- (CGFloat)magnitude
{
    return _magnitude;
}

- (CGVector)pushDirection
{
    return _forceVector;
}

- (void)setPushDirection:(CGVector)direction
{
    if (direction.dx == _forceVector.dx && direction.dy == _forceVector.dy)
        return;
    _forceVector = direction;
    _angle = atan2(direction.dy, direction.dx);
    _magnitude = sqrt(direction.dx * direction.dx + direction.dy * direction.dy);
    [self revenant_changedParameterForBody:nil];
}

- (void)setAngle:(CGFloat)angle
{
    [self setAngle:angle magnitude:_magnitude];
}

- (void)setMagnitude:(CGFloat)magnitude
{
    [self setAngle:_angle magnitude:magnitude];
}

- (void)setAngle:(CGFloat)angle magnitude:(CGFloat)magnitude
{
    if (angle == _angle && magnitude == _magnitude)
        return;
    _angle = angle;
    _magnitude = magnitude;
    float sine = sinf((float)angle), cosine = cosf((float)angle);
    _forceVector = CGVectorMake(magnitude * (double)cosine, magnitude * (double)sine);
    [self revenant_changedParameterForBody:nil];
}

- (CGPoint)revenant_offsetForItem:(id<UIDynamicItem>)item
{
    NSValue *offset = _targetPoints[[NSValue valueWithPointer:(__bridge const void *)item]];
    return offset ? [offset CGPointValue] : CGPointZero;
}

- (UIOffset)targetOffsetFromCenterForItem:(id<UIDynamicItem>)item
{
    CGPoint offset = [self revenant_offsetForItem:item];
    return UIOffsetMake(offset.x, offset.y);
}

- (void)setTargetOffsetFromCenter:(UIOffset)offset forItem:(id<UIDynamicItem>)item
{
    if (!item)
        return;
    CGPoint current = [self revenant_offsetForItem:item];
    if (current.x == offset.horizontal && current.y == offset.vertical)
        return;
    id key = [NSValue valueWithPointer:(__bridge const void *)item];
    if (offset.horizontal == 0 && offset.vertical == 0) {
        [_targetPoints removeObjectForKey:key];
        if (_targetPoints.count == 0)
            _targetPoints = nil;
    } else {
        _targetPoints = _targetPoints ?: [NSMutableDictionary new];
        _targetPoints[key] = [NSValue valueWithCGPoint:CGPointMake(offset.horizontal, offset.vertical)];
    }
    [self revenant_changedParameterForBody:nil];
}

- (void)addItem:(id<UIDynamicItem>)item
{
    if ([[self revenant_items] containsObject:item])
        return;
    if ([self revenant_isAssociated])
        [[self revenant_context] revenant_registerBodyForItem:item shape:RevenantDynamicsShapeBox].usesPreciseCollisionDetection = YES;
    [[self revenant_items] addObject:item];
}

- (void)removeItem:(id<UIDynamicItem>)item
{
    if (![[self revenant_items] containsObject:item])
        return;
    [[self revenant_context] revenant_unregisterBodyForItem:item action:nil];
    [_targetPoints removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)item]];
    if (_targetPoints.count == 0)
        _targetPoints = nil;
    [[self revenant_items] removeObject:item];
}

- (void)revenant_associate
{
    [super revenant_associate];
    for (id<UIDynamicItem> item in [self revenant_items])
        [[self revenant_context] revenant_registerBodyForItem:item shape:RevenantDynamicsShapeBox].usesPreciseCollisionDetection = YES;
}

- (void)revenant_dissociate
{
    for (id<UIDynamicItem> item in [self revenant_items])
        [[self revenant_context] revenant_unregisterBodyForItem:item action:nil];
    [super revenant_dissociate];
}

- (void)revenant_step
{
    if (!_active)
        return;
    UIDynamicAnimator *context = [self revenant_context];
    for (id<UIDynamicItem> item in [self revenant_items]) {
        RevenantDynamicsBody *body = [context revenant_bodyForItem:item];
        NSValue *offset = _targetPoints[[NSValue valueWithPointer:(__bridge const void *)item]];
        if (offset) {
            CGPoint center = item.center, shift = [offset CGPointValue];
            CGPoint point = CGPointMake(center.x + shift.x, center.y + shift.y);
            if (_mode == UIPushBehaviorModeInstantaneous)
                [body applyImpulse:_forceVector atPoint:point];
            else
                [body applyForce:_forceVector atPoint:point];
        } else if (_mode == UIPushBehaviorModeInstantaneous) {
            [body applyImpulse:_forceVector];
        } else {
            [body applyForce:_forceVector];
        }
    }
    if (_mode == UIPushBehaviorModeInstantaneous)
        _active = NO;
}

@end
