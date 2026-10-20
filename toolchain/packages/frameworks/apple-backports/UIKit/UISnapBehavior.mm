#import "RevenantDynamics.h"

@implementation UISnapBehavior {
    CGPoint _anchorPoint;
    CGFloat _damping;
    CGFloat _distance;
    CGFloat _frequency;
    RevenantDynamicsBody *_anchorBody;
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
    if (!(self = [super revenant_initPrimitive:YES]))
        return nil;
    if (item)
        [[self revenant_items] addObject:item];
    _anchorPoint = point;
    _damping = 0.5;
    _distance = 50.0;
    _frequency = 4.0;
    return self;
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithString:[super description]];
    [description appendFormat:@" %@ <-", [self revenant_items].firstObject];
    [description appendFormat:@"-> %@", NSStringFromCGPoint(_anchorPoint)];
    return description;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self revenant_items]];
}

- (CGFloat)damping
{
    return _damping;
}

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
    [self revenant_changedParameterForBody:[[self revenant_context] revenant_bodyForItem:[self revenant_items].firstObject]];
}

- (void)revenant_associate
{
    [super revenant_associate];
    UIDynamicAnimator *context = [self revenant_context];
    id<UIDynamicItem> item = [self revenant_items].firstObject;
    RevenantDynamicsBody *itemBody = [context revenant_registerBodyForItem:item shape:RevenantDynamicsShapeBox];
    _anchorBody = [context revenant_anchorBodyAtPoint:_anchorPoint];
    CGSize size = item.bounds.size;
    CGFloat halfWidth = size.width / 2, halfHeight = size.height / 2, distance = _distance;
    struct { CGPoint item[4], anchor[4]; } anchors = {
        {{-halfWidth, -halfHeight}, {-halfWidth, -halfHeight}, {halfWidth, halfHeight}, {halfWidth, halfHeight}},
        {{-halfWidth - distance, -halfHeight}, {-halfWidth, -halfHeight - distance}, {halfWidth + distance, halfHeight}, {halfWidth, halfHeight + distance}},
    };
    RevenantDynamicsBody *anchorBody = _anchorBody;
    CGFloat damping = _damping, frequency = _frequency;
    [context revenant_runBlockPostSolverIfNeeded:^{
        if (!self->_anchorBody || self->_anchorBody != anchorBody)
            return;
        b2World *world = [context revenant_world];
        b2Body *bodyA = itemBody.b2Body, *bodyB = anchorBody.b2Body;
        for (int index = 0; index < 4; index++) {
            b2DistanceJointDef definition;
            definition.Initialize(bodyA, bodyB, bodyA->GetWorldPoint(revenant_metres(anchors.item[index])), bodyB->GetWorldPoint(revenant_metres(anchors.anchor[index])));
            definition.frequencyHz = (float)frequency;
            definition.dampingRatio = (float)damping;
            self->_joints[index] = world->CreateJoint(&definition);
        }
        self->_jointCount = 4;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
            if (self->_anchorBody != anchorBody)
                return;
            for (int index = 0; index < self->_jointCount; index++)
                static_cast<b2DistanceJoint *>(self->_joints[index])->SetLength((float)(distance * REVENANT_DYNAMICS_INVERSE_PTM));
        });
    }];
}

- (void)revenant_dissociate
{
    UIDynamicAnimator *context = [self revenant_context];
    b2World *world = [context revenant_world];
    for (int index = 0; index < _jointCount; index++)
        world->DestroyJoint(_joints[index]);
    _jointCount = 0;
    [context revenant_removeBody:_anchorBody];
    _anchorBody = nil;
    [context revenant_unregisterBodyForItem:[self revenant_items].firstObject action:nil];
    [super revenant_dissociate];
}

@end
