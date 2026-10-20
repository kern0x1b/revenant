#import "RevenantDynamics.h"

@implementation UIGravityBehavior {
    CGVector _gravity;
}

- (instancetype)init
{
    return [self initWithItems:@[]];
}

- (instancetype)initWithItems:(NSArray *)items
{
    if (!(self = [super revenant_initPrimitive:YES]))
        return nil;
    [[self revenant_items] addObjectsFromArray:items ?: @[]];
    _gravity = CGVectorMake(0, 1);
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ {%g, %g} ", [super description], _gravity.dx, _gravity.dy];
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self revenant_items]];
}

- (void)revenant_addItem:(id<UIDynamicItem>)item
{
    RevenantDynamicsBody *body = [[self revenant_context] revenant_registerBodyForItem:item shape:RevenantDynamicsShapeBox];
    body.usesPreciseCollisionDetection = YES;
    body.affectedByGravity = YES;
    body.resting = NO;
}

- (void)addItem:(id<UIDynamicItem>)item
{
    if ([[self revenant_items] containsObject:item])
        return;
    [[self revenant_items] addObject:item];
    if ([self revenant_isAssociated]) {
        [self revenant_addItem:item];
        [[self revenant_context] revenant_tickle];
    }
}

- (void)removeItem:(id<UIDynamicItem>)item
{
    if (![[self revenant_items] containsObject:item])
        return;
    [[self revenant_context] revenant_unregisterBodyForItem:item action:^(RevenantDynamicsBody *body) {
        body.affectedByGravity = NO;
    }];
    [[self revenant_items] removeObject:item];
}

- (void)revenant_associate
{
    [super revenant_associate];
    [[self revenant_context] revenant_setWorldGravity:_gravity];
    for (id<UIDynamicItem> item in [self revenant_items])
        [self revenant_addItem:item];
}

- (void)revenant_dissociate
{
    UIDynamicAnimator *context = [self revenant_context];
    for (id<UIDynamicItem> item in [self revenant_items]) {
        [context revenant_unregisterBodyForItem:item action:^(RevenantDynamicsBody *body) {
            body.affectedByGravity = NO;
        }];
    }
    [context revenant_setWorldGravity:CGVectorMake(0, 0)];
    [super revenant_dissociate];
}

- (CGVector)gravityDirection
{
    return _gravity;
}

- (void)setGravityDirection:(CGVector)direction
{
    [self revenant_setGravity:direction];
}

- (CGFloat)angle
{
    return atan2(_gravity.dy, _gravity.dx);
}

- (CGFloat)magnitude
{
    return sqrt(_gravity.dx * _gravity.dx + _gravity.dy * _gravity.dy);
}

- (void)setAngle:(CGFloat)angle
{
    [self setAngle:angle magnitude:self.magnitude];
}

- (void)setMagnitude:(CGFloat)magnitude
{
    [self setAngle:self.angle magnitude:magnitude];
}

- (void)setAngle:(CGFloat)angle magnitude:(CGFloat)magnitude
{
    float sine = sinf((float)angle), cosine = cosf((float)angle);
    [self revenant_setGravity:CGVectorMake((double)cosine * magnitude, (double)sine * magnitude)];
}

- (void)revenant_setGravity:(CGVector)gravity
{
    if (gravity.dx == _gravity.dx && gravity.dy == _gravity.dy)
        return;
    _gravity = gravity;
    if ([self revenant_isAssociated])
        [[self revenant_context] revenant_setWorldGravity:gravity];
    [self revenant_changedParameterForBody:nil];
}

@end
