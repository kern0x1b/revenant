#import "RevenantDynamics.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#ifdef REVENANT_HOST_DIFFERENTIAL
static const BOOL revenant_host_integrator = YES;
#else
static const BOOL revenant_host_integrator = NO;
#endif

static const float revenant_shape_radius = revenant_host_integrator ? 0.0f : 0.001f;

static Class revenant_layout_class(void)
{
    return NSClassFromString(@"UICollectionViewLayout");
}

static Class revenant_layout_attributes_class(void)
{
    return NSClassFromString(@"UICollectionViewLayoutAttributes");
}

@interface RevenantDynamicsBody ()
- (instancetype)initWithShape:(RevenantDynamicsShape)shape size:(CGSize)size vertices:(const b2Vec2 *)vertices count:(int32)count;
- (void)revenant_attachToWorld:(b2World *)world;
- (void)revenant_detachFromWorld;
@end

@implementation RevenantDynamicsBody {
    b2Body *_b2Body;
    b2BodyDef _definition;
    RevenantDynamicsShape _shape;
    CGSize _size;
    b2Vec2 *_vertices;
    int32 _vertexCount;
    float _density, _fixtureFriction, _fixtureRestitution, _areaFactor;
    BOOL _affectedByGravity;
    CGFloat _charge;
}

@synthesize representedObject = _representedObject, associations = _associations;
@synthesize categoryBitMask = _categoryBitMask, collisionBitMask = _collisionBitMask, contactTestBitMask = _contactTestBitMask;

- (instancetype)initWithShape:(RevenantDynamicsShape)shape size:(CGSize)size vertices:(const b2Vec2 *)vertices count:(int32)count
{
    if (!(self = [super init]))
        return nil;
    _shape = shape;
    _size = size;
    if (count > 0) {
        _vertices = (b2Vec2 *)malloc(sizeof(b2Vec2) * count);
        memcpy(_vertices, vertices, sizeof(b2Vec2) * count);
        _vertexCount = count;
    }
    _definition.type = b2_dynamicBody;
    _definition.linearDamping = 0.1f;
    _definition.angularDamping = 0.1f;
    _definition.allowSleep = true;
    _definition.awake = true;
    _definition.bullet = false;
    _definition.gravityScale = 0.0f;
    _fixtureFriction = 0.2f;
    _fixtureRestitution = 0.2f;
    _areaFactor = 1.0f;
    if (shape == RevenantDynamicsShapeBox && !revenant_host_integrator) {
        CGFloat inset = 0.02 / REVENANT_DYNAMICS_INVERSE_PTM;
        CGFloat width = size.width > inset + 1 ? size.width - inset : MAX(size.width - inset, size.width / 2);
        CGFloat height = size.height > inset + 1 ? size.height - inset : MAX(size.height - inset, size.height / 2);
        _areaFactor = (float)((size.width * size.height) / (width * height));
        _size = CGSizeMake(width, height);
    }
    _density = 1.0f * _areaFactor;
    return self;
}

- (void)dealloc
{
    free(_vertices);
}

- (b2Body *)b2Body
{
    return _b2Body;
}

- (void)revenant_attachToWorld:(b2World *)world
{
    if (_b2Body)
        return;
    _definition.userData = (__bridge void *)self;
    _b2Body = world->CreateBody(&_definition);
    b2FixtureDef fixture;
    fixture.density = _density;
    fixture.friction = _fixtureFriction;
    fixture.restitution = _fixtureRestitution;
    b2PolygonShape box;
    b2CircleShape circle;
    b2EdgeShape edge;
    b2ChainShape chain;
    switch (_shape) {
    case RevenantDynamicsShapeNone:
        return;
    case RevenantDynamicsShapeBox:
        box.SetAsBox(0.5f * (float)_size.width * REVENANT_DYNAMICS_INVERSE_PTM, 0.5f * (float)_size.height * REVENANT_DYNAMICS_INVERSE_PTM);
        box.m_radius = revenant_shape_radius;
        fixture.shape = &box;
        break;
    case RevenantDynamicsShapeCircle:
        circle.m_radius = 0.5f * (float)_size.width * REVENANT_DYNAMICS_INVERSE_PTM;
        fixture.shape = &circle;
        break;
    case RevenantDynamicsShapeEdge:
        edge.Set(_vertices[0], _vertices[1]);
        edge.m_radius = revenant_shape_radius;
        fixture.shape = &edge;
        break;
    case RevenantDynamicsShapeLoop:
        if (_vertexCount == 2) {
            b2Vec2 closed[3] = {_vertices[0], _vertices[1], _vertices[0]};
            chain.CreateChain(closed, 3);
            chain.SetPrevVertex(_vertices[1]);
            chain.SetNextVertex(_vertices[1]);
        } else {
            chain.CreateLoop(_vertices, _vertexCount);
        }
        chain.m_radius = revenant_shape_radius;
        fixture.shape = &chain;
        break;
    }
    _b2Body->CreateFixture(&fixture);
}

- (void)revenant_detachFromWorld
{
    if (!_b2Body)
        return;
    _definition.position = _b2Body->GetPosition();
    _definition.angle = _b2Body->GetAngle();
    _definition.linearVelocity = _b2Body->GetLinearVelocity();
    _definition.angularVelocity = _b2Body->GetAngularVelocity();
    _b2Body->GetWorld()->DestroyBody(_b2Body);
    _b2Body = NULL;
}

- (void)revenant_refilter
{
    for (b2Fixture *fixture = _b2Body ? _b2Body->GetFixtureList() : NULL; fixture; fixture = fixture->GetNext())
        fixture->Refilter();
}

- (void)setCategoryBitMask:(uint32_t)mask
{
    _categoryBitMask = mask;
    [self revenant_refilter];
}

- (void)setCollisionBitMask:(uint32_t)mask
{
    _collisionBitMask = mask;
    [self revenant_refilter];
}

- (void)setContactTestBitMask:(uint32_t)mask
{
    _contactTestBitMask = mask;
    [self revenant_refilter];
}

- (BOOL)affectedByGravity
{
    return _affectedByGravity;
}

- (void)setAffectedByGravity:(BOOL)affected
{
    _affectedByGravity = affected;
    _definition.gravityScale = affected ? 1.0f : 0.0f;
    if (_b2Body)
        _b2Body->SetGravityScale(_definition.gravityScale);
}

- (BOOL)usesPreciseCollisionDetection
{
    return _b2Body ? _b2Body->IsBullet() : _definition.bullet;
}

- (void)setUsesPreciseCollisionDetection:(BOOL)precise
{
    _definition.bullet = precise;
    if (_b2Body)
        _b2Body->SetBullet(precise);
}

- (BOOL)dynamic
{
    return (_b2Body ? _b2Body->GetType() : _definition.type) == b2_dynamicBody;
}

- (void)setDynamic:(BOOL)dynamic
{
    _definition.type = dynamic ? b2_dynamicBody : b2_staticBody;
    if (_b2Body)
        _b2Body->SetType(_definition.type);
}

- (BOOL)resting
{
    return _b2Body ? !_b2Body->IsAwake() : !_definition.awake;
}

- (void)setResting:(BOOL)resting
{
    _definition.awake = !resting;
    if (_b2Body)
        _b2Body->SetAwake(!resting);
}

- (CGPoint)position
{
    return revenant_points(_b2Body ? _b2Body->GetPosition() : _definition.position);
}

- (void)setPosition:(CGPoint)position
{
    _definition.position = revenant_metres(position);
    if (_b2Body)
        _b2Body->SetTransform(_definition.position, _b2Body->GetAngle());
}

- (CGFloat)rotation
{
    return _b2Body ? _b2Body->GetAngle() : _definition.angle;
}

- (void)setRotation:(CGFloat)rotation
{
    _definition.angle = (float)rotation;
    if (_b2Body)
        _b2Body->SetTransform(_b2Body->GetPosition(), (float)rotation);
}

- (CGPoint)velocity
{
    return revenant_points(_b2Body ? _b2Body->GetLinearVelocity() : _definition.linearVelocity);
}

- (void)setVelocity:(CGPoint)velocity
{
    _definition.linearVelocity = revenant_metres(velocity);
    if (_b2Body)
        _b2Body->SetLinearVelocity(_definition.linearVelocity);
}

- (CGFloat)angularVelocity
{
    return _b2Body ? _b2Body->GetAngularVelocity() : _definition.angularVelocity;
}

- (void)setAngularVelocity:(CGFloat)velocity
{
    _definition.angularVelocity = (float)velocity;
    if (_b2Body)
        _b2Body->SetAngularVelocity((float)velocity);
}

- (b2Fixture *)revenant_fixture
{
    return _b2Body ? _b2Body->GetFixtureList() : NULL;
}

- (CGFloat)restitution
{
    return _fixtureRestitution;
}

- (void)setRestitution:(CGFloat)restitution
{
    _fixtureRestitution = (float)restitution;
    if (b2Fixture *fixture = [self revenant_fixture])
        fixture->SetRestitution(_fixtureRestitution);
}

- (CGFloat)friction
{
    return _fixtureFriction;
}

- (void)setFriction:(CGFloat)friction
{
    _fixtureFriction = (float)friction;
    if (b2Fixture *fixture = [self revenant_fixture])
        fixture->SetFriction(_fixtureFriction);
}

- (CGFloat)normalizedDensity
{
    return _density / _areaFactor;
}

- (void)setNormalizedDensity:(CGFloat)density
{
    _density = (float)density * _areaFactor;
    if (b2Fixture *fixture = [self revenant_fixture]) {
        fixture->SetDensity(_density);
        _b2Body->ResetMassData();
    }
}

- (CGFloat)linearDamping
{
    return _b2Body ? _b2Body->GetLinearDamping() : _definition.linearDamping;
}

- (void)setLinearDamping:(CGFloat)damping
{
    _definition.linearDamping = (float)damping;
    if (_b2Body)
        _b2Body->SetLinearDamping((float)damping);
}

- (CGFloat)angularDamping
{
    return _b2Body ? _b2Body->GetAngularDamping() : _definition.angularDamping;
}

- (void)setAngularDamping:(CGFloat)damping
{
    _definition.angularDamping = (float)damping;
    if (_b2Body)
        _b2Body->SetAngularDamping((float)damping);
}

- (BOOL)allowsRotation
{
    return !(_b2Body ? _b2Body->IsFixedRotation() : _definition.fixedRotation);
}

- (void)setAllowsRotation:(BOOL)allows
{
    _definition.fixedRotation = !allows;
    if (_b2Body)
        _b2Body->SetFixedRotation(!allows);
}

- (CGFloat)charge
{
    return _charge;
}

- (void)setCharge:(CGFloat)charge
{
    _charge = charge;
}

- (void)applyForce:(CGVector)force
{
    if (_b2Body)
        _b2Body->ApplyForceToCenter(b2Vec2((float)force.dx, (float)force.dy));
}

- (void)applyForce:(CGVector)force atPoint:(CGPoint)point
{
    if (_b2Body)
        _b2Body->ApplyForce(b2Vec2((float)force.dx, (float)force.dy), revenant_metres(point));
}

- (void)applyImpulse:(CGVector)impulse
{
    if (_b2Body)
        _b2Body->ApplyLinearImpulse(b2Vec2((float)impulse.dx, (float)impulse.dy), _b2Body->GetWorldCenter());
}

- (void)applyImpulse:(CGVector)impulse atPoint:(CGPoint)point
{
    if (_b2Body)
        _b2Body->ApplyLinearImpulse(b2Vec2((float)impulse.dx, (float)impulse.dy), revenant_metres(point));
}

@end

@interface RevenantDynamicsContact ()
@property (nonatomic, readwrite) RevenantDynamicsBody *bodyA;
@property (nonatomic, readwrite) RevenantDynamicsBody *bodyB;
@property (nonatomic, readwrite) CGPoint contactPoint;
@property (nonatomic) BOOL beganDelivered;
@property (nonatomic) BOOL ended;
@end

@implementation RevenantDynamicsContact
@synthesize bodyA = _bodyA, bodyB = _bodyB, contactPoint = _contactPoint, beganDelivered = _beganDelivered, ended = _ended;
@end

namespace {

RevenantDynamicsBody *body_of(b2Fixture *fixture)
{
    return (__bridge RevenantDynamicsBody *)fixture->GetBody()->GetUserData();
}

class ContactFilter : public b2ContactFilter {
public:
    bool ShouldCollide(b2Fixture *fixtureA, b2Fixture *fixtureB)
    {
        RevenantDynamicsBody *a = body_of(fixtureA), *b = body_of(fixtureB);
        return (a.categoryBitMask & b.collisionBitMask) || (b.categoryBitMask & a.collisionBitMask);
    }
};

class ContactListener : public b2ContactListener {
public:
    NSMutableArray *records = [NSMutableArray array];
    NSMapTable *live = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                             valueOptions:NSPointerFunctionsStrongMemory];

    void BeginContact(b2Contact *contact)
    {
        RevenantDynamicsContact *record = [RevenantDynamicsContact new];
        record.bodyA = body_of(contact->GetFixtureA());
        record.bodyB = body_of(contact->GetFixtureB());
        [records addObject:record];
        [live setObject:record forKey:(__bridge id)(void *)contact];
    }

    void EndContact(b2Contact *contact)
    {
        RevenantDynamicsContact *record = [live objectForKey:(__bridge id)(void *)contact];
        record.ended = YES;
        [live removeObjectForKey:(__bridge id)(void *)contact];
    }

    void PreSolve(b2Contact *contact, const b2Manifold *)
    {
        RevenantDynamicsBody *a = body_of(contact->GetFixtureA()), *b = body_of(contact->GetFixtureB());
        bool respondsA = contact->GetFixtureA()->GetBody()->GetType() == b2_dynamicBody && (b.categoryBitMask & a.collisionBitMask);
        bool respondsB = contact->GetFixtureB()->GetBody()->GetType() == b2_dynamicBody && (a.categoryBitMask & b.collisionBitMask);
        if (!respondsA && !respondsB)
            contact->SetEnabled(false);
    }

    void PostSolve(b2Contact *contact, const b2ContactImpulse *impulse)
    {
        RevenantDynamicsContact *record = [live objectForKey:(__bridge id)(void *)contact];
        int32 count = contact->GetManifold()->pointCount;
        if (!record || count == 0)
            return;
        b2WorldManifold manifold;
        contact->GetWorldManifold(&manifold);
        int32 strongest = 0;
        for (int32 index = 1; index < count; index++) {
            if (impulse->normalImpulses[index] > impulse->normalImpulses[strongest])
                strongest = index;
        }
        record.contactPoint = revenant_points(manifold.points[strongest]);
    }
};

class ItemQuery : public b2QueryCallback {
public:
    NSMutableArray *items = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    bool ReportFixture(b2Fixture *fixture)
    {
        RevenantDynamicsBody *body = body_of(fixture);
        if (![seen containsObject:body]) {
            [seen addObject:body];
            if (body.representedObject)
                [items addObject:body.representedObject];
        }
        return true;
    }
};

}

typedef NS_ENUM(NSInteger, RevenantReferenceSystem) {
    RevenantReferenceSystemNone,
    RevenantReferenceSystemView,
    RevenantReferenceSystemLayout,
};

@interface RevenantDynamicsTicker : NSObject
@property (nonatomic, weak) UIDynamicAnimator *animator;
@end

@interface UIDynamicAnimator (RevenantDynamicsTick)
- (void)revenant_displayLinkTick:(CADisplayLink *)link;
@end

@implementation RevenantDynamicsTicker
@synthesize animator = _animator;

- (void)tick:(CADisplayLink *)link
{
    [self.animator revenant_displayLinkTick:link];
}

@end

@interface UIDynamicAnimator (RevenantReferenceView)
- (void)revenant_tickle;
@end

static CFMutableArrayRef revenant_animators;
static char revenant_watch_key;

static void revenant_reference_view_size_changed(UIView *view)
{
    for (CFIndex index = 0; index < CFArrayGetCount(revenant_animators); index++) {
        UIDynamicAnimator *animator = (__bridge UIDynamicAnimator *)CFArrayGetValueAtIndex(revenant_animators, index);
        if (animator.referenceView == view)
            [animator revenant_tickle];
    }
}

@interface RevenantReferenceViewWatch : NSObject
- (instancetype)initWithView:(UIView *)view;
@end

@implementation RevenantReferenceViewWatch {
    __unsafe_unretained UIView *_view;
    CGSize _sizeBefore;
}

- (instancetype)initWithView:(UIView *)view
{
    if (!(self = [super init]))
        return nil;
    _view = view;
    _sizeBefore = view.bounds.size;
    [view addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionPrior context:NULL];
    [view addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionPrior context:NULL];
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    CGSize size = _view.bounds.size;
    if ([[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue])
        _sizeBefore = size;
    else if (!CGSizeEqualToSize(size, _sizeBefore))
        revenant_reference_view_size_changed(_view);
}

- (void)dealloc
{
    [_view removeObserver:self forKeyPath:@"frame"];
    [_view removeObserver:self forKeyPath:@"bounds"];
}

@end

static void revenant_register_animator(UIDynamicAnimator *animator)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_animators = CFArrayCreateMutable(NULL, 0, NULL);
    });
    CFArrayAppendValue(revenant_animators, (__bridge const void *)animator);
    UIView *view = animator.referenceView;
    if (view && !objc_getAssociatedObject(view, &revenant_watch_key))
        objc_setAssociatedObject(view, &revenant_watch_key, [[RevenantReferenceViewWatch alloc] initWithView:view], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void revenant_unregister_animator(UIDynamicAnimator *animator)
{
    if (!revenant_animators)
        return;
    CFIndex index = CFArrayGetFirstIndexOfValue(revenant_animators, CFRangeMake(0, CFArrayGetCount(revenant_animators)), (__bridge const void *)animator);
    if (index == kCFNotFound)
        return;
    CFArrayRemoveValueAtIndex(revenant_animators, index);
    UIView *view = animator.referenceView;
    if (!view)
        return;
    for (index = 0; index < CFArrayGetCount(revenant_animators); index++)
        if (((__bridge UIDynamicAnimator *)CFArrayGetValueAtIndex(revenant_animators, index)).referenceView == view)
            return;
    objc_setAssociatedObject(view, &revenant_watch_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIDynamicAnimator {
    b2World *_world;
    ContactFilter *_contactFilter;
    ContactListener *_contactListener;
    NSMutableArray *_worldBodies;
    double _accumulatedDt;
    float _speed;
    __weak id _referenceSystem;
    RevenantReferenceSystem _referenceSystemType;
    CGRect _referenceSystemBounds;
    NSMutableArray *_topLevelBehaviors;
    NSMutableSet *_registeredBehaviors;
    NSMutableArray *_behaviorsToAdd;
    NSMutableArray *_behaviorsToRemove;
    NSMutableArray *_postSolverActions;
    NSMutableDictionary *_bodies;
    NSMutableArray *_beginContacts;
    NSMutableArray *_endContacts;
    CADisplayLink *_displayLink;
    CFTimeInterval _lastUpdateTime;
    NSTimeInterval _elapsedTime;
    NSTimeInterval _realElapsedTime;
    NSUInteger _ticks;
    CGFloat _accuracy;
    NSInteger _integralization;
    int _registeredCollisionGroups;
    int _registeredImplicitBounds;
    BOOL _needsLocalBehaviorReevaluation;
    BOOL _isInWorldStepMethod;
    __weak id<UIDynamicAnimatorDelegate> _delegate;
    BOOL _delegateWillResume;
    BOOL _delegateDidPause;
    BOOL _disableDisplayLink;
    BOOL _deallocating;
}

- (instancetype)init
{
    return [self revenant_initWithReferenceSystem:nil];
}

- (instancetype)initWithReferenceView:(UIView *)view
{
    return [self revenant_initWithReferenceSystem:view];
}

- (instancetype)revenant_initWithReferenceSystem:(id)system __attribute__((objc_method_family(init)))
{
    if (!(self = [super init]))
        return nil;
    _referenceSystem = system;
    if ([system isKindOfClass:[UIView class]]) {
        _referenceSystemType = RevenantReferenceSystemView;
        _referenceSystemBounds = [system bounds];
    } else if ([system isKindOfClass:revenant_layout_class()]) {
        _referenceSystemType = RevenantReferenceSystemLayout;
        _referenceSystemBounds = [self revenant_layoutBounds];
    } else {
        _referenceSystemType = RevenantReferenceSystemNone;
        _referenceSystemBounds = CGRectNull;
    }
    _registeredBehaviors = [NSMutableSet new];
    _topLevelBehaviors = [NSMutableArray new];
    _postSolverActions = [NSMutableArray new];
    _bodies = [NSMutableDictionary new];
    _worldBodies = [NSMutableArray new];
    _beginContacts = [NSMutableArray new];
    _endContacts = [NSMutableArray new];
    _accuracy = [UIScreen mainScreen].scale;
    _speed = 1.0f;
    _integralization = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"] ? 1 : 0;
    if ([NSThread isMainThread])
        revenant_register_animator(self);
    return self;
}

- (void)dealloc
{
    _deallocating = YES;
    revenant_unregister_animator(self);
    [_displayLink invalidate];
    @autoreleasepool {
        for (UIDynamicBehavior *behavior in [_registeredBehaviors copy]) {
            [behavior revenant_dissociate];
            [behavior revenant_setContext:nil];
        }
    }
    delete _world;
    delete _contactFilter;
    delete _contactListener;
}

- (CGRect)revenant_layoutBounds
{
    UICollectionViewLayout *layout = _referenceSystem;
    CGSize size = [layout collectionViewContentSize];
    return CGRectMake(0, 0, size.width, size.height);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> %@(%fs) in <%@: %p> %@", [self class], self, self.running ? @"" : @"Stopped ",
            _elapsedTime, [_referenceSystem class], _referenceSystem, NSStringFromCGRect(_referenceSystemBounds)];
}

- (UIView *)referenceView
{
    return _referenceSystemType == RevenantReferenceSystemView ? _referenceSystem : nil;
}

- (NSArray *)behaviors
{
    return [NSArray arrayWithArray:_topLevelBehaviors];
}

- (BOOL)isRunning
{
    return _displayLink != nil;
}

- (NSTimeInterval)elapsedTime
{
    return _elapsedTime;
}

- (id<UIDynamicAnimatorDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIDynamicAnimatorDelegate>)delegate
{
    _delegate = delegate;
    _delegateWillResume = [delegate respondsToSelector:@selector(dynamicAnimatorWillResume:)];
    _delegateDidPause = [delegate respondsToSelector:@selector(dynamicAnimatorDidPause:)];
}

#pragma mark World

- (b2World *)revenant_world
{
    return _world;
}

- (void)revenant_setupWorld
{
    _world = new b2World(b2Vec2(0.0f, -9.8f));
    _world->SetAllowSleeping(true);
    _world->SetContinuousPhysics(true);
    _world->SetAutoClearForces(false);
    _contactFilter = new ContactFilter();
    _contactListener = new ContactListener();
    _world->SetContactFilter(_contactFilter);
    _world->SetContactListener(_contactListener);
    _accumulatedDt = 0.0;
}

- (void)revenant_setWorldGravity:(CGVector)gravity
{
    if (_world)
        _world->SetGravity(b2Vec2((float)(gravity.dx * 10.0), (float)(gravity.dy * 10.0)));
}

- (void)revenant_addBody:(RevenantDynamicsBody *)body
{
    if (!_world || body.b2Body)
        return;
    [body revenant_attachToWorld:_world];
    [_worldBodies addObject:body];
}

- (void)revenant_removeBody:(RevenantDynamicsBody *)body
{
    if (!body.b2Body)
        return;
    [body revenant_detachFromWorld];
    [_worldBodies removeObjectIdenticalTo:body];
}

- (BOOL)revenant_stepWorld:(double)dt
{
    if (_world->GetBodyCount() == 0)
        return NO;
    float step = (float)dt;
    if (!(step > 0.0f) || fabsf(step) < 0x1p-63f)
        return YES;
    if (revenant_host_integrator) {
        const float substep = (float)(1.0 / 120.0);
        _accumulatedDt += dt * (double)_speed;
        while (_accumulatedDt >= (double)substep) {
            _world->Step(substep, 8, 3);
            _accumulatedDt += -(double)substep;
        }
    } else {
        double total = _accumulatedDt + dt;
        _accumulatedDt = fmod(total, 0.004);
        if (total > 0.004) {
            float substep = (float)((double)_speed * 0.004);
            do {
                _world->Step(substep, 8, 3);
                total += -0.004;
            } while (total > 0.004);
        }
    }
    [self revenant_flushContacts];
    _world->ClearForces();
    BOOL resting = YES;
    for (RevenantDynamicsBody *body in [_worldBodies copy]) {
        if (body.representedObject)
            [self revenant_writeBack:body];
        if (body.dynamic)
            resting = resting && body.resting;
    }
    return !resting;
}

- (void)revenant_flushContacts
{
    NSMutableArray *records = _contactListener->records;
    for (RevenantDynamicsContact *record in [records copy]) {
        if (!record.beganDelivered) {
            record.beganDelivered = YES;
            [_beginContacts addObject:record];
        }
        if (record.ended) {
            [_endContacts addObject:record];
            [records removeObjectIdenticalTo:record];
        }
    }
}

#pragma mark Stepping

- (void)revenant_displayLinkTick:(CADisplayLink *)link
{
    CFTimeInterval dt = link.timestamp - _lastUpdateTime;
    if (dt > 0.5)
        dt = 1.0 / 60.0;
    _realElapsedTime += dt;
    BOOL awake = [self revenant_animatorStep:dt];
    _lastUpdateTime = link.timestamp;
    if (!awake)
        [self revenant_stop];
}

- (CGRect)revenant_currentReferenceBounds
{
    if (_referenceSystemType == RevenantReferenceSystemLayout)
        return [self revenant_layoutBounds];
    return [_referenceSystem bounds];
}

- (BOOL)revenant_animatorStep:(double)dt
{
    _ticks += 1;
    _elapsedTime += dt;
    [self revenant_preSolverStep];
    _isInWorldStepMethod = YES;
    BOOL awake = [self revenant_stepWorld:dt];
    _isInWorldStepMethod = NO;
    [self revenant_postSolverStep];
    if (_referenceSystemType == RevenantReferenceSystemLayout)
        [(UICollectionViewLayout *)_referenceSystem invalidateLayout];
    return awake;
}

- (void)revenant_preSolverStep
{
    if (_needsLocalBehaviorReevaluation) {
        _needsLocalBehaviorReevaluation = NO;
        [self revenant_traverseBehaviorHierarchy:^(UIDynamicBehavior *behavior) {
            [behavior revenant_reevaluate:0];
        }];
    }
    id system = _referenceSystem;
    if (_registeredImplicitBounds >= 1 && system && !CGRectEqualToRect(_referenceSystemBounds, [self revenant_currentReferenceBounds])) {
        if (_referenceSystemType == RevenantReferenceSystemView)
            _referenceSystemBounds = [[(UIView *)system layer] presentationLayer].bounds;
        else
            _referenceSystemBounds = [self revenant_currentReferenceBounds];
        [self revenant_traverseBehaviorHierarchy:^(UIDynamicBehavior *behavior) {
            if ([behavior isKindOfClass:[UICollisionBehavior class]] && [(UICollisionBehavior *)behavior revenant_usesImplicitBounds])
                [(UICollisionBehavior *)behavior revenant_reevaluateImplicitBounds];
        }];
    }
    for (UIDynamicBehavior *behavior in [_registeredBehaviors copy])
        [behavior revenant_step];
}

- (void)revenant_postSolverStep
{
    _isInWorldStepMethod = YES;
    [self revenant_reportContacts:_beginContacts began:YES];
    [self revenant_reportContacts:_endContacts began:NO];
    for (UIDynamicBehavior *behavior in [_registeredBehaviors copy]) {
        if (behavior.action)
            behavior.action();
    }
    BOOL stoppable = YES;
    for (UIDynamicBehavior *behavior in _topLevelBehaviors) {
        if (![behavior revenant_allowsAnimatorToStop]) {
            stoppable = NO;
            break;
        }
    }
    _isInWorldStepMethod = NO;
    NSArray *actions = [_postSolverActions copy];
    [_postSolverActions removeAllObjects];
    for (dispatch_block_t action in actions)
        action();
    NSArray *removing = _behaviorsToRemove, *adding = _behaviorsToAdd;
    _behaviorsToRemove = nil;
    _behaviorsToAdd = nil;
    for (UIDynamicBehavior *behavior in removing)
        [self revenant_unregisterBehavior:behavior];
    for (UIDynamicBehavior *behavior in adding)
        [self revenant_registerBehavior:behavior];
    if (stoppable || _registeredBehaviors.count == 0)
        [self revenant_stop];
}

- (void)revenant_reportContacts:(NSMutableArray *)contacts began:(BOOL)began
{
    NSArray *delivered = [contacts copy];
    [contacts removeAllObjects];
    if (delivered.count == 0)
        return;
    [self revenant_traverseBehaviorHierarchy:^(UIDynamicBehavior *behavior) {
        if (![behavior isKindOfClass:[UICollisionBehavior class]])
            return;
        for (RevenantDynamicsContact *contact in delivered) {
            if (began)
                [(UICollisionBehavior *)behavior revenant_didBeginContact:contact];
            else
                [(UICollisionBehavior *)behavior revenant_didEndContact:contact];
        }
    }];
}

- (void)revenant_runBlockPostSolverIfNeeded:(dispatch_block_t)block
{
    if (_isInWorldStepMethod)
        [_postSolverActions addObject:[block copy]];
    else
        block();
}

#pragma mark Running

- (void)revenant_tickle
{
    if (!self.running && _bodies.count != 0)
        [self revenant_start];
}

- (void)revenant_start
{
    if ((_referenceSystemType == RevenantReferenceSystemView && !_referenceSystem) || _displayLink || _disableDisplayLink || _deallocating)
        return;
    _lastUpdateTime = CACurrentMediaTime();
    RevenantDynamicsTicker *ticker = [RevenantDynamicsTicker new];
    ticker.animator = self;
    _displayLink = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
    _displayLink.frameInterval = 1;
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    if (_referenceSystemType == RevenantReferenceSystemView) {
        _accuracy = [[(UIView *)_referenceSystem window] screen].scale;
        if (_accuracy == 0)
            _accuracy = 1.0;
    }
    if (_delegateWillResume)
        [_delegate dynamicAnimatorWillResume:self];
}

- (void)_setAlwaysDisableDisplayLink:(BOOL)disable
{
    _disableDisplayLink = disable;
    if (disable)
        [self revenant_stop];
}

- (void)revenant_stop
{
    if (!_displayLink)
        return;
    _lastUpdateTime = 0;
    [_displayLink invalidate];
    _displayLink = nil;
    if (_delegateDidPause)
        [_delegate dynamicAnimatorDidPause:self];
}

#pragma mark Bodies

- (id)revenant_keyForItem:(id<UIDynamicItem>)item
{
    return [NSValue valueWithPointer:(__bridge const void *)item];
}

- (RevenantDynamicsBody *)revenant_bodyForItem:(id<UIDynamicItem>)item
{
    return item ? _bodies[[self revenant_keyForItem:item]] : nil;
}

- (RevenantDynamicsBody *)revenant_registerBodyForItem:(id<UIDynamicItem>)item shape:(RevenantDynamicsShape)shape
{
    BOOL view = [(id)item isKindOfClass:[UIView class]];
    BOOL attributes = [(id)item isKindOfClass:revenant_layout_attributes_class()];
    if (attributes && _referenceSystemType == RevenantReferenceSystemView)
        [NSException raise:NSInvalidArgumentException format:@"Can't use layout attributes as item (%@) in an animator with view reference %@", item, self];
    if (view && _referenceSystemType == RevenantReferenceSystemLayout)
        [NSException raise:NSInvalidArgumentException format:@"Can't use view as item (%@) in an animator with layout reference %@", item, self];
    if (view && _referenceSystemType == RevenantReferenceSystemView && ![(UIView *)item isDescendantOfView:_referenceSystem])
        [NSException raise:NSInvalidArgumentException format:@"View item (%@) should be a descendant of reference view in %@", item, self];
    id key = [self revenant_keyForItem:item];
    RevenantDynamicsBody *body = _bodies[key];
    if (body) {
        if (body.representedObject != item)
            NSLog(@"%@: body %@ without representedObject for item %@", self, body, item);
        body.associations += 1;
        return body;
    }
    CGPoint position = item.center;
    if (view && _referenceSystemType == RevenantReferenceSystemView)
        position = [(UIView *)_referenceSystem convertPoint:position fromView:[(UIView *)item superview]];
    if (view && [item respondsToSelector:@selector(setTranslatesAutoresizingMaskIntoConstraints:)]) {
        UIView *itemView = (UIView *)item;
        NSMutableArray *constraints = [NSMutableArray array];
        for (NSLayoutConstraint *constraint in itemView.superview.constraints) {
            if (constraint.firstItem == itemView || constraint.secondItem == itemView)
                [constraints addObject:constraint];
        }
        [itemView.superview removeConstraints:constraints];
        itemView.translatesAutoresizingMaskIntoConstraints = YES;
    }
    CGSize size = item.bounds.size;
    if (size.width == 0 || size.height == 0)
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:@(__FILE__) lineNumber:__LINE__
                                                       description:@"Invalid size %@ for item %@ in Dynamics", NSStringFromCGSize(size), item];
    body = [[RevenantDynamicsBody alloc] initWithShape:(shape == RevenantDynamicsShapeCircle ? RevenantDynamicsShapeCircle : RevenantDynamicsShapeBox)
                                                size:size vertices:NULL count:0];
    body.associations = 1;
    body.representedObject = item;
    CGAffineTransform transform = item.transform;
    body.rotation = atan2(transform.b, transform.a);
    body.position = position;
    body.affectedByGravity = NO;
    [self revenant_addBody:body];
    _bodies[key] = body;
    [self revenant_tickle];
    return body;
}

- (void)revenant_unregisterBodyForItem:(id<UIDynamicItem>)item action:(void (^)(RevenantDynamicsBody *body))action
{
    id key = [self revenant_keyForItem:item];
    RevenantDynamicsBody *body = _bodies[key];
    if (!body)
        return;
    if (action)
        action(body);
    body.associations -= 1;
    if (body.associations > 0)
        return;
    [self revenant_runBlockPostSolverIfNeeded:^{
        if (body.associations > 0 || self->_bodies[key] != body)
            return;
        [self revenant_removeBody:body];
        [self->_bodies removeObjectForKey:key];
    }];
}

- (RevenantDynamicsBody *)revenant_anchorBodyAtPoint:(CGPoint)point
{
    RevenantDynamicsBody *body = [[RevenantDynamicsBody alloc] initWithShape:RevenantDynamicsShapeNone size:CGSizeZero vertices:NULL count:0];
    body.dynamic = NO;
    body.position = point;
    [self revenant_addBody:body];
    return body;
}

- (RevenantDynamicsBody *)revenant_boundaryBodyFromPoint:(CGPoint)first toPoint:(CGPoint)second
{
    b2Vec2 vertices[2] = {revenant_metres(first), revenant_metres(second)};
    RevenantDynamicsBody *body = [[RevenantDynamicsBody alloc] initWithShape:RevenantDynamicsShapeEdge size:CGSizeZero vertices:vertices count:2];
    body.dynamic = NO;
    return body;
}

- (RevenantDynamicsBody *)revenant_boundaryBodyWithLoop:(const b2Vec2 *)vertices count:(int32)count
{
    RevenantDynamicsBody *body = [[RevenantDynamicsBody alloc] initWithShape:RevenantDynamicsShapeLoop size:CGSizeZero vertices:vertices count:count];
    body.dynamic = NO;
    return body;
}

static CGFloat revenant_rounded(CGFloat value, CGFloat scale)
{
    if (scale == 1)
        return round(value);
    CGFloat whole = floor(value);
    return whole + round(scale * (value - whole)) / scale;
}

- (void)revenant_writeBack:(RevenantDynamicsBody *)body
{
    id<UIDynamicItem> item = body.representedObject;
    CGPoint position = body.position;
    CGFloat angle = body.rotation;
    BOOL view = [(id)item isKindOfClass:[UIView class]];
    NSInteger type = view ? 1 : [(id)item isKindOfClass:revenant_layout_attributes_class()] ? 2 : 0;
    if (view && _referenceSystemType == RevenantReferenceSystemView)
        position = [(UIView *)_referenceSystem convertPoint:position toView:[(UIView *)item superview]];
    if (_integralization != 2 && !(_integralization == 0 && type == 0)) {
        CGPoint center = CGPointMake(revenant_rounded(position.x, _accuracy), revenant_rounded(position.y, _accuracy));
        if (!CGPointEqualToPoint(item.center, center))
            item.center = center;
        item.transform = CGAffineTransformMakeRotation(round(angle * 5000.0) / 5000.0);
    } else {
        item.center = position;
        item.transform = CGAffineTransformMakeRotation(angle);
    }
}

- (BOOL)revenant_isRounded:(id<UIDynamicItem>)item
{
    BOOL object = ![(id)item isKindOfClass:[UIView class]] && ![(id)item isKindOfClass:revenant_layout_attributes_class()];
    return _integralization != 2 && !(_integralization == 0 && object);
}

- (void)updateItemUsingCurrentState:(id<UIDynamicItem>)item
{
    RevenantDynamicsBody *body = [self revenant_bodyForItem:item];
    if (!body)
        return;
    CGPoint center = item.center;
    if ([(id)item isKindOfClass:[UIView class]] && _referenceSystemType == RevenantReferenceSystemView)
        center = [(UIView *)_referenceSystem convertPoint:center fromView:[(UIView *)item superview]];
    CGAffineTransform transform = item.transform;
    CGFloat angle = atan2(transform.b, transform.a);
    if ([self revenant_isRounded:item]) {
        CGPoint current = body.position;
        BOOL samePosition = revenant_rounded(current.x, _accuracy) == revenant_rounded(center.x, _accuracy)
            && revenant_rounded(current.y, _accuracy) == revenant_rounded(center.y, _accuracy);
        BOOL sameAngle = round(body.rotation * 5000.0) / 5000.0 == round(angle * 5000.0) / 5000.0;
        if (sameAngle)
            body.rotation = angle;
        if (!samePosition)
            body.position = center;
        else if (!sameAngle)
            return;
    } else {
        body.position = center;
        body.rotation = angle;
    }
    body.resting = NO;
    [self revenant_tickle];
}

- (NSArray *)itemsInRect:(CGRect)rect
{
    if (!_world)
        return [NSMutableArray array];
    b2AABB box;
    box.lowerBound = b2Vec2((float)(REVENANT_DYNAMICS_INVERSE_PTM * rect.origin.x), (float)(REVENANT_DYNAMICS_INVERSE_PTM * rect.origin.y));
    box.upperBound = box.lowerBound + b2Vec2((float)(rect.size.width * REVENANT_DYNAMICS_INVERSE_PTM), (float)(rect.size.height * REVENANT_DYNAMICS_INVERSE_PTM));
    ItemQuery query;
    _world->QueryAABB(&query, box);
    return query.items;
}

#pragma mark Behaviors

- (void)revenant_checkBehavior:(UIDynamicBehavior *)behavior
{
    if ([_registeredBehaviors containsObject:behavior])
        [NSException raise:NSInvalidArgumentException format:@"Adding the same behavior twice to the same animator is not supported %@", behavior];
}

- (void)addBehavior:(UIDynamicBehavior *)behavior
{
    if (!behavior || [_topLevelBehaviors containsObject:behavior])
        return;
    [self revenant_checkBehavior:behavior];
    [_topLevelBehaviors addObject:behavior];
    [self revenant_registerBehavior:behavior];
}

- (void)removeBehavior:(UIDynamicBehavior *)behavior
{
    if (![_topLevelBehaviors containsObject:behavior])
        return;
    [_topLevelBehaviors removeObject:behavior];
    [self revenant_unregisterBehavior:behavior];
}

- (void)revenant_registerBehavior:(UIDynamicBehavior *)behavior
{
    if (_isInWorldStepMethod) {
        if ([_behaviorsToRemove containsObject:behavior])
            [_behaviorsToRemove removeObject:behavior];
        else
            [(_behaviorsToAdd = _behaviorsToAdd ?: [NSMutableArray new]) addObject:behavior];
        return;
    }
    if (!_world)
        [self revenant_setupWorld];
    [behavior revenant_setContext:self];
    [behavior willMoveToAnimator:self];
    [behavior revenant_associate];
    [_registeredBehaviors addObject:behavior];
    if ([behavior isKindOfClass:[UIDynamicItemBehavior class]])
        [self revenant_shouldReevaluateLocalBehaviors];
    if ([behavior isKindOfClass:[UIGravityBehavior class]]) {
        __block NSUInteger gravities = 0;
        [self revenant_traverseBehaviorHierarchy:^(UIDynamicBehavior *each) {
            if ([each isKindOfClass:[UIGravityBehavior class]])
                gravities += 1;
        }];
        if (gravities >= 2)
            NSLog(@"Multiple gravity behavior per animator is undefined and may assert in the future");
    }
    [self revenant_tickle];
}

- (void)revenant_unregisterBehavior:(UIDynamicBehavior *)behavior
{
    if (!behavior)
        return;
    if (_isInWorldStepMethod) {
        [_behaviorsToAdd removeObject:behavior];
        if ([_registeredBehaviors containsObject:behavior] && ![_behaviorsToRemove containsObject:behavior])
            [(_behaviorsToRemove = _behaviorsToRemove ?: [NSMutableArray new]) addObject:behavior];
        return;
    }
    [behavior revenant_dissociate];
    [behavior revenant_setContext:nil];
    [behavior willMoveToAnimator:nil];
    [_registeredBehaviors removeObject:behavior];
    if ([behavior isKindOfClass:[UIDynamicItemBehavior class]])
        [self revenant_shouldReevaluateLocalBehaviors];
    [self revenant_tickle];
}

- (void)removeAllBehaviors
{
    if (_isInWorldStepMethod) {
        _behaviorsToRemove = _behaviorsToRemove ?: [NSMutableArray new];
        for (UIDynamicBehavior *behavior in _registeredBehaviors) {
            if (![_behaviorsToRemove containsObject:behavior])
                [_behaviorsToRemove addObject:behavior];
        }
        return;
    }
    for (UIDynamicBehavior *behavior in [_registeredBehaviors copy]) {
        [behavior revenant_dissociate];
        [behavior revenant_setContext:nil];
    }
    [_topLevelBehaviors removeAllObjects];
    [_registeredBehaviors removeAllObjects];
}

- (void)revenant_traverseBehaviorHierarchy:(void (^)(UIDynamicBehavior *behavior))block
{
    for (UIDynamicBehavior *behavior in [_topLevelBehaviors copy])
        [self revenant_visitBehavior:behavior block:block];
}

- (void)revenant_visitBehavior:(UIDynamicBehavior *)behavior block:(void (^)(UIDynamicBehavior *behavior))block
{
    block(behavior);
    for (UIDynamicBehavior *child in behavior.childBehaviors)
        [self revenant_visitBehavior:child block:block];
}

- (void)revenant_shouldReevaluateLocalBehaviors
{
    _needsLocalBehaviorReevaluation = YES;
    [self revenant_tickle];
}

- (int)revenant_registerCollisionGroup
{
    return ++_registeredCollisionGroups;
}

- (void)revenant_unregisterCollisionGroup
{
    --_registeredCollisionGroups;
}

- (void)revenant_registerImplicitBounds
{
    ++_registeredImplicitBounds;
}

- (void)revenant_unregisterImplicitBounds
{
    --_registeredImplicitBounds;
}

- (CGRect)revenant_referenceSystemBounds
{
    return _referenceSystemBounds;
}

@end

@interface UIView (RevenantDynamicItem) <UIDynamicItem>
@end

@implementation UIView (RevenantDynamicItem)
@end
