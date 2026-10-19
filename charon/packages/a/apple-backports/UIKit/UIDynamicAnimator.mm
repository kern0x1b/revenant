#import "CharonDynamics.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

// UIKit Dynamics over unmodified Box2D 2.2.1, the engine iOS 7.0's PhysicsKit is a fork of. The world
// lives here, with the bodies, the contact filter and the contact listener; the behaviors are in their
// own files. Every rule below is iOS 7.0's; facts/UIKit/UIDynamicAnimator.md names the listing or the
// measurement each comes from.
//
// The integrator. 7.0 steps its world in fixed sub-steps of 0.004 s times the speed, while the running
// total exceeds 0.004, carrying fmod(total, 0.004) to the next call, and builds a box 1 pt smaller on
// every side than the item, with a skin of 0.001 m. The host's PhysicsKit, the oracle the differential
// test compares with, sub-steps at (float)1/120 while the accumulator is at least that, and builds the
// box at full size with no skin. The host test builds these sources with CHARON_HOST_DIFFERENTIAL and
// so runs the host's integrator; every other rule is the same on both.

#ifdef CHARON_HOST_DIFFERENTIAL
static const BOOL charon_host_integrator = YES;
#else
static const BOOL charon_host_integrator = NO;
#endif

static const float charon_shape_radius = charon_host_integrator ? 0.0f : 0.001f;

// UICollectionViewLayout and UICollectionViewLayoutAttributes arrive in iOS 6.0, the animator is carried from 4.3.
// Named by symbol they would be weak imports that are NULL below 6.0; looked up by name they are Nil there, where no
// reference system or item can be one of them, and -isKindOfClass: of Nil is NO.
static Class charon_layout_class(void)
{
    return NSClassFromString(@"UICollectionViewLayout");
}

static Class charon_layout_attributes_class(void)
{
    return NSClassFromString(@"UICollectionViewLayoutAttributes");
}

@interface CharonDynamicsBody ()
- (instancetype)initWithShape:(CharonDynamicsShape)shape size:(CGSize)size vertices:(const b2Vec2 *)vertices count:(int32)count;
- (void)charon_attachToWorld:(b2World *)world;
- (void)charon_detachFromWorld;
@end

@implementation CharonDynamicsBody {
    b2Body *_b2Body;
    b2BodyDef _definition;
    CharonDynamicsShape _shape;
    CGSize _size;
    b2Vec2 *_vertices;
    int32 _vertexCount;
    float _density, _fixtureFriction, _fixtureRestitution, _areaFactor;
    BOOL _affectedByGravity;
    CGFloat _charge;
}

@synthesize representedObject = _representedObject, associations = _associations;
@synthesize categoryBitMask = _categoryBitMask, collisionBitMask = _collisionBitMask, contactTestBitMask = _contactTestBitMask;

- (instancetype)initWithShape:(CharonDynamicsShape)shape size:(CGSize)size vertices:(const b2Vec2 *)vertices count:(int32)count
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
    if (shape == CharonDynamicsShapeBox && !charon_host_integrator) {
        // -[PKExtendedPhysicsBody initWithRectangleOfSize:] (7.0): a 2 pt inset, and an area factor
        // so that a density still gives the mass of the full item.
        CGFloat inset = 0.02 / CHARON_DYNAMICS_INVERSE_PTM;
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

- (void)charon_attachToWorld:(b2World *)world
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
    case CharonDynamicsShapeNone:
        return;
    case CharonDynamicsShapeBox:
        box.SetAsBox(0.5f * (float)_size.width * CHARON_DYNAMICS_INVERSE_PTM, 0.5f * (float)_size.height * CHARON_DYNAMICS_INVERSE_PTM);
        box.m_radius = charon_shape_radius;
        fixture.shape = &box;
        break;
    case CharonDynamicsShapeCircle:
        circle.m_radius = 0.5f * (float)_size.width * CHARON_DYNAMICS_INVERSE_PTM;
        fixture.shape = &circle;
        break;
    case CharonDynamicsShapeEdge:
        edge.Set(_vertices[0], _vertices[1]);
        edge.m_radius = charon_shape_radius;
        fixture.shape = &edge;
        break;
    case CharonDynamicsShapeLoop:
        // Box2D 2.2.1's CreateLoop asserts three vertices; for two it would store v0 v1 v0 with v1 on either side,
        // the loop the host builds (items cross it and report contacts, facts/UIKit/UIDynamicAnimator.md M2), so
        // that is built as a chain.
        if (_vertexCount == 2) {
            b2Vec2 closed[3] = {_vertices[0], _vertices[1], _vertices[0]};
            chain.CreateChain(closed, 3);
            chain.SetPrevVertex(_vertices[1]);
            chain.SetNextVertex(_vertices[1]);
        } else {
            chain.CreateLoop(_vertices, _vertexCount);
        }
        chain.m_radius = charon_shape_radius;
        fixture.shape = &chain;
        break;
    }
    _b2Body->CreateFixture(&fixture);
}

- (void)charon_detachFromWorld
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

- (void)charon_refilter
{
    for (b2Fixture *fixture = _b2Body ? _b2Body->GetFixtureList() : NULL; fixture; fixture = fixture->GetNext())
        fixture->Refilter();
}

- (void)setCategoryBitMask:(uint32_t)mask
{
    _categoryBitMask = mask;
    [self charon_refilter];
}

- (void)setCollisionBitMask:(uint32_t)mask
{
    _collisionBitMask = mask;
    [self charon_refilter];
}

- (void)setContactTestBitMask:(uint32_t)mask
{
    _contactTestBitMask = mask;
    [self charon_refilter];
}

- (BOOL)affectedByGravity
{
    return _affectedByGravity;
}

// Box2D 2.2.1 integrates v += h * (gravityScale * gravity + invMass * force): a gravity scale of 1 or
// 0 is PhysicsKit's affectedByGravity flag.
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
    return charon_points(_b2Body ? _b2Body->GetPosition() : _definition.position);
}

- (void)setPosition:(CGPoint)position
{
    _definition.position = charon_metres(position);
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
    return charon_points(_b2Body ? _b2Body->GetLinearVelocity() : _definition.linearVelocity);
}

- (void)setVelocity:(CGPoint)velocity
{
    _definition.linearVelocity = charon_metres(velocity);
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

- (b2Fixture *)charon_fixture
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
    if (b2Fixture *fixture = [self charon_fixture])
        fixture->SetRestitution(_fixtureRestitution);
}

- (CGFloat)friction
{
    return _fixtureFriction;
}

- (void)setFriction:(CGFloat)friction
{
    _fixtureFriction = (float)friction;
    if (b2Fixture *fixture = [self charon_fixture])
        fixture->SetFriction(_fixtureFriction);
}

- (CGFloat)normalizedDensity
{
    return _density / _areaFactor;
}

- (void)setNormalizedDensity:(CGFloat)density
{
    _density = (float)density * _areaFactor;
    if (b2Fixture *fixture = [self charon_fixture]) {
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

// SetFixedRotation only toggles the flag and resets the mass data: a spin the body has goes on, as
// on 7.0.
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
        _b2Body->ApplyForce(b2Vec2((float)force.dx, (float)force.dy), charon_metres(point));
}

- (void)applyImpulse:(CGVector)impulse
{
    if (_b2Body)
        _b2Body->ApplyLinearImpulse(b2Vec2((float)impulse.dx, (float)impulse.dy), _b2Body->GetWorldCenter());
}

- (void)applyImpulse:(CGVector)impulse atPoint:(CGPoint)point
{
    if (_b2Body)
        _b2Body->ApplyLinearImpulse(b2Vec2((float)impulse.dx, (float)impulse.dy), charon_metres(point));
}

@end

@interface CharonDynamicsContact ()
@property (nonatomic, readwrite) CharonDynamicsBody *bodyA;
@property (nonatomic, readwrite) CharonDynamicsBody *bodyB;
@property (nonatomic, readwrite) CGPoint contactPoint;
@property (nonatomic) BOOL beganDelivered;
@property (nonatomic) BOOL ended;
@end

@implementation CharonDynamicsContact
@synthesize bodyA = _bodyA, bodyB = _bodyB, contactPoint = _contactPoint, beganDelivered = _beganDelivered, ended = _ended;
@end

namespace {

CharonDynamicsBody *body_of(b2Fixture *fixture)
{
    return (__bridge CharonDynamicsBody *)fixture->GetBody()->GetUserData();
}

// PhysicsKit's masks work as SpriteKit's: two bodies are in contact when either one's category is in
// the other's collision mask.
class ContactFilter : public b2ContactFilter {
public:
    bool ShouldCollide(b2Fixture *fixtureA, b2Fixture *fixtureB)
    {
        CharonDynamicsBody *a = body_of(fixtureA), *b = body_of(fixtureB);
        return (a.categoryBitMask & b.collisionBitMask) || (b.categoryBitMask & a.collisionBitMask);
    }
};

// Contacts are recorded while the world steps and handed to the animator after the last sub-step, so
// that no delegate runs inside b2World::Step. A body responds to a contact only when the other's
// category is in its collision mask; a contact no dynamic body responds to is still reported, and
// disabled.
class ContactListener : public b2ContactListener {
public:
    NSMutableArray *records = [NSMutableArray array];
    // b2Contact pointers, not objects, as keys: opaque, so that nothing sends them retain.
    NSMapTable *live = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                             valueOptions:NSPointerFunctionsStrongMemory];

    void BeginContact(b2Contact *contact)
    {
        CharonDynamicsContact *record = [CharonDynamicsContact new];
        record.bodyA = body_of(contact->GetFixtureA());
        record.bodyB = body_of(contact->GetFixtureB());
        [records addObject:record];
        [live setObject:record forKey:(__bridge id)(void *)contact];
    }

    void EndContact(b2Contact *contact)
    {
        CharonDynamicsContact *record = [live objectForKey:(__bridge id)(void *)contact];
        record.ended = YES;
        [live removeObjectForKey:(__bridge id)(void *)contact];
    }

    void PreSolve(b2Contact *contact, const b2Manifold *)
    {
        CharonDynamicsBody *a = body_of(contact->GetFixtureA()), *b = body_of(contact->GetFixtureB());
        bool respondsA = contact->GetFixtureA()->GetBody()->GetType() == b2_dynamicBody && (b.categoryBitMask & a.collisionBitMask);
        bool respondsB = contact->GetFixtureB()->GetBody()->GetType() == b2_dynamicBody && (a.categoryBitMask & b.collisionBitMask);
        if (!respondsA && !respondsB)
            contact->SetEnabled(false);
    }

    void PostSolve(b2Contact *contact, const b2ContactImpulse *impulse)
    {
        CharonDynamicsContact *record = [live objectForKey:(__bridge id)(void *)contact];
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
        record.contactPoint = charon_points(manifold.points[strongest]);
    }
};

class ItemQuery : public b2QueryCallback {
public:
    NSMutableArray *items = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    bool ReportFixture(b2Fixture *fixture)
    {
        CharonDynamicsBody *body = body_of(fixture);
        if (![seen containsObject:body]) {
            [seen addObject:body];
            if (body.representedObject)
                [items addObject:body.representedObject];
        }
        return true;
    }
};

} // namespace

typedef NS_ENUM(NSInteger, CharonReferenceSystem) {
    CharonReferenceSystemNone,
    CharonReferenceSystemView,
    CharonReferenceSystemLayout,
};

@interface CharonDynamicsTicker : NSObject
@property (nonatomic, weak) UIDynamicAnimator *animator;
@end

@interface UIDynamicAnimator (CharonDynamicsTick)
- (void)charon_displayLinkTick:(CADisplayLink *)link;
@end

@implementation CharonDynamicsTicker
@synthesize animator = _animator;

- (void)tick:(CADisplayLink *)link
{
    [self.animator charon_displayLinkTick:link];
}

@end

@interface UIDynamicAnimator (CharonReferenceView)
- (void)charon_tickle;
@end

// +[UIDynamicAnimator _registerAnimator:] and +_referenceViewSizeChanged: (7.0, facts/UIKit/UIDynamicAnimator.md §9):
// animators made on the main thread are listed, and 7.0's -[UIView setFrame:] and -setBounds: wake those whose
// reference view's bounds size they changed. Autoresizing and Auto Layout reach it through the two setters; a
// layer-level resize, center and transform do not (facts/UIKit/UIDynamicAnimator.md M3). iOS 6's setters tell no one, but
// they are KVO-compliant, and KVO of frame and bounds together fires on exactly the calls that wake on 7.0 (measured on
// 6.1.3, M3). The observer is an object the reference view holds (an associated object), so it goes with the view: an
// observer left on a view that deallocates is leaked by KVO with a log line (measured, M3). The list does not retain: an
// animator leaves it in its -dealloc.
static CFMutableArrayRef charon_animators;
static char charon_watch_key;

static void charon_reference_view_size_changed(UIView *view)
{
    for (CFIndex index = 0; index < CFArrayGetCount(charon_animators); index++) {
        UIDynamicAnimator *animator = (__bridge UIDynamicAnimator *)CFArrayGetValueAtIndex(charon_animators, index);
        if (animator.referenceView == view)
            [animator charon_tickle];
    }
}

// Observes a reference view's frame and bounds until it is deallocated or an animator drops it. The prior notification
// reads the bounds size before the setter changes it, the notification after compares: 7.0's own test.
@interface CharonReferenceViewWatch : NSObject
- (instancetype)initWithView:(UIView *)view;
@end

@implementation CharonReferenceViewWatch {
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
        charon_reference_view_size_changed(_view);
}

// Runs from the view's own deallocation when the view holds this object last.
- (void)dealloc
{
    [_view removeObserver:self forKeyPath:@"frame"];
    [_view removeObserver:self forKeyPath:@"bounds"];
}

@end

static void charon_register_animator(UIDynamicAnimator *animator)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_animators = CFArrayCreateMutable(NULL, 0, NULL);
    });
    CFArrayAppendValue(charon_animators, (__bridge const void *)animator);
    UIView *view = animator.referenceView;
    if (view && !objc_getAssociatedObject(view, &charon_watch_key))
        objc_setAssociatedObject(view, &charon_watch_key, [[CharonReferenceViewWatch alloc] initWithView:view], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void charon_unregister_animator(UIDynamicAnimator *animator)
{
    if (!charon_animators)
        return;
    CFIndex index = CFArrayGetFirstIndexOfValue(charon_animators, CFRangeMake(0, CFArrayGetCount(charon_animators)), (__bridge const void *)animator);
    if (index == kCFNotFound)
        return;
    CFArrayRemoveValueAtIndex(charon_animators, index);
    UIView *view = animator.referenceView;
    if (!view)
        return;
    for (index = 0; index < CFArrayGetCount(charon_animators); index++)
        if (((__bridge UIDynamicAnimator *)CFArrayGetValueAtIndex(charon_animators, index)).referenceView == view)
            return;
    objc_setAssociatedObject(view, &charon_watch_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIDynamicAnimator {
    b2World *_world;
    ContactFilter *_contactFilter;
    ContactListener *_contactListener;
    NSMutableArray *_worldBodies;
    double _accumulatedDt;
    float _speed;
    __weak id _referenceSystem;
    CharonReferenceSystem _referenceSystemType;
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
    return [self charon_initWithReferenceSystem:nil];
}

- (instancetype)initWithReferenceView:(UIView *)view
{
    return [self charon_initWithReferenceSystem:view];
}

- (instancetype)charon_initWithReferenceSystem:(id)system __attribute__((objc_method_family(init)))
{
    if (!(self = [super init]))
        return nil;
    _referenceSystem = system;
    if ([system isKindOfClass:[UIView class]]) {
        _referenceSystemType = CharonReferenceSystemView;
        _referenceSystemBounds = [system bounds];
    } else if ([system isKindOfClass:charon_layout_class()]) {
        _referenceSystemType = CharonReferenceSystemLayout;
        _referenceSystemBounds = [self charon_layoutBounds];
    } else {
        _referenceSystemType = CharonReferenceSystemNone;
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
        charon_register_animator(self);
    return self;
}

// Dissociating the behaviors below tickles the animator, which would start a display link whose ticker holds a
// weak reference to an animator already deallocating; nothing restarts it from here on. A behavior reads the animator
// through -charon_context, which returns it retained and autoreleased (below iOS 5 nothing cancels the pair), so the
// dissociation has a pool of its own: the animator is released while it is still there, not by a pool that drains
// after it is freed.
- (void)dealloc
{
    _deallocating = YES;
    charon_unregister_animator(self);
    [_displayLink invalidate];
    @autoreleasepool {
        for (UIDynamicBehavior *behavior in [_registeredBehaviors copy]) {
            [behavior charon_dissociate];
            [behavior charon_setContext:nil];
        }
    }
    delete _world;
    delete _contactFilter;
    delete _contactListener;
}

// 7.0's private -[UICollectionViewLayout bounds], which 6.x does not have: the content, at the origin.
- (CGRect)charon_layoutBounds
{
    UICollectionViewLayout *layout = _referenceSystem;
    CGSize size = [layout collectionViewContentSize];
    return CGRectMake(0, 0, size.width, size.height);
}

// "<UIDynamicAnimator: 0x…> Stopped (0.250000s) in <UIView: 0x…> {{0, 0}, {400, 300}}": "Stopped " only while no display
// link runs, the elapsed time, the reference system (a nil one reads "<(null): 0x0>") and its bounds, which are
// CGRectNull without one. Measured on the host; the reference-system exceptions end with it, and the host test's T9
// holds their full text to the host's (tests/backports/host/dynamics/structure_test.m).
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> %@(%fs) in <%@: %p> %@", [self class], self, self.running ? @"" : @"Stopped ",
            _elapsedTime, [_referenceSystem class], _referenceSystem, NSStringFromCGRect(_referenceSystemBounds)];
}

- (UIView *)referenceView
{
    return _referenceSystemType == CharonReferenceSystemView ? _referenceSystem : nil;
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

// The delegate is asked what it implements when it is set, and not again.
- (void)setDelegate:(id<UIDynamicAnimatorDelegate>)delegate
{
    _delegate = delegate;
    _delegateWillResume = [delegate respondsToSelector:@selector(dynamicAnimatorWillResume:)];
    _delegateDidPause = [delegate respondsToSelector:@selector(dynamicAnimatorDidPause:)];
}

#pragma mark World

- (b2World *)charon_world
{
    return _world;
}

- (void)charon_setupWorld
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

- (void)charon_setWorldGravity:(CGVector)gravity
{
    if (_world)
        _world->SetGravity(b2Vec2((float)(gravity.dx * 10.0), (float)(gravity.dy * 10.0)));
}

- (void)charon_addBody:(CharonDynamicsBody *)body
{
    if (!_world || body.b2Body)
        return;
    [body charon_attachToWorld:_world];
    [_worldBodies addObject:body];
}

- (void)charon_removeBody:(CharonDynamicsBody *)body
{
    if (!body.b2Body)
        return;
    [body charon_detachFromWorld];
    [_worldBodies removeObjectIdenticalTo:body];
}

// -[PKPhysicsWorld stepWithTime:velocityIterations:positionIterations:] (7.0): fixed sub-steps, then
// the contacts, then the forces cleared once, then every body written back. Answers whether a
// dynamic body is still awake.
- (BOOL)charon_stepWorld:(double)dt
{
    if (_world->GetBodyCount() == 0)
        return NO;
    float step = (float)dt;
    if (!(step > 0.0f) || fabsf(step) < 0x1p-63f)
        return YES;
    if (charon_host_integrator) {
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
    [self charon_flushContacts];
    _world->ClearForces();
    BOOL resting = YES;
    for (CharonDynamicsBody *body in [_worldBodies copy]) {
        if (body.representedObject)
            [self charon_writeBack:body];
        if (body.dynamic)
            resting = resting && body.resting;
    }
    return !resting;
}

- (void)charon_flushContacts
{
    NSMutableArray *records = _contactListener->records;
    for (CharonDynamicsContact *record in [records copy]) {
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

- (void)charon_displayLinkTick:(CADisplayLink *)link
{
    CFTimeInterval dt = link.timestamp - _lastUpdateTime;
    if (dt > 0.5)
        dt = 1.0 / 60.0;
    _realElapsedTime += dt;
    BOOL awake = [self charon_animatorStep:dt];
    _lastUpdateTime = link.timestamp;
    if (!awake)
        [self charon_stop];
}

- (CGRect)charon_currentReferenceBounds
{
    if (_referenceSystemType == CharonReferenceSystemLayout)
        return [self charon_layoutBounds];
    return [_referenceSystem bounds];
}

- (BOOL)charon_animatorStep:(double)dt
{
    _ticks += 1;
    _elapsedTime += dt;
    [self charon_preSolverStep];
    _isInWorldStepMethod = YES;
    BOOL awake = [self charon_stepWorld:dt];
    _isInWorldStepMethod = NO;
    [self charon_postSolverStep];
    if (_referenceSystemType == CharonReferenceSystemLayout)
        [(UICollectionViewLayout *)_referenceSystem invalidateLayout];
    return awake;
}

- (void)charon_preSolverStep
{
    if (_needsLocalBehaviorReevaluation) {
        _needsLocalBehaviorReevaluation = NO;
        [self charon_traverseBehaviorHierarchy:^(UIDynamicBehavior *behavior) {
            [behavior charon_reevaluate:0];
        }];
    }
    id system = _referenceSystem;
    if (_registeredImplicitBounds >= 1 && system && !CGRectEqualToRect(_referenceSystemBounds, [self charon_currentReferenceBounds])) {
        if (_referenceSystemType == CharonReferenceSystemView)
            _referenceSystemBounds = [[(UIView *)system layer] presentationLayer].bounds;
        else
            _referenceSystemBounds = [self charon_currentReferenceBounds];
        [self charon_traverseBehaviorHierarchy:^(UIDynamicBehavior *behavior) {
            if ([behavior isKindOfClass:[UICollisionBehavior class]] && [(UICollisionBehavior *)behavior charon_usesImplicitBounds])
                [(UICollisionBehavior *)behavior charon_reevaluateImplicitBounds];
        }];
    }
    for (UIDynamicBehavior *behavior in [_registeredBehaviors copy])
        [behavior charon_step];
}

- (void)charon_postSolverStep
{
    _isInWorldStepMethod = YES;
    [self charon_reportContacts:_beginContacts began:YES];
    [self charon_reportContacts:_endContacts began:NO];
    for (UIDynamicBehavior *behavior in [_registeredBehaviors copy]) {
        if (behavior.action)
            behavior.action();
    }
    BOOL stoppable = YES;
    for (UIDynamicBehavior *behavior in _topLevelBehaviors) {
        if (![behavior charon_allowsAnimatorToStop]) {
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
        [self charon_unregisterBehavior:behavior];
    for (UIDynamicBehavior *behavior in adding)
        [self charon_registerBehavior:behavior];
    if (stoppable || _registeredBehaviors.count == 0)
        [self charon_stop];
}

- (void)charon_reportContacts:(NSMutableArray *)contacts began:(BOOL)began
{
    NSArray *delivered = [contacts copy];
    [contacts removeAllObjects];
    if (delivered.count == 0)
        return;
    [self charon_traverseBehaviorHierarchy:^(UIDynamicBehavior *behavior) {
        if (![behavior isKindOfClass:[UICollisionBehavior class]])
            return;
        for (CharonDynamicsContact *contact in delivered) {
            if (began)
                [(UICollisionBehavior *)behavior charon_didBeginContact:contact];
            else
                [(UICollisionBehavior *)behavior charon_didEndContact:contact];
        }
    }];
}

- (void)charon_runBlockPostSolverIfNeeded:(dispatch_block_t)block
{
    if (_isInWorldStepMethod)
        [_postSolverActions addObject:[block copy]];
    else
        block();
}

#pragma mark Running

- (void)charon_tickle
{
    if (!self.running && _bodies.count != 0)
        [self charon_start];
}

- (void)charon_start
{
    if ((_referenceSystemType == CharonReferenceSystemView && !_referenceSystem) || _displayLink || _disableDisplayLink || _deallocating)
        return;
    _lastUpdateTime = CACurrentMediaTime();
    CharonDynamicsTicker *ticker = [CharonDynamicsTicker new];
    ticker.animator = self;
    _displayLink = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
    _displayLink.frameInterval = 1;
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    if (_referenceSystemType == CharonReferenceSystemView) {
        _accuracy = [[(UIView *)_referenceSystem window] screen].scale;
        if (_accuracy == 0)
            _accuracy = 1.0;
    }
    if (_delegateWillResume)
        [_delegate dynamicAnimatorWillResume:self];
}

// 7.0's own private switch (facts/UIKit/UIDynamicAnimator.md §1.6): an animator that never starts a display link, so
// only an explicit step moves it, and no delegate hears a resume. The host test sets it on both animators to step
// them by hand.
- (void)_setAlwaysDisableDisplayLink:(BOOL)disable
{
    _disableDisplayLink = disable;
    if (disable)
        [self charon_stop];
}

- (void)charon_stop
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

- (id)charon_keyForItem:(id<UIDynamicItem>)item
{
    return [NSValue valueWithPointer:(__bridge const void *)item];
}

- (CharonDynamicsBody *)charon_bodyForItem:(id<UIDynamicItem>)item
{
    return item ? _bodies[[self charon_keyForItem:item]] : nil;
}

// -[UIDynamicAnimator _registerBodyForItem:shape:] (7.0): one body per item and animator, shared by
// every behavior that holds the item and counted by them.
- (CharonDynamicsBody *)charon_registerBodyForItem:(id<UIDynamicItem>)item shape:(CharonDynamicsShape)shape
{
    BOOL view = [(id)item isKindOfClass:[UIView class]];
    BOOL attributes = [(id)item isKindOfClass:charon_layout_attributes_class()];
    if (attributes && _referenceSystemType == CharonReferenceSystemView)
        [NSException raise:NSInvalidArgumentException format:@"Can't use layout attributes as item (%@) in an animator with view reference %@", item, self];
    if (view && _referenceSystemType == CharonReferenceSystemLayout)
        [NSException raise:NSInvalidArgumentException format:@"Can't use view as item (%@) in an animator with layout reference %@", item, self];
    if (view && _referenceSystemType == CharonReferenceSystemView && ![(UIView *)item isDescendantOfView:_referenceSystem])
        [NSException raise:NSInvalidArgumentException format:@"View item (%@) should be a descendant of reference view in %@", item, self];
    id key = [self charon_keyForItem:item];
    CharonDynamicsBody *body = _bodies[key];
    if (body) {
        if (body.representedObject != item)
            NSLog(@"%@: body %@ without representedObject for item %@", self, body, item);
        body.associations += 1;
        return body;
    }
    CGPoint position = item.center;
    if (view && _referenceSystemType == CharonReferenceSystemView)
        position = [(UIView *)_referenceSystem convertPoint:position fromView:[(UIView *)item superview]];
    // Auto Layout arrived in iOS 6.0: below it a view has no constraints to take the item out of and no switch to set.
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
    body = [[CharonDynamicsBody alloc] initWithShape:(shape == CharonDynamicsShapeCircle ? CharonDynamicsShapeCircle : CharonDynamicsShapeBox)
                                                size:size vertices:NULL count:0];
    body.associations = 1;
    body.representedObject = item;
    CGAffineTransform transform = item.transform;
    body.rotation = atan2(transform.b, transform.a);
    body.position = position;
    body.affectedByGravity = NO;
    [self charon_addBody:body];
    _bodies[key] = body;
    [self charon_tickle];
    return body;
}

- (void)charon_unregisterBodyForItem:(id<UIDynamicItem>)item action:(void (^)(CharonDynamicsBody *body))action
{
    id key = [self charon_keyForItem:item];
    CharonDynamicsBody *body = _bodies[key];
    if (!body)
        return;
    if (action)
        action(body);
    body.associations -= 1;
    if (body.associations > 0)
        return;
    [self charon_runBlockPostSolverIfNeeded:^{
        if (body.associations > 0 || self->_bodies[key] != body)
            return;
        [self charon_removeBody:body];
        [self->_bodies removeObjectForKey:key];
    }];
}

- (CharonDynamicsBody *)charon_anchorBodyAtPoint:(CGPoint)point
{
    CharonDynamicsBody *body = [[CharonDynamicsBody alloc] initWithShape:CharonDynamicsShapeNone size:CGSizeZero vertices:NULL count:0];
    body.dynamic = NO;
    body.position = point;
    [self charon_addBody:body];
    return body;
}

- (CharonDynamicsBody *)charon_boundaryBodyFromPoint:(CGPoint)first toPoint:(CGPoint)second
{
    b2Vec2 vertices[2] = {charon_metres(first), charon_metres(second)};
    CharonDynamicsBody *body = [[CharonDynamicsBody alloc] initWithShape:CharonDynamicsShapeEdge size:CGSizeZero vertices:vertices count:2];
    body.dynamic = NO;
    return body;
}

- (CharonDynamicsBody *)charon_boundaryBodyWithLoop:(const b2Vec2 *)vertices count:(int32)count
{
    CharonDynamicsBody *body = [[CharonDynamicsBody alloc] initWithShape:CharonDynamicsShapeLoop size:CGSizeZero vertices:vertices count:count];
    body.dynamic = NO;
    return body;
}

static CGFloat charon_rounded(CGFloat value, CGFloat scale)
{
    if (scale == 1)
        return round(value);
    CGFloat whole = floor(value);
    return whole + round(scale * (value - whole)) / scale;
}

// -[UIDynamicAnimator _defaultMapper:position:angle:itemType:] (7.0): a view's center to the pixel and
// its angle to 1/5000 rad, a plain item exactly; the transform is replaced by the body's rotation.
- (void)charon_writeBack:(CharonDynamicsBody *)body
{
    id<UIDynamicItem> item = body.representedObject;
    CGPoint position = body.position;
    CGFloat angle = body.rotation;
    BOOL view = [(id)item isKindOfClass:[UIView class]];
    NSInteger type = view ? 1 : [(id)item isKindOfClass:charon_layout_attributes_class()] ? 2 : 0;
    if (view && _referenceSystemType == CharonReferenceSystemView)
        position = [(UIView *)_referenceSystem convertPoint:position toView:[(UIView *)item superview]];
    if (_integralization != 2 && !(_integralization == 0 && type == 0)) {
        CGPoint center = CGPointMake(charon_rounded(position.x, _accuracy), charon_rounded(position.y, _accuracy));
        if (!CGPointEqualToPoint(item.center, center))
            item.center = center;
        item.transform = CGAffineTransformMakeRotation(round(angle * 5000.0) / 5000.0);
    } else {
        item.center = position;
        item.transform = CGAffineTransformMakeRotation(angle);
    }
}

- (BOOL)charon_isRounded:(id<UIDynamicItem>)item
{
    BOOL object = ![(id)item isKindOfClass:[UIView class]] && ![(id)item isKindOfClass:charon_layout_attributes_class()];
    return _integralization != 2 && !(_integralization == 0 && object);
}

// A view's body keeps a rotation within the same 1/5000 rad and a center within the same pixel: 7.0
// compares them rounded, and moves the body only when the center differs.
- (void)updateItemUsingCurrentState:(id<UIDynamicItem>)item
{
    CharonDynamicsBody *body = [self charon_bodyForItem:item];
    if (!body)
        return;
    CGPoint center = item.center;
    if ([(id)item isKindOfClass:[UIView class]] && _referenceSystemType == CharonReferenceSystemView)
        center = [(UIView *)_referenceSystem convertPoint:center fromView:[(UIView *)item superview]];
    CGAffineTransform transform = item.transform;
    CGFloat angle = atan2(transform.b, transform.a);
    if ([self charon_isRounded:item]) {
        CGPoint current = body.position;
        BOOL samePosition = charon_rounded(current.x, _accuracy) == charon_rounded(center.x, _accuracy)
            && charon_rounded(current.y, _accuracy) == charon_rounded(center.y, _accuracy);
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
    [self charon_tickle];
}

- (NSArray *)itemsInRect:(CGRect)rect
{
    if (!_world)
        return [NSMutableArray array];
    b2AABB box;
    box.lowerBound = b2Vec2((float)(CHARON_DYNAMICS_INVERSE_PTM * rect.origin.x), (float)(CHARON_DYNAMICS_INVERSE_PTM * rect.origin.y));
    box.upperBound = box.lowerBound + b2Vec2((float)(rect.size.width * CHARON_DYNAMICS_INVERSE_PTM), (float)(rect.size.height * CHARON_DYNAMICS_INVERSE_PTM));
    ItemQuery query;
    _world->QueryAABB(&query, box);
    return query.items;
}

#pragma mark Behaviors

- (void)charon_checkBehavior:(UIDynamicBehavior *)behavior
{
    if ([_registeredBehaviors containsObject:behavior])
        [NSException raise:NSInvalidArgumentException format:@"Adding the same behavior twice to the same animator is not supported %@", behavior];
}

- (void)addBehavior:(UIDynamicBehavior *)behavior
{
    if (!behavior || [_topLevelBehaviors containsObject:behavior])
        return;
    [self charon_checkBehavior:behavior];
    [_topLevelBehaviors addObject:behavior];
    [self charon_registerBehavior:behavior];
}

- (void)removeBehavior:(UIDynamicBehavior *)behavior
{
    if (![_topLevelBehaviors containsObject:behavior])
        return;
    [_topLevelBehaviors removeObject:behavior];
    [self charon_unregisterBehavior:behavior];
}

- (void)charon_registerBehavior:(UIDynamicBehavior *)behavior
{
    if (_isInWorldStepMethod) {
        if ([_behaviorsToRemove containsObject:behavior])
            [_behaviorsToRemove removeObject:behavior];
        else
            [(_behaviorsToAdd = _behaviorsToAdd ?: [NSMutableArray new]) addObject:behavior];
        return;
    }
    if (!_world)
        [self charon_setupWorld];
    [behavior charon_setContext:self];
    [behavior willMoveToAnimator:self];
    [behavior charon_associate];
    [_registeredBehaviors addObject:behavior];
    if ([behavior isKindOfClass:[UIDynamicItemBehavior class]])
        [self charon_shouldReevaluateLocalBehaviors];
    if ([behavior isKindOfClass:[UIGravityBehavior class]]) {
        __block NSUInteger gravities = 0;
        [self charon_traverseBehaviorHierarchy:^(UIDynamicBehavior *each) {
            if ([each isKindOfClass:[UIGravityBehavior class]])
                gravities += 1;
        }];
        if (gravities >= 2)
            NSLog(@"Multiple gravity behavior per animator is undefined and may assert in the future");
    }
    [self charon_tickle];
}

- (void)charon_unregisterBehavior:(UIDynamicBehavior *)behavior
{
    if (!behavior)
        return;
    // 7.0 (and the host) queue only a registered behavior inside a step, and outside one unregister whatever they are
    // given: a behavior removeAllBehaviors already dissociated is dissociated again, with no context
    // (facts/UIKit/UIDynamicAnimator.md M1).
    if (_isInWorldStepMethod) {
        [_behaviorsToAdd removeObject:behavior];
        if ([_registeredBehaviors containsObject:behavior] && ![_behaviorsToRemove containsObject:behavior])
            [(_behaviorsToRemove = _behaviorsToRemove ?: [NSMutableArray new]) addObject:behavior];
        return;
    }
    [behavior charon_dissociate];
    [behavior charon_setContext:nil];
    [behavior willMoveToAnimator:nil];
    [_registeredBehaviors removeObject:behavior];
    if ([behavior isKindOfClass:[UIDynamicItemBehavior class]])
        [self charon_shouldReevaluateLocalBehaviors];
    [self charon_tickle];
}

- (void)removeAllBehaviors
{
    // Inside a step every registered behavior is queued and animator.behaviors is left as it is
    // (facts/UIKit/UIDynamicAnimator.md M1).
    if (_isInWorldStepMethod) {
        _behaviorsToRemove = _behaviorsToRemove ?: [NSMutableArray new];
        for (UIDynamicBehavior *behavior in _registeredBehaviors) {
            if (![_behaviorsToRemove containsObject:behavior])
                [_behaviorsToRemove addObject:behavior];
        }
        return;
    }
    for (UIDynamicBehavior *behavior in [_registeredBehaviors copy]) {
        [behavior charon_dissociate];
        [behavior charon_setContext:nil];
    }
    [_topLevelBehaviors removeAllObjects];
    [_registeredBehaviors removeAllObjects];
}

// Depth first, in the order of animator.behaviors, each behavior before its children.
- (void)charon_traverseBehaviorHierarchy:(void (^)(UIDynamicBehavior *behavior))block
{
    for (UIDynamicBehavior *behavior in [_topLevelBehaviors copy])
        [self charon_visitBehavior:behavior block:block];
}

- (void)charon_visitBehavior:(UIDynamicBehavior *)behavior block:(void (^)(UIDynamicBehavior *behavior))block
{
    block(behavior);
    for (UIDynamicBehavior *child in behavior.childBehaviors)
        [self charon_visitBehavior:child block:block];
}

- (void)charon_shouldReevaluateLocalBehaviors
{
    _needsLocalBehaviorReevaluation = YES;
    [self charon_tickle];
}

- (int)charon_registerCollisionGroup
{
    return ++_registeredCollisionGroups;
}

- (void)charon_unregisterCollisionGroup
{
    --_registeredCollisionGroups;
}

- (void)charon_registerImplicitBounds
{
    ++_registeredImplicitBounds;
}

- (void)charon_unregisterImplicitBounds
{
    --_registeredImplicitBounds;
}

- (CGRect)charon_referenceSystemBounds
{
    return _referenceSystemBounds;
}

@end

// 7.0's UIView adopts UIDynamicItem; its three required members are UIView's own since 2.0, and it implements none of
// the 9.0 optional ones (measured on 6.1.3, 7.0, 8.4.1 and 9.0: facts/UIKit/UIDynamicAnimator.md §10). The conformance
// lives with the animator, so a band whose release carries UIKit Dynamics, and with it the conformance, leaves it
// out with the class.
@interface UIView (CharonDynamicItem) <UIDynamicItem>
@end

@implementation UIView (CharonDynamicItem)
@end
