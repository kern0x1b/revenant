#import "CharonDynamics.h"

// The material of an item's body. A property is pushed to the body only once it was set to a value
// other than the one it had, and then at association, at addItem: and at the start of each step after
// any change; several behaviors on one item are applied in the animator's hierarchy order, so the last
// one that set a property wins. Removing the behavior puts the 7.0 properties back to their defaults
// at once (7.0); anchored and charge (9.0) stay as they were (host).
enum {
    CharonElasticitySet = 1 << 0,
    CharonFrictionSet = 1 << 1,
    CharonDensitySet = 1 << 2,
    CharonResistanceSet = 1 << 3,
    CharonAngularResistanceSet = 1 << 4,
    CharonRotationSet = 1 << 5,
    CharonChargeSet = 1 << 6,
    CharonAnchoredSet = 1 << 7,
};

@implementation UIDynamicItemBehavior {
    CGFloat _elasticity, _friction, _density, _resistance, _angularResistance, _charge;
    BOOL _allowsRotation, _anchored;
    NSUInteger _stateFlags;
    NSMapTable *_cachedLinearVelocities;
    NSMapTable *_cachedAngularVelocities;
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
    _elasticity = 0.2;
    _friction = 0.2;
    _density = 1;
    _resistance = 0.1;
    _angularResistance = 0.1;
    _allowsRotation = YES;
    return self;
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithString:[super description]];
    if (_stateFlags & CharonElasticitySet)
        [description appendFormat:@" E=%f", _elasticity];
    if (_stateFlags & CharonFrictionSet)
        [description appendFormat:@" F=%f", _friction];
    if (_stateFlags & CharonDensitySet)
        [description appendFormat:@" D=%f", _density];
    if (_stateFlags & CharonResistanceSet)
        [description appendFormat:@" R=%f", _resistance];
    if (_stateFlags & CharonAngularResistanceSet)
        [description appendFormat:@" AR=%f", _angularResistance];
    if (!_allowsRotation)
        [description appendString:@" !Rotation"];
    for (id item in [self charon_items])
        [description appendFormat:@" %@", item];
    return description;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self charon_items]];
}

- (void)charon_changed:(NSUInteger)flag
{
    _stateFlags |= flag;
    [[self charon_context] charon_shouldReevaluateLocalBehaviors];
}

#define CHARON_PROPERTY(type, getter, setter, ivar, flag) \
- (type)getter { return ivar; } \
- (void)setter:(type)value { if (value == ivar) return; ivar = value; [self charon_changed:flag]; }

CHARON_PROPERTY(CGFloat, elasticity, setElasticity, _elasticity, CharonElasticitySet)
CHARON_PROPERTY(CGFloat, friction, setFriction, _friction, CharonFrictionSet)
CHARON_PROPERTY(CGFloat, density, setDensity, _density, CharonDensitySet)
CHARON_PROPERTY(CGFloat, resistance, setResistance, _resistance, CharonResistanceSet)
CHARON_PROPERTY(CGFloat, angularResistance, setAngularResistance, _angularResistance, CharonAngularResistanceSet)
CHARON_PROPERTY(BOOL, allowsRotation, setAllowsRotation, _allowsRotation, CharonRotationSet)
CHARON_PROPERTY(CGFloat, charge, setCharge, _charge, CharonChargeSet)
CHARON_PROPERTY(BOOL, isAnchored, setAnchored, _anchored, CharonAnchoredSet)

#undef CHARON_PROPERTY

// -[UIDynamicItemBehavior _configureBody:forView:] (7.0), and the two 9.0 properties after them. An
// anchored body is static: b2Body::SetType zeroes its velocities, as the host's anchored item has none.
- (void)charon_configureBody:(CharonDynamicsBody *)body
{
    if (_stateFlags & CharonElasticitySet)
        body.restitution = _elasticity;
    if (_stateFlags & CharonFrictionSet)
        body.friction = _friction;
    if (_stateFlags & CharonDensitySet)
        body.normalizedDensity = _density;
    if (_stateFlags & CharonResistanceSet)
        body.linearDamping = _resistance;
    if (_stateFlags & CharonAngularResistanceSet)
        body.angularDamping = _angularResistance;
    if (_stateFlags & CharonRotationSet)
        body.allowsRotation = _allowsRotation;
    if (_stateFlags & CharonChargeSet)
        body.charge = _charge;
    if (_stateFlags & CharonAnchoredSet)
        body.dynamic = !_anchored;
}

static void charon_reset_material(CharonDynamicsBody *body)
{
    body.restitution = 0.2;
    body.friction = 0.2;
    body.normalizedDensity = 1;
    body.linearDamping = 0.1;
    body.angularDamping = 0.1;
    body.allowsRotation = YES;
}

- (void)charon_registerItem:(id<UIDynamicItem>)item
{
    CharonDynamicsBody *body = [[self charon_context] charon_registerBodyForItem:item shape:CharonDynamicsShapeBox];
    [self charon_configureBody:body];
}

// Mode 2 is the behavior's own association (bodies registered, then configured); every other mode is
// the start of a step after a change, which configures the bodies the items already have.
- (void)charon_reevaluate:(NSInteger)mode
{
    UIDynamicAnimator *context = [self charon_context];
    for (id<UIDynamicItem> item in [self charon_items]) {
        if (mode == 2)
            [self charon_registerItem:item];
        else if (CharonDynamicsBody *body = [context charon_bodyForItem:item])
            [self charon_configureBody:body];
    }
}

- (void)charon_associate
{
    [super charon_associate];
    [self charon_reevaluate:2];
    UIDynamicAnimator *context = [self charon_context];
    for (id<UIDynamicItem> item in [self charon_items]) {
        CharonDynamicsBody *body = [context charon_bodyForItem:item];
        NSValue *linear = [_cachedLinearVelocities objectForKey:item];
        NSNumber *angular = [_cachedAngularVelocities objectForKey:item];
        if (linear) {
            CGPoint velocity = body.velocity, added = [linear CGPointValue];
            body.velocity = CGPointMake(velocity.x + added.x, velocity.y + added.y);
        }
        if (angular)
            body.angularVelocity = body.angularVelocity + [angular doubleValue];
    }
    [_cachedLinearVelocities removeAllObjects];
    [_cachedAngularVelocities removeAllObjects];
}

- (void)charon_dissociate
{
    for (id<UIDynamicItem> item in [self charon_items])
        [[self charon_context] charon_unregisterBodyForItem:item action:^(CharonDynamicsBody *body) {
            charon_reset_material(body);
        }];
    [super charon_dissociate];
}

- (void)addItem:(id<UIDynamicItem>)item
{
    if ([[self charon_items] containsObject:item])
        return;
    [[self charon_items] addObject:item];
    if ([self charon_isAssociated]) {
        [self charon_registerItem:item];
        [[self charon_context] charon_shouldReevaluateLocalBehaviors];
    }
}

- (void)removeItem:(id<UIDynamicItem>)item
{
    if (![[self charon_items] containsObject:item])
        return;
    UIDynamicAnimator *context = [self charon_context];
    [context charon_unregisterBodyForItem:item action:^(CharonDynamicsBody *body) {
        charon_reset_material(body);
    }];
    [context charon_shouldReevaluateLocalBehaviors];
    [_cachedLinearVelocities removeObjectForKey:item];
    [_cachedAngularVelocities removeObjectForKey:item];
    [[self charon_items] removeObject:item];
}

// 7.0 keys its velocity caches weakly (+weakToStrongObjectsMapTable, which 4.3-5.1.1 lack). An entry
// exists only for an item in -charon_items, which holds it, and leaves with -removeItem:, so keys that
// are not retained answer as weak ones do; the options below are the ones 4.3's NSMapTable has.
static NSMapTable *charon_velocity_cache(void)
{
    return [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsObjectPersonality
                                 valueOptions:NSPointerFunctionsStrongMemory];
}

// A velocity added before the behavior joins an animator is kept, summed, and given to the body at
// association; after that it goes to the body at once.
- (void)addLinearVelocity:(CGPoint)velocity forItem:(id<UIDynamicItem>)item
{
    if ((velocity.x == 0 && velocity.y == 0) || ![[self charon_items] containsObject:item])
        return;
    if ([self charon_isAssociated]) {
        CharonDynamicsBody *body = [[self charon_context] charon_bodyForItem:item];
        CGPoint current = body.velocity;
        body.velocity = CGPointMake(current.x + velocity.x, current.y + velocity.y);
        [self charon_changedParameterForBody:body];
        return;
    }
    _cachedLinearVelocities = _cachedLinearVelocities ?: charon_velocity_cache();
    CGPoint cached = [[_cachedLinearVelocities objectForKey:item] CGPointValue];
    [_cachedLinearVelocities setObject:[NSValue valueWithCGPoint:CGPointMake(cached.x + velocity.x, cached.y + velocity.y)] forKey:item];
}

- (CGPoint)linearVelocityForItem:(id<UIDynamicItem>)item
{
    if (![self charon_isAssociated] || ![[self charon_items] containsObject:item])
        return CGPointZero;
    return [[self charon_context] charon_bodyForItem:item].velocity;
}

- (void)addAngularVelocity:(CGFloat)velocity forItem:(id<UIDynamicItem>)item
{
    if (velocity == 0 || ![[self charon_items] containsObject:item])
        return;
    if ([self charon_isAssociated]) {
        CharonDynamicsBody *body = [[self charon_context] charon_bodyForItem:item];
        body.angularVelocity = body.angularVelocity + velocity;
        [self charon_changedParameterForBody:body];
        return;
    }
    _cachedAngularVelocities = _cachedAngularVelocities ?: charon_velocity_cache();
    CGFloat cached = [[_cachedAngularVelocities objectForKey:item] doubleValue];
    [_cachedAngularVelocities setObject:@(cached + velocity) forKey:item];
}

- (CGFloat)angularVelocityForItem:(id<UIDynamicItem>)item
{
    if (![self charon_isAssociated] || ![[self charon_items] containsObject:item])
        return 0;
    return [[self charon_context] charon_bodyForItem:item].angularVelocity;
}

@end
