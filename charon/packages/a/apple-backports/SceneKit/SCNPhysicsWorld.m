#import "CharonSCN.h"
#import "../CharonSayOnce.h"

// Nothing steps a simulation here: no SCNPhysicsBody is carried, so there is nothing for gravity, speed, the time
// step, a behavior or the contact delegate to act on. The values are kept as given and read back, and the first
// time an application sets one it is said, once.
static void CharonSCNPhysicsWorldSay(void)
{
    charon_say_once_for(@"SCNPhysicsWorld", @"SCNPhysicsWorld: nothing is simulated on this port; gravity, speed, the time step, "
                                            @"behaviors and the contact delegate are kept and never act");
}

@implementation SCNPhysicsWorld
{
    NSMutableArray<SCNPhysicsBehavior *> *_behaviors;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _gravity = SCNVector3Make(0, -9.8, 0);
        _speed = 1;
        _timeStep = 1.0 / 60.0;
        _behaviors = [NSMutableArray array];
    }
    return self;
}

@synthesize gravity = _gravity;
@synthesize speed = _speed;
@synthesize timeStep = _timeStep;
@synthesize contactDelegate = _contactDelegate;

- (void)setGravity:(SCNVector3)gravity
{
    CharonSCNPhysicsWorldSay();
    _gravity = gravity;
}

- (void)setSpeed:(CGFloat)speed
{
    CharonSCNPhysicsWorldSay();
    _speed = speed;
}

- (void)setTimeStep:(NSTimeInterval)timeStep
{
    CharonSCNPhysicsWorldSay();
    _timeStep = timeStep;
}

// The property is atomic, so its getter is written beside the setter; a weak load is atomic by itself.
- (id<SCNPhysicsContactDelegate>)contactDelegate
{
    return _contactDelegate;
}

- (void)setContactDelegate:(id<SCNPhysicsContactDelegate>)contactDelegate
{
    CharonSCNPhysicsWorldSay();
    _contactDelegate = contactDelegate;
}

- (NSArray<SCNPhysicsBehavior *> *)allBehaviors
{
    return [_behaviors copy];
}

- (void)addBehavior:(SCNPhysicsBehavior *)behavior
{
    CharonSCNPhysicsWorldSay();
    if (behavior && ![_behaviors containsObject:behavior]) {
        [_behaviors addObject:behavior];
    }
}

- (void)removeBehavior:(SCNPhysicsBehavior *)behavior
{
    [_behaviors removeObject:behavior];
}

- (void)removeAllBehaviors
{
    [_behaviors removeAllObjects];
}

- (NSArray<SCNHitTestResult *> *)rayTestWithSegmentFromPoint:(SCNVector3)origin toPoint:(SCNVector3)dest options:(NSDictionary<SCNPhysicsTestOption, id> *)options
{
    return @[];
}

- (NSArray<SCNPhysicsContact *> *)contactTestBetweenBody:(SCNPhysicsBody *)bodyA andBody:(SCNPhysicsBody *)bodyB options:(NSDictionary<SCNPhysicsTestOption, id> *)options
{
    return @[];
}

- (NSArray<SCNPhysicsContact *> *)contactTestWithBody:(SCNPhysicsBody *)body options:(NSDictionary<SCNPhysicsTestOption, id> *)options
{
    return @[];
}

- (NSArray<SCNPhysicsContact *> *)convexSweepTestWithShape:(SCNPhysicsShape *)shape fromTransform:(SCNMatrix4)from toTransform:(SCNMatrix4)to options:(NSDictionary<SCNPhysicsTestOption, id> *)options
{
    return @[];
}

- (void)updateCollisionPairs
{
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        if ([coder containsValueForKey:@"gravity"]) {
            _gravity = [CharonSCNCoding decodeVector3:coder forKey:@"gravity"];
        }
        if ([coder containsValueForKey:@"speed"]) {
            _speed = [coder decodeDoubleForKey:@"speed"];
        }
        if ([coder containsValueForKey:@"timeStep"]) {
            _timeStep = [coder decodeDoubleForKey:@"timeStep"];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [CharonSCNCoding encodeVector3:_gravity coder:coder forKey:@"gravity"];
    [coder encodeDouble:_speed forKey:@"speed"];
    [coder encodeDouble:_timeStep forKey:@"timeStep"];
}

@end
