#import "CharonDynamics.h"

// 7.0's attachment is a distance joint between the item and a static anchor body or a second item,
// with its anchors in the items' own axes; a rigid anchor attachment shorter than 1 pt, whose length
// was never set, becomes a pin at the anchor instead. The joint is built at the distance the anchors
// are at, and a length set afterwards takes over on the next turn of the main queue (7.0; the host
// applies it at once). The 9.0 factories build a weld, a pin, a slider or a rope, measured on the host.
typedef NS_ENUM(NSInteger, CharonAttachmentKind) {
    CharonAttachmentDistance,
    CharonAttachmentFixed,
    CharonAttachmentPin,
    CharonAttachmentSliding,
    CharonAttachmentLimit,
};

enum {
    CharonDampingSet = 1 << 0,
    CharonFrequencySet = 1 << 1,
    CharonLengthSet = 1 << 2,
    CharonRevolute = 1 << 3,
    CharonRangeSet = 1 << 4,
    CharonFrictionTorqueSet = 1 << 5,
};

@implementation UIAttachmentBehavior {
    CharonAttachmentKind _kind;
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
    CharonDynamicsBody *_anchorBody;
    b2Joint *_joint;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"init is undefined for objects of type %@", [self class]];
    return nil;
}

- (instancetype)charon_initWithItems:(NSArray *)items kind:(CharonAttachmentKind)kind type:(NSInteger)type __attribute__((objc_method_family(init)))
{
    if (!(self = [super charon_initPrimitive:YES]))
        return nil;
    [[self charon_items] addObjectsFromArray:items];
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
    if (!(self = [self charon_initWithItems:@[item] kind:CharonAttachmentDistance type:1]))
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
    if (!(self = [self charon_initWithItems:@[item, other] kind:CharonAttachmentDistance type:0]))
        return nil;
    _anchorPointA = CGPointMake(offset.horizontal, offset.vertical);
    _anchorPointB = CGPointMake(otherOffset.horizontal, otherOffset.vertical);
    return self;
}

+ (instancetype)fixedAttachmentWithItem:(id<UIDynamicItem>)item attachedToItem:(id<UIDynamicItem>)other attachmentAnchor:(CGPoint)point
{
    UIAttachmentBehavior *behavior = [[self alloc] charon_initWithItems:@[item, other] kind:CharonAttachmentFixed type:0];
    behavior->_anchorPoint = point;
    return behavior;
}

+ (instancetype)pinAttachmentWithItem:(id<UIDynamicItem>)item attachedToItem:(id<UIDynamicItem>)other attachmentAnchor:(CGPoint)point
{
    UIAttachmentBehavior *behavior = [[self alloc] charon_initWithItems:@[item, other] kind:CharonAttachmentPin type:0];
    behavior->_anchorPoint = point;
    behavior->_attachmentRange = (UIFloatRange){-INFINITY, INFINITY};
    return behavior;
}

+ (instancetype)slidingAttachmentWithItem:(id<UIDynamicItem>)item attachedToItem:(id<UIDynamicItem>)other attachmentAnchor:(CGPoint)point axisOfTranslation:(CGVector)axis
{
    UIAttachmentBehavior *behavior = [[self alloc] charon_initWithItems:@[item, other] kind:CharonAttachmentSliding type:0];
    behavior->_anchorPoint = point;
    behavior->_axis = axis;
    behavior->_attachmentRange = (UIFloatRange){-INFINITY, INFINITY};
    return behavior;
}

+ (instancetype)slidingAttachmentWithItem:(id<UIDynamicItem>)item attachmentAnchor:(CGPoint)point axisOfTranslation:(CGVector)axis
{
    UIAttachmentBehavior *behavior = [[self alloc] charon_initWithItems:@[item] kind:CharonAttachmentSliding type:1];
    behavior->_anchorPoint = point;
    behavior->_axis = axis;
    behavior->_attachmentRange = (UIFloatRange){-INFINITY, INFINITY};
    // The private type is 1, the public attachedBehaviorType stays Items as for every other initializer: the host
    // answers 0 for this factory (tests/backports/host/dynamics structure T12), where the specification had read 1
    // (facts/UIKit/UIDynamicAnimator.md §6.4).
    return behavior;
}

// The rope's limit is the distance of its anchors when the joint is made, not at the factory: the factory keeps the
// centres' distance as the length it answers until then (facts/UIKit/UIDynamicAnimator.md M4). The offsets are the
// host's: negated, in the reference view's axes (facts/UIKit/UIDynamicAnimator.md §6.4).
+ (instancetype)limitAttachmentWithItem:(id<UIDynamicItem>)item offsetFromCenter:(UIOffset)offset attachedToItem:(id<UIDynamicItem>)other offsetFromCenter:(UIOffset)otherOffset
{
    UIAttachmentBehavior *behavior = [[self alloc] charon_initWithItems:@[item, other] kind:CharonAttachmentLimit type:0];
    behavior->_anchorPointA = CGPointMake(offset.horizontal, offset.vertical);
    behavior->_anchorPointB = CGPointMake(otherOffset.horizontal, otherOffset.vertical);
    CGPoint first = item.center, second = other.center;
    behavior->_length = hypot(second.x - first.x, second.y - first.y);
    return behavior;
}

- (NSString *)description
{
    NSArray *items = [self charon_items];
    NSMutableString *description = [NSMutableString stringWithString:[super description]];
    [description appendFormat:@" %@ <-", items.firstObject];
    if (_stateFlags & (CharonDampingSet | CharonFrequencySet)) {
        [description appendString:@"("];
        if (_stateFlags & CharonDampingSet)
            [description appendFormat:@"D:%f", _damping];
        [description appendString:@" "];
        if (_stateFlags & CharonFrequencySet)
            [description appendFormat:@"F:%f", _frequency];
        [description appendString:@")"];
    }
    [description appendFormat:@"-> %@", _type == 1 ? NSStringFromCGPoint(self.anchorPoint) : items.lastObject];
    return description;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self charon_items]];
}

- (UIAttachmentBehaviorType)attachedBehaviorType
{
    return _attachedBehaviorType;
}

- (BOOL)charon_distanceJoint
{
    return _joint && _kind == CharonAttachmentDistance && !(_stateFlags & CharonRevolute);
}

- (CGPoint)anchorPoint
{
    return _anchorBody ? _anchorBody.position : _anchorPoint;
}

// The anchor body moves; the joint and its rest length stay.
- (void)setAnchorPoint:(CGPoint)point
{
    if (CGPointEqualToPoint(point, self.anchorPoint))
        return;
    _anchorPoint = point;
    _anchorBody.position = point;
    [self charon_changedParameter];
}

- (CGFloat)length
{
    if (_joint && _kind == CharonAttachmentLimit)
        return (double)(CHARON_DYNAMICS_PTM * static_cast<b2RopeJoint *>(_joint)->GetMaxLength());
    return [self charon_distanceJoint] ? (double)(CHARON_DYNAMICS_PTM * static_cast<b2DistanceJoint *>(_joint)->GetLength()) : _length;
}

- (void)setLength:(CGFloat)length
{
    CGFloat old = self.length;
    if (length == old) {
        if (!_joint)
            _stateFlags |= CharonLengthSet;
        return;
    }
    _length = length;
    _stateFlags |= CharonLengthSet;
    if (_kind != CharonAttachmentDistance)
        return;
    if (length == 0 || old == 0) {
        [self charon_reevaluateJoint];
        [self charon_changedParameter];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1), dispatch_get_main_queue(), ^{
        if ([self charon_distanceJoint])
            static_cast<b2DistanceJoint *>(self->_joint)->SetLength((float)(self->_length * CHARON_DYNAMICS_INVERSE_PTM));
        [self charon_changedParameter];
    });
}

- (CGFloat)damping
{
    return [self charon_distanceJoint] ? static_cast<b2DistanceJoint *>(_joint)->GetDampingRatio() : _damping;
}

- (void)setDamping:(CGFloat)damping
{
    if (damping == self.damping)
        return;
    _damping = damping;
    _stateFlags |= CharonDampingSet;
    if ([self charon_distanceJoint])
        static_cast<b2DistanceJoint *>(_joint)->SetDampingRatio((float)damping);
    [self charon_changedParameter];
}

- (CGFloat)frequency
{
    return [self charon_distanceJoint] ? static_cast<b2DistanceJoint *>(_joint)->GetFrequency() : _frequency;
}

- (void)setFrequency:(CGFloat)frequency
{
    if (frequency == _frequency)
        return;
    CGFloat old = _frequency;
    _frequency = frequency;
    _stateFlags |= CharonFrequencySet;
    if (frequency == 0 || old == 0)
        [self charon_reevaluateJoint];
    else if ([self charon_distanceJoint])
        static_cast<b2DistanceJoint *>(_joint)->SetFrequency((float)frequency);
    [self charon_changedParameter];
}

- (CGFloat)frictionTorque
{
    return _frictionTorque;
}

// A pin's friction is a motor held at speed 0 with this much torque; no other kind has one (host).
- (void)setFrictionTorque:(CGFloat)torque
{
    if (_kind != CharonAttachmentPin || torque == _frictionTorque)
        return;
    _frictionTorque = torque;
    _stateFlags |= CharonFrictionTorqueSet;
    [self charon_applyPinAndSlider];
    [self charon_changedParameter];
}

- (UIFloatRange)attachmentRange
{
    return _attachmentRange;
}

// A pin's range is in radians, a slider's in points; the other kinds have none (host).
- (void)setAttachmentRange:(UIFloatRange)range
{
    if (_kind != CharonAttachmentPin && _kind != CharonAttachmentSliding)
        return;
    _attachmentRange = range;
    _stateFlags |= CharonRangeSet;
    [self charon_applyPinAndSlider];
    [self charon_changedParameter];
}

- (void)charon_applyPinAndSlider
{
    if (!_joint)
        return;
    if (_kind == CharonAttachmentPin) {
        b2RevoluteJoint *pin = static_cast<b2RevoluteJoint *>(_joint);
        if (_stateFlags & CharonRangeSet) {
            pin->EnableLimit(true);
            pin->SetLimits((float)_attachmentRange.minimum, (float)_attachmentRange.maximum);
        }
        if (_stateFlags & CharonFrictionTorqueSet) {
            pin->EnableMotor(true);
            pin->SetMotorSpeed(0);
            pin->SetMaxMotorTorque((float)_frictionTorque);
        }
    } else if (_kind == CharonAttachmentSliding && (_stateFlags & CharonRangeSet)) {
        b2PrismaticJoint *slider = static_cast<b2PrismaticJoint *>(_joint);
        slider->EnableLimit(true);
        slider->SetLimits((float)(_attachmentRange.minimum * CHARON_DYNAMICS_INVERSE_PTM), (float)(_attachmentRange.maximum * CHARON_DYNAMICS_INVERSE_PTM));
    }
}

- (void)charon_changedParameter
{
    UIDynamicAnimator *context = [self charon_context];
    NSArray *items = [self charon_items];
    [context charon_bodyForItem:items.firstObject].resting = NO;
    if (_anchorBody)
        _anchorBody.resting = NO;
    else if (items.count > 1)
        [context charon_bodyForItem:items[1]].resting = NO;
    [context charon_tickle];
}

- (void)charon_associate
{
    [super charon_associate];
    UIDynamicAnimator *context = [self charon_context];
    for (id<UIDynamicItem> item in [self charon_items])
        [context charon_registerBodyForItem:item shape:CharonDynamicsShapeBox];
    if (_type == 1)
        _anchorBody = [context charon_anchorBodyAtPoint:_anchorPoint];
    [self charon_reevaluateJoint];
}

- (void)charon_destroyJoint
{
    if (_joint)
        [[self charon_context] charon_world]->DestroyJoint(_joint);
    _joint = NULL;
}

// -[UIAttachmentBehavior _reevaluateJoint] (7.0), and the joints of the 9.0 factories.
- (void)charon_reevaluateJoint
{
    UIDynamicAnimator *context = [self charon_context];
    b2World *world = [context charon_world];
    if (!world || ![self charon_isAssociated])
        return;
    NSArray *items = [self charon_items];
    b2Body *bodyA = [context charon_bodyForItem:items.firstObject].b2Body;
    b2Body *bodyB = _anchorBody ? _anchorBody.b2Body : [context charon_bodyForItem:items.lastObject].b2Body;
    [self charon_destroyJoint];
    _stateFlags &= ~CharonRevolute;
    b2Vec2 anchor = charon_metres(_anchorPoint);
    switch (_kind) {
    case CharonAttachmentDistance: {
        b2DistanceJointDef definition;
        definition.Initialize(bodyA, bodyB, bodyA->GetWorldPoint(charon_metres(_anchorPointA)), bodyB->GetWorldPoint(charon_metres(_anchorPointB)));
        definition.collideConnected = _type == 0;
        definition.frequencyHz = (_stateFlags & CharonFrequencySet) ? (float)_frequency : 0.0f;
        definition.dampingRatio = (_stateFlags & CharonDampingSet) ? (float)_damping : 0.0f;
        _joint = world->CreateJoint(&definition);
        b2DistanceJoint *distance = static_cast<b2DistanceJoint *>(_joint);
        if (_stateFlags & CharonLengthSet)
            distance->SetLength((float)(_length * CHARON_DYNAMICS_INVERSE_PTM));
        if (CHARON_DYNAMICS_PTM * distance->GetLength() < 1.0f && _frequency == 0 && _type == 1 && !(_stateFlags & CharonLengthSet)) {
            [self charon_destroyJoint];
            b2RevoluteJointDef pin;
            pin.Initialize(bodyA, bodyB, bodyB->GetPosition());
            _joint = world->CreateJoint(&pin);
            _stateFlags |= CharonRevolute;
        }
        break;
    }
    case CharonAttachmentFixed: {
        b2WeldJointDef definition;
        definition.Initialize(bodyA, bodyB, anchor);
        _joint = world->CreateJoint(&definition);
        break;
    }
    case CharonAttachmentPin: {
        b2RevoluteJointDef definition;
        definition.Initialize(bodyA, bodyB, anchor);
        _joint = world->CreateJoint(&definition);
        break;
    }
    case CharonAttachmentSliding: {
        b2Vec2 axis((float)_axis.dx, (float)_axis.dy);
        axis.Normalize();
        b2PrismaticJointDef definition;
        definition.Initialize(bodyA, bodyB, anchor, axis);
        _joint = world->CreateJoint(&definition);
        break;
    }
    case CharonAttachmentLimit: {
        CGPoint centreA = charon_points(bodyA->GetPosition()), centreB = charon_points(bodyB->GetPosition());
        b2Vec2 worldA = charon_metres(CGPointMake(centreA.x - _anchorPointA.x, centreA.y - _anchorPointA.y));
        b2Vec2 worldB = charon_metres(CGPointMake(centreB.x - _anchorPointB.x, centreB.y - _anchorPointB.y));
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
    [self charon_applyPinAndSlider];
}

- (void)charon_dissociate
{
    UIDynamicAnimator *context = [self charon_context];
    [self charon_destroyJoint];
    if (_anchorBody) {
        [context charon_removeBody:_anchorBody];
        _anchorBody = nil;
    }
    for (id<UIDynamicItem> item in [self charon_items])
        [context charon_unregisterBodyForItem:item action:nil];
    [super charon_dissociate];
}

@end
