#import "CharonDynamics.h"

// A snap is four springs from the item's corners to a static anchor body at the snap point, the item's
// size, turned to 0 (7.0): two from the top left corner, 50 pt out to the left and upwards, two from
// the bottom right one, out to the right and downwards. They are built at the distance the corners are
// now, and given their rest length of 50 pt on the next turn of the main queue, as 7.0 does.
@implementation UISnapBehavior {
    CGPoint _anchorPoint;
    CGFloat _damping;
    CGFloat _distance;
    CGFloat _frequency;
    CharonDynamicsBody *_anchorBody;
    b2Joint *_joints[4];
    int _jointCount;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"init is undefined for objects of type %@", [self class]];
    return nil;
}

- (instancetype)initWithItem:(id<UIDynamicItem>)item snapToPoint:(CGPoint)point
{
    if (!(self = [super charon_initPrimitive:YES]))
        return nil;
    if (item)
        [[self charon_items] addObject:item];
    _anchorPoint = point;
    _damping = 0.5;
    _distance = 50.0;
    _frequency = 4.0;
    return self;
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithString:[super description]];
    [description appendFormat:@" %@ <-", [self charon_items].firstObject];
    [description appendFormat:@"-> %@", NSStringFromCGPoint(_anchorPoint)];
    return description;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self charon_items]];
}

- (CGFloat)damping
{
    return _damping;
}

// The damping is read when the springs are built: a live snap keeps the one it had (7.0).
- (void)setDamping:(CGFloat)damping
{
    _damping = damping;
}

- (CGPoint)snapPoint
{
    return _anchorPoint;
}

- (void)setSnapPoint:(CGPoint)point
{
    if (CGPointEqualToPoint(point, _anchorPoint))
        return;
    _anchorPoint = point;
    if (!_anchorBody)
        return;
    _anchorBody.position = point;
    [self charon_changedParameterForBody:[[self charon_context] charon_bodyForItem:[self charon_items].firstObject]];
}

- (void)charon_associate
{
    [super charon_associate];
    UIDynamicAnimator *context = [self charon_context];
    id<UIDynamicItem> item = [self charon_items].firstObject;
    CharonDynamicsBody *itemBody = [context charon_registerBodyForItem:item shape:CharonDynamicsShapeBox];
    _anchorBody = [context charon_anchorBodyAtPoint:_anchorPoint];
    CGSize size = item.bounds.size;
    CGFloat halfWidth = size.width / 2, halfHeight = size.height / 2, distance = _distance;
    struct { CGPoint item[4], anchor[4]; } anchors = {
        {{-halfWidth, -halfHeight}, {-halfWidth, -halfHeight}, {halfWidth, halfHeight}, {halfWidth, halfHeight}},
        {{-halfWidth - distance, -halfHeight}, {-halfWidth, -halfHeight - distance}, {halfWidth + distance, halfHeight}, {halfWidth, halfHeight + distance}},
    };
    CharonDynamicsBody *anchorBody = _anchorBody;
    CGFloat damping = _damping, frequency = _frequency;
    [context charon_runBlockPostSolverIfNeeded:^{
        if (!self->_anchorBody || self->_anchorBody != anchorBody)
            return;
        b2World *world = [context charon_world];
        b2Body *bodyA = itemBody.b2Body, *bodyB = anchorBody.b2Body;
        for (int index = 0; index < 4; index++) {
            b2DistanceJointDef definition;
            definition.Initialize(bodyA, bodyB, bodyA->GetWorldPoint(charon_metres(anchors.item[index])), bodyB->GetWorldPoint(charon_metres(anchors.anchor[index])));
            definition.frequencyHz = (float)frequency;
            definition.dampingRatio = (float)damping;
            self->_joints[index] = world->CreateJoint(&definition);
        }
        self->_jointCount = 4;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
            if (self->_anchorBody != anchorBody)
                return;
            for (int index = 0; index < self->_jointCount; index++)
                static_cast<b2DistanceJoint *>(self->_joints[index])->SetLength((float)(distance * CHARON_DYNAMICS_INVERSE_PTM));
        });
    }];
}

- (void)charon_dissociate
{
    UIDynamicAnimator *context = [self charon_context];
    b2World *world = [context charon_world];
    for (int index = 0; index < _jointCount; index++)
        world->DestroyJoint(_joints[index]);
    _jointCount = 0;
    [context charon_removeBody:_anchorBody];
    _anchorBody = nil;
    [context charon_unregisterBodyForItem:[self charon_items].firstObject action:nil];
    [super charon_dissociate];
}

@end
