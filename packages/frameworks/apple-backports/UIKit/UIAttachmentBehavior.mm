#import "RevenantDynamics.h"

typedef NS_ENUM(NSInteger, RevenantAttachmentKind) {
    RevenantAttachmentDistance,
    RevenantAttachmentFixed,
    RevenantAttachmentPin,
    RevenantAttachmentSliding,
    RevenantAttachmentLimit,
};

enum {
    RevenantDampingSet = 1 << 0,
    RevenantFrequencySet = 1 << 1,
    RevenantLengthSet = 1 << 2,
    RevenantRevolute = 1 << 3,
    RevenantRangeSet = 1 << 4,
    RevenantFrictionTorqueSet = 1 << 5,
};

@implementation UIAttachmentBehavior {
    RevenantAttachmentKind _kind;
    NSInteger _type;
    UIAttachmentBehaviorType _attachedBehaviorType;
    CGPoint _anchorPoint;
    CGPoint _anchorPointA;
    CGPoint _anchorPointB;
    CGVector _axis;
    CGFloat _damping;
    CGFloat _frequency;
    CGFloat _length;
    CGFloat _frictionTorque;
    UIFloatRange _attachmentRange;
    NSUInteger _stateFlags;
    RevenantDynamicsBody *_anchorBody;
    b2Joint *_joint;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"init is undefined for objects of type %@", [self class]];
    return nil;
}

- (instancetype)revenant_initWithItems:(NSArray *)items kind:(RevenantAttachmentKind)kind type:(NSInteger)type __attribute__((objc_method_family(init)))
{
    if (!(self = [super revenant_initPrimitive:YES]))
        return nil;
    [[self revenant_items] addObjectsFromArray:items];
    _kind = kind;
    _type = type;
    return self;
}

- (instancetype)initWithItem:(id<UIDynamicItem>)item attachedToAnchor:(CGPoint)point
{
    return [self initWithItem:item offsetFromCenter:UIOffsetMake(0, 0) attachedToAnchor:point];
}

- (instancetype)initWithItem:(id<UIDynamicItem>)item offsetFromCenter:(UIOffset)offset attachedToAnchor:(CGPoint)point
{
    if (!(self = [self revenant_initWithItems:@[item] kind:RevenantAttachmentDistance type:1]))
        return nil;
    _anchorPoint = point;
    _anchorPointA = CGPointMake(offset.horizontal, offset.vertical);
    return self;
}

- (instancetype)initWithItem:(id<UIDynamicItem>)item attachedToItem:(id<UIDynamicItem>)other
{
    return [self initWithItem:item offsetFromCenter:UIOffsetMake(0, 0) attachedToItem:other offsetFromCenter:UIOffsetMake(0, 0)];
}

- (instancetype)initWithItem:(id<UIDynamicItem>)item offsetFromCenter:(UIOffset)offset attachedToItem:(id<UIDynamicItem>)other offsetFromCenter:(UIOffset)otherOffset
{
    if (!(self = [self revenant_initWithItems:@[item, other] kind:RevenantAttachmentDistance type:0]))
        return nil;
    _anchorPointA = CGPointMake(offset.horizontal, offset.vertical);
    _anchorPointB = CGPointMake(otherOffset.horizontal, otherOffset.vertical);
    return self;
}

+ (instancetype)fixedAttachmentWithItem:(id<UIDynamicItem>)item attachedToItem:(id<UIDynamicItem>)other attachmentAnchor:(CGPoint)point
{
    UIAttachmentBehavior *behavior = [[self alloc] revenant_initWithItems:@[item, other] kind:RevenantAttachmentFixed type:0];
    behavior->_anchorPoint = point;
    return behavior;
}

+ (instancetype)pinAttachmentWithItem:(id<UIDynamicItem>)item attachedToItem:(id<UIDynamicItem>)other attachmentAnchor:(CGPoint)point
{
    UIAttachmentBehavior *behavior = [[self alloc] revenant_initWithItems:@[item, other] kind:RevenantAttachmentPin type:0];
    behavior->_anchorPoint = point;
    behavior->_attachmentRange = (UIFloatRange){-INFINITY, INFINITY};
    return behavior;
}

+ (instancetype)slidingAttachmentWithItem:(id<UIDynamicItem>)item attachedToItem:(id<UIDynamicItem>)other attachmentAnchor:(CGPoint)point axisOfTranslation:(CGVector)axis
{
    UIAttachmentBehavior *behavior = [[self alloc] revenant_initWithItems:@[item, other] kind:RevenantAttachmentSliding type:0];
    behavior->_anchorPoint = point;
    behavior->_axis = axis;
    behavior->_attachmentRange = (UIFloatRange){-INFINITY, INFINITY};
    return behavior;
}

+ (instancetype)slidingAttachmentWithItem:(id<UIDynamicItem>)item attachmentAnchor:(CGPoint)point axisOfTranslation:(CGVector)axis
{
    UIAttachmentBehavior *behavior = [[self alloc] revenant_initWithItems:@[item] kind:RevenantAttachmentSliding type:1];
    behavior->_anchorPoint = point;
    behavior->_axis = axis;
    behavior->_attachmentRange = (UIFloatRange){-INFINITY, INFINITY};
    return behavior;
}

+ (instancetype)limitAttachmentWithItem:(id<UIDynamicItem>)item offsetFromCenter:(UIOffset)offset attachedToItem:(id<UIDynamicItem>)other offsetFromCenter:(UIOffset)otherOffset
{
    UIAttachmentBehavior *behavior = [[self alloc] revenant_initWithItems:@[item, other] kind:RevenantAttachmentLimit type:0];
    behavior->_anchorPointA = CGPointMake(offset.horizontal, offset.vertical);
    behavior->_anchorPointB = CGPointMake(otherOffset.horizontal, otherOffset.vertical);
    CGPoint first = item.center, second = other.center;
    behavior->_length = hypot(second.x - first.x, second.y - first.y);
    return behavior;
}

- (NSString *)description
{
    NSArray *items = [self revenant_items];
    NSMutableString *description = [NSMutableString stringWithString:[super description]];
    [description appendFormat:@" %@ <-", items.firstObject];
    if (_stateFlags & (RevenantDampingSet | RevenantFrequencySet)) {
        [description appendString:@"("];
        if (_stateFlags & RevenantDampingSet)
            [description appendFormat:@"D:%f", _damping];
        [description appendString:@" "];
        if (_stateFlags & RevenantFrequencySet)
            [description appendFormat:@"F:%f", _frequency];
        [description appendString:@")"];
    }
    [description appendFormat:@"-> %@", _type == 1 ? NSStringFromCGPoint(self.anchorPoint) : items.lastObject];
    return description;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self revenant_items]];
}

- (UIAttachmentBehaviorType)attachedBehaviorType
{
    return _attachedBehaviorType;
}

- (BOOL)revenant_distanceJoint
{
    return _joint && _kind == RevenantAttachmentDistance && !(_stateFlags & RevenantRevolute);
}

- (CGPoint)anchorPoint
{
    return _anchorBody ? _anchorBody.position : _anchorPoint;
}

- (void)setAnchorPoint:(CGPoint)point
{
    if (CGPointEqualToPoint(point, self.anchorPoint))
        return;
    _anchorPoint = point;
    _anchorBody.position = point;
    [self revenant_changedParameter];
}

- (CGFloat)length
{
    if (_joint && _kind == RevenantAttachmentLimit)
        return (double)(REVENANT_DYNAMICS_PTM * static_cast<b2RopeJoint *>(_joint)->GetMaxLength());
    return [self revenant_distanceJoint] ? (double)(REVENANT_DYNAMICS_PTM * static_cast<b2DistanceJoint *>(_joint)->GetLength()) : _length;
}

- (void)setLength:(CGFloat)length
{
    CGFloat old = self.length;
    if (length == old) {
        if (!_joint)
            _stateFlags |= RevenantLengthSet;
        return;
    }
    _length = length;
    _stateFlags |= RevenantLengthSet;
    if (_kind != RevenantAttachmentDistance)
        return;
    if (length == 0 || old == 0) {
        [self revenant_reevaluateJoint];
        [self revenant_changedParameter];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1), dispatch_get_main_queue(), ^{
        if ([self revenant_distanceJoint])
            static_cast<b2DistanceJoint *>(self->_joint)->SetLength((float)(self->_length * REVENANT_DYNAMICS_INVERSE_PTM));
        [self revenant_changedParameter];
    });
}

- (CGFloat)damping
{
    return [self revenant_distanceJoint] ? static_cast<b2DistanceJoint *>(_joint)->GetDampingRatio() : _damping;
}

- (void)setDamping:(CGFloat)damping
{
    if (damping == self.damping)
        return;
    _damping = damping;
    _stateFlags |= RevenantDampingSet;
    if ([self revenant_distanceJoint])
        static_cast<b2DistanceJoint *>(_joint)->SetDampingRatio((float)damping);
    [self revenant_changedParameter];
}

- (CGFloat)frequency
{
    return [self revenant_distanceJoint] ? static_cast<b2DistanceJoint *>(_joint)->GetFrequency() : _frequency;
}

- (void)setFrequency:(CGFloat)frequency
{
    if (frequency == _frequency)
        return;
    CGFloat old = _frequency;
    _frequency = frequency;
    _stateFlags |= RevenantFrequencySet;
    if (frequency == 0 || old == 0)
        [self revenant_reevaluateJoint];
    else if ([self revenant_distanceJoint])
        static_cast<b2DistanceJoint *>(_joint)->SetFrequency((float)frequency);
    [self revenant_changedParameter];
}

- (CGFloat)frictionTorque
{
    return _frictionTorque;
}

- (void)setFrictionTorque:(CGFloat)torque
{
    if (_kind != RevenantAttachmentPin || torque == _frictionTorque)
        return;
    _frictionTorque = torque;
    _stateFlags |= RevenantFrictionTorqueSet;
    [self revenant_applyPinAndSlider];
    [self revenant_changedParameter];
}

- (UIFloatRange)attachmentRange
{
    return _attachmentRange;
}

- (void)setAttachmentRange:(UIFloatRange)range
{
    if (_kind != RevenantAttachmentPin && _kind != RevenantAttachmentSliding)
        return;
    _attachmentRange = range;
    _stateFlags |= RevenantRangeSet;
    [self revenant_applyPinAndSlider];
    [self revenant_changedParameter];
}

- (void)revenant_applyPinAndSlider
{
    if (!_joint)
        return;
    if (_kind == RevenantAttachmentPin) {
        b2RevoluteJoint *pin = static_cast<b2RevoluteJoint *>(_joint);
        if (_stateFlags & RevenantRangeSet) {
            pin->EnableLimit(true);
            pin->SetLimits((float)_attachmentRange.minimum, (float)_attachmentRange.maximum);
        }
        if (_stateFlags & RevenantFrictionTorqueSet) {
            pin->EnableMotor(true);
            pin->SetMotorSpeed(0);
            pin->SetMaxMotorTorque((float)_frictionTorque);
        }
    } else if (_kind == RevenantAttachmentSliding && (_stateFlags & RevenantRangeSet)) {
        b2PrismaticJoint *slider = static_cast<b2PrismaticJoint *>(_joint);
        slider->EnableLimit(true);
        slider->SetLimits((float)(_attachmentRange.minimum * REVENANT_DYNAMICS_INVERSE_PTM), (float)(_attachmentRange.maximum * REVENANT_DYNAMICS_INVERSE_PTM));
    }
}

- (void)revenant_changedParameter
{
    UIDynamicAnimator *context = [self revenant_context];
    NSArray *items = [self revenant_items];
    [context revenant_bodyForItem:items.firstObject].resting = NO;
    if (_anchorBody)
        _anchorBody.resting = NO;
    else if (items.count > 1)
        [context revenant_bodyForItem:items[1]].resting = NO;
    [context revenant_tickle];
}

- (void)revenant_associate
{
    [super revenant_associate];
    UIDynamicAnimator *context = [self revenant_context];
    for (id<UIDynamicItem> item in [self revenant_items])
        [context revenant_registerBodyForItem:item shape:RevenantDynamicsShapeBox];
    if (_type == 1)
        _anchorBody = [context revenant_anchorBodyAtPoint:_anchorPoint];
    [self revenant_reevaluateJoint];
}

- (void)revenant_destroyJoint
{
    if (_joint)
        [[self revenant_context] revenant_world]->DestroyJoint(_joint);
    _joint = NULL;
}

- (void)revenant_reevaluateJoint
{
    UIDynamicAnimator *context = [self revenant_context];
    b2World *world = [context revenant_world];
    if (!world || ![self revenant_isAssociated])
        return;
    NSArray *items = [self revenant_items];
    b2Body *bodyA = [context revenant_bodyForItem:items.firstObject].b2Body;
    b2Body *bodyB = _anchorBody ? _anchorBody.b2Body : [context revenant_bodyForItem:items.lastObject].b2Body;
    [self revenant_destroyJoint];
    _stateFlags &= ~RevenantRevolute;
    b2Vec2 anchor = revenant_metres(_anchorPoint);
    switch (_kind) {
    case RevenantAttachmentDistance: {
        b2DistanceJointDef definition;
        definition.Initialize(bodyA, bodyB, bodyA->GetWorldPoint(revenant_metres(_anchorPointA)), bodyB->GetWorldPoint(revenant_metres(_anchorPointB)));
        definition.collideConnected = _type == 0;
        definition.frequencyHz = (_stateFlags & RevenantFrequencySet) ? (float)_frequency : 0.0f;
        definition.dampingRatio = (_stateFlags & RevenantDampingSet) ? (float)_damping : 0.0f;
        _joint = world->CreateJoint(&definition);
        b2DistanceJoint *distance = static_cast<b2DistanceJoint *>(_joint);
        if (_stateFlags & RevenantLengthSet)
            distance->SetLength((float)(_length * REVENANT_DYNAMICS_INVERSE_PTM));
        if (REVENANT_DYNAMICS_PTM * distance->GetLength() < 1.0f && _frequency == 0 && _type == 1 && !(_stateFlags & RevenantLengthSet)) {
            [self revenant_destroyJoint];
            b2RevoluteJointDef pin;
            pin.Initialize(bodyA, bodyB, bodyB->GetPosition());
            _joint = world->CreateJoint(&pin);
            _stateFlags |= RevenantRevolute;
        }
        break;
    }
    case RevenantAttachmentFixed: {
        b2WeldJointDef definition;
        definition.Initialize(bodyA, bodyB, anchor);
        _joint = world->CreateJoint(&definition);
        break;
    }
    case RevenantAttachmentPin: {
        b2RevoluteJointDef definition;
        definition.Initialize(bodyA, bodyB, anchor);
        _joint = world->CreateJoint(&definition);
        break;
    }
    case RevenantAttachmentSliding: {
        b2Vec2 axis((float)_axis.dx, (float)_axis.dy);
        axis.Normalize();
        b2PrismaticJointDef definition;
        definition.Initialize(bodyA, bodyB, anchor, axis);
        _joint = world->CreateJoint(&definition);
        break;
    }
    case RevenantAttachmentLimit: {
        CGPoint centreA = revenant_points(bodyA->GetPosition()), centreB = revenant_points(bodyB->GetPosition());
        b2Vec2 worldA = revenant_metres(CGPointMake(centreA.x - _anchorPointA.x, centreA.y - _anchorPointA.y));
        b2Vec2 worldB = revenant_metres(CGPointMake(centreB.x - _anchorPointB.x, centreB.y - _anchorPointB.y));
        b2RopeJointDef definition;
        definition.bodyA = bodyA;
        definition.bodyB = bodyB;
        definition.localAnchorA = bodyA->GetLocalPoint(worldA);
        definition.localAnchorB = bodyB->GetLocalPoint(worldB);
        definition.maxLength = b2Distance(worldA, worldB);
        _joint = world->CreateJoint(&definition);
        break;
    }
    }
    [self revenant_applyPinAndSlider];
}

- (void)revenant_dissociate
{
    UIDynamicAnimator *context = [self revenant_context];
    [self revenant_destroyJoint];
    if (_anchorBody) {
        [context revenant_removeBody:_anchorBody];
        _anchorBody = nil;
    }
    for (id<UIDynamicItem> item in [self revenant_items])
        [context revenant_unregisterBodyForItem:item action:nil];
    [super revenant_dissociate];
}

@end
