#import "CharonDynamics.h"

// Gravity is the world's, not a force on each item: the behavior writes its vector, times 10 m/s^2
// (1000 pt/s^2), as the world gravity, and marks its items' bodies affected by it. So an animator has
// one gravity, the last one written, and removing any gravity behavior sets it to zero (7.0).
@implementation UIGravityBehavior {
    CGVector _gravity;
}

- (instancetype)init
{
    return [self initWithItems:@[]];
}

- (instancetype)initWithItems:(NSArray *)items
{
    if (!(self = [super charon_initPrimitive:YES]))
        return nil;
    [[self charon_items] addObjectsFromArray:items ?: @[]];
    _gravity = CGVectorMake(0, 1);
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ {%g, %g} ", [super description], _gravity.dx, _gravity.dy];
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self charon_items]];
}

- (void)charon_addItem:(id<UIDynamicItem>)item
{
    CharonDynamicsBody *body = [[self charon_context] charon_registerBodyForItem:item shape:CharonDynamicsShapeBox];
    body.usesPreciseCollisionDetection = YES;
    body.affectedByGravity = YES;
    body.resting = NO;
}

- (void)addItem:(id<UIDynamicItem>)item
{
    if ([[self charon_items] containsObject:item])
        return;
    [[self charon_items] addObject:item];
    if ([self charon_isAssociated]) {
        [self charon_addItem:item];
        [[self charon_context] charon_tickle];
    }
}

- (void)removeItem:(id<UIDynamicItem>)item
{
    if (![[self charon_items] containsObject:item])
        return;
    [[self charon_context] charon_unregisterBodyForItem:item action:^(CharonDynamicsBody *body) {
        body.affectedByGravity = NO;
    }];
    [[self charon_items] removeObject:item];
}

- (void)charon_associate
{
    [super charon_associate];
    [[self charon_context] charon_setWorldGravity:_gravity];
    for (id<UIDynamicItem> item in [self charon_items])
        [self charon_addItem:item];
}

- (void)charon_dissociate
{
    UIDynamicAnimator *context = [self charon_context];
    for (id<UIDynamicItem> item in [self charon_items]) {
        [context charon_unregisterBodyForItem:item action:^(CharonDynamicsBody *body) {
            body.affectedByGravity = NO;
        }];
    }
    [context charon_setWorldGravity:CGVectorMake(0, 0)];
    [super charon_dissociate];
}

- (CGVector)gravityDirection
{
    return _gravity;
}

- (void)setGravityDirection:(CGVector)direction
{
    [self charon_setGravity:direction];
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

// 7.0 takes the sine and cosine in float.
- (void)setAngle:(CGFloat)angle magnitude:(CGFloat)magnitude
{
    float sine = sinf((float)angle), cosine = cosf((float)angle);
    [self charon_setGravity:CGVectorMake((double)cosine * magnitude, (double)sine * magnitude)];
}

- (void)charon_setGravity:(CGVector)gravity
{
    if (gravity.dx == _gravity.dx && gravity.dy == _gravity.dy)
        return;
    _gravity = gravity;
    if ([self charon_isAssociated])
        [[self charon_context] charon_setWorldGravity:gravity];
    [self charon_changedParameterForBody:nil];
}

@end
