#import "RevenantDynamics.h"

enum {
    RevenantElasticitySet = 1 << 0,
    RevenantFrictionSet = 1 << 1,
    RevenantDensitySet = 1 << 2,
    RevenantResistanceSet = 1 << 3,
    RevenantAngularResistanceSet = 1 << 4,
    RevenantRotationSet = 1 << 5,
    RevenantChargeSet = 1 << 6,
    RevenantAnchoredSet = 1 << 7,
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
    if (!(self = [super revenant_initPrimitive:YES]))
        return nil;
    [[self revenant_items] addObjectsFromArray:items ?: @[]];
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
    if (_stateFlags & RevenantElasticitySet)
        [description appendFormat:@" E=%f", _elasticity];
    if (_stateFlags & RevenantFrictionSet)
        [description appendFormat:@" F=%f", _friction];
    if (_stateFlags & RevenantDensitySet)
        [description appendFormat:@" D=%f", _density];
    if (_stateFlags & RevenantResistanceSet)
        [description appendFormat:@" R=%f", _resistance];
    if (_stateFlags & RevenantAngularResistanceSet)
        [description appendFormat:@" AR=%f", _angularResistance];
    if (!_allowsRotation)
        [description appendString:@" !Rotation"];
    for (id item in [self revenant_items])
        [description appendFormat:@" %@", item];
    return description;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self revenant_items]];
}

- (void)revenant_changed:(NSUInteger)flag
{
    _stateFlags |= flag;
    [[self revenant_context] revenant_shouldReevaluateLocalBehaviors];
}

#define REVENANT_PROPERTY(type, getter, setter, ivar, flag) \
- (type)getter { return ivar; } \
- (void)setter:(type)value { if (value == ivar) return; ivar = value; [self revenant_changed:flag]; }

REVENANT_PROPERTY(CGFloat, elasticity, setElasticity, _elasticity, RevenantElasticitySet)
REVENANT_PROPERTY(CGFloat, friction, setFriction, _friction, RevenantFrictionSet)
REVENANT_PROPERTY(CGFloat, density, setDensity, _density, RevenantDensitySet)
REVENANT_PROPERTY(CGFloat, resistance, setResistance, _resistance, RevenantResistanceSet)
REVENANT_PROPERTY(CGFloat, angularResistance, setAngularResistance, _angularResistance, RevenantAngularResistanceSet)
REVENANT_PROPERTY(BOOL, allowsRotation, setAllowsRotation, _allowsRotation, RevenantRotationSet)
REVENANT_PROPERTY(CGFloat, charge, setCharge, _charge, RevenantChargeSet)
REVENANT_PROPERTY(BOOL, isAnchored, setAnchored, _anchored, RevenantAnchoredSet)

#undef REVENANT_PROPERTY

- (void)revenant_configureBody:(RevenantDynamicsBody *)body
{
    if (_stateFlags & RevenantElasticitySet)
        body.restitution = _elasticity;
    if (_stateFlags & RevenantFrictionSet)
        body.friction = _friction;
    if (_stateFlags & RevenantDensitySet)
        body.normalizedDensity = _density;
    if (_stateFlags & RevenantResistanceSet)
        body.linearDamping = _resistance;
    if (_stateFlags & RevenantAngularResistanceSet)
        body.angularDamping = _angularResistance;
    if (_stateFlags & RevenantRotationSet)
        body.allowsRotation = _allowsRotation;
    if (_stateFlags & RevenantChargeSet)
        body.charge = _charge;
    if (_stateFlags & RevenantAnchoredSet)
        body.dynamic = !_anchored;
}

static void revenant_reset_material(RevenantDynamicsBody *body)
{
    body.restitution = 0.2;
    body.friction = 0.2;
    body.normalizedDensity = 1;
    body.linearDamping = 0.1;
    body.angularDamping = 0.1;
    body.allowsRotation = YES;
}

- (void)revenant_registerItem:(id<UIDynamicItem>)item
{
    RevenantDynamicsBody *body = [[self revenant_context] revenant_registerBodyForItem:item shape:RevenantDynamicsShapeBox];
    [self revenant_configureBody:body];
}

- (void)revenant_reevaluate:(NSInteger)mode
{
    UIDynamicAnimator *context = [self revenant_context];
    for (id<UIDynamicItem> item in [self revenant_items]) {
        if (mode == 2)
            [self revenant_registerItem:item];
        else if (RevenantDynamicsBody *body = [context revenant_bodyForItem:item])
            [self revenant_configureBody:body];
    }
}

- (void)revenant_associate
{
    [super revenant_associate];
    [self revenant_reevaluate:2];
    UIDynamicAnimator *context = [self revenant_context];
    for (id<UIDynamicItem> item in [self revenant_items]) {
        RevenantDynamicsBody *body = [context revenant_bodyForItem:item];
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

- (void)revenant_dissociate
{
    for (id<UIDynamicItem> item in [self revenant_items])
        [[self revenant_context] revenant_unregisterBodyForItem:item action:^(RevenantDynamicsBody *body) {
            revenant_reset_material(body);
        }];
    [super revenant_dissociate];
}

- (void)addItem:(id<UIDynamicItem>)item
{
    if ([[self revenant_items] containsObject:item])
        return;
    [[self revenant_items] addObject:item];
    if ([self revenant_isAssociated]) {
        [self revenant_registerItem:item];
        [[self revenant_context] revenant_shouldReevaluateLocalBehaviors];
    }
}

- (void)removeItem:(id<UIDynamicItem>)item
{
    if (![[self revenant_items] containsObject:item])
        return;
    UIDynamicAnimator *context = [self revenant_context];
    [context revenant_unregisterBodyForItem:item action:^(RevenantDynamicsBody *body) {
        revenant_reset_material(body);
    }];
    [context revenant_shouldReevaluateLocalBehaviors];
    [_cachedLinearVelocities removeObjectForKey:item];
    [_cachedAngularVelocities removeObjectForKey:item];
    [[self revenant_items] removeObject:item];
}

static NSMapTable *revenant_velocity_cache(void)
{
    return [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsObjectPersonality
                                 valueOptions:NSPointerFunctionsStrongMemory];
}

- (void)addLinearVelocity:(CGPoint)velocity forItem:(id<UIDynamicItem>)item
{
    if ((velocity.x == 0 && velocity.y == 0) || ![[self revenant_items] containsObject:item])
        return;
    if ([self revenant_isAssociated]) {
        RevenantDynamicsBody *body = [[self revenant_context] revenant_bodyForItem:item];
        CGPoint current = body.velocity;
        body.velocity = CGPointMake(current.x + velocity.x, current.y + velocity.y);
        [self revenant_changedParameterForBody:body];
        return;
    }
    _cachedLinearVelocities = _cachedLinearVelocities ?: revenant_velocity_cache();
    CGPoint cached = [[_cachedLinearVelocities objectForKey:item] CGPointValue];
    [_cachedLinearVelocities setObject:[NSValue valueWithCGPoint:CGPointMake(cached.x + velocity.x, cached.y + velocity.y)] forKey:item];
}

- (CGPoint)linearVelocityForItem:(id<UIDynamicItem>)item
{
    if (![self revenant_isAssociated] || ![[self revenant_items] containsObject:item])
        return CGPointZero;
    return [[self revenant_context] revenant_bodyForItem:item].velocity;
}

- (void)addAngularVelocity:(CGFloat)velocity forItem:(id<UIDynamicItem>)item
{
    if (velocity == 0 || ![[self revenant_items] containsObject:item])
        return;
    if ([self revenant_isAssociated]) {
        RevenantDynamicsBody *body = [[self revenant_context] revenant_bodyForItem:item];
        body.angularVelocity = body.angularVelocity + velocity;
        [self revenant_changedParameterForBody:body];
        return;
    }
    _cachedAngularVelocities = _cachedAngularVelocities ?: revenant_velocity_cache();
    CGFloat cached = [[_cachedAngularVelocities objectForKey:item] doubleValue];
    [_cachedAngularVelocities setObject:@(cached + velocity) forKey:item];
}

- (CGFloat)angularVelocityForItem:(id<UIDynamicItem>)item
{
    if (![self revenant_isAssociated] || ![[self revenant_items] containsObject:item])
        return 0;
    return [[self revenant_context] revenant_bodyForItem:item].angularVelocity;
}

@end
