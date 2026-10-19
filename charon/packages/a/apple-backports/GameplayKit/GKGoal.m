// GKGoal.m -- the twelve things an agent can be asked to do. GameplayKit.framework carries no code at
// all before iOS 9 (GK_BASE_AVAILABILITY is NS_CLASS_AVAILABLE(10_11, 9_0) and the 6.1.3 armv7 cache
// exports no GameplayKit class), so this is this port's own. A goal's own surface is its factories
// and its copy: an application builds one, hands it to a behaviour with a weight, and an agent reads
// it, and nothing else of a goal is public. So what a goal holds here is the kind its factory names
// and the arguments it was given, and GKAgent reads them back through -charon_kind and the accessors
// below when it decides what to do with the goals in a behaviour.
//
// The arguments a goal carries, by kind:
//   seek, flee and
//   intercept            one agent, and nil for one of those three is what the host refuses
//   avoid obstacles     a list of obstacles and the longest time to look ahead
//   avoid agents        a list of agents and the longest time to look ahead
//   separate, align,
//   cohere              a list of agents, the distance beyond which an agent is ignored, and the
//                       angle beyond which its direction of travel is ignored
//   target speed        one speed
//   wander              one speed
//   intercept           one agent and the longest time to look ahead
//   follow path         a path, the longest time to look ahead, and whether to follow it forwards
//   stay on path        a path and the longest time to look ahead
//
// Every selector below but -copyWithZone: is one the SDK's GKGoal.h declares, and -copyWithZone: is
// the NSCopying member it adopts. Nothing here is a property, so there is nothing for
// -Wobjc-missing-property-synthesis to say and no pragma says otherwise.

#import "CharonGK.h"

@implementation GKGoal {
    CharonGKGoalKind _kind;
    GKAgent *_agent;
    NSArray<GKObstacle *> *_obstacles;
    NSArray<GKAgent *> *_agents;
    GKPath *_path;
    NSTimeInterval _maxPredictionTime;
    float _value;
    float _maxDistance;
    float _maxAngle;
    BOOL _forward;
}

+ (instancetype)charon_goalOfKind:(CharonGKGoalKind)kind
{
    return [[self alloc] initWithCharonKind:kind];
}

- (instancetype)initWithCharonKind:(CharonGKGoalKind)kind
{
    self = [super init];
    if (self) {
        _kind = kind;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithCharonKind:CharonGKGoalWander];
}

- (CharonGKGoalKind)charon_kind
{
    return _kind;
}

- (GKAgent *)charon_agent
{
    return _agent;
}

- (NSArray<GKObstacle *> *)charon_obstacles
{
    return _obstacles;
}

- (NSArray<GKAgent *> *)charon_agents
{
    return _agents;
}

- (GKPath *)charon_path
{
    return _path;
}

- (NSTimeInterval)charon_maxPredictionTime
{
    return _maxPredictionTime;
}

- (float)charon_value
{
    return _value;
}

- (float)charon_maxDistance
{
    return _maxDistance;
}

- (float)charon_maxAngle
{
    return _maxAngle;
}

- (BOOL)charon_forward
{
    return _forward;
}

+ (instancetype)goalToSeekAgent:(GKAgent *)agent
{
    return [self charon_goalWithAgent:agent kind:CharonGKGoalSeek];
}

+ (instancetype)goalToFleeAgent:(GKAgent *)agent
{
    return [self charon_goalWithAgent:agent kind:CharonGKGoalFlee];
}

// The three factories that take ONE agent -- seek, flee and intercept -- are the three that refuse a
// nil one, with NSInvalidArgumentException: the host keeps the agent in a one-element list and
// building that list with nothing in it is what raises, so there is no goal to hand back at all.
// Measured over all twelve factories: the nine that take a list, a path or a number answer for nil
// and for an empty list alike. The archived version of this file stored nil and answered, which is a
// goal that names an agent that is not there.
+ (instancetype)charon_goalWithAgent:(GKAgent *)agent kind:(CharonGKGoalKind)kind
{
    if (!agent) {
        [NSException raise:NSInvalidArgumentException format:@"%@ needs an agent", NSStringFromSelector(_cmd)];
        return nil;
    }
    GKGoal *goal = [self charon_goalOfKind:kind];
    goal->_agent = agent;
    return goal;
}

+ (instancetype)goalToAvoidObstacles:(NSArray<GKObstacle *> *)obstacles maxPredictionTime:(NSTimeInterval)maxPredictionTime
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalAvoidObstacles];
    goal->_obstacles = [obstacles copy];
    goal->_maxPredictionTime = maxPredictionTime;
    return goal;
}

+ (instancetype)goalToAvoidAgents:(NSArray<GKAgent *> *)agents maxPredictionTime:(NSTimeInterval)maxPredictionTime
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalAvoidAgents];
    goal->_agents = [agents copy];
    goal->_maxPredictionTime = maxPredictionTime;
    return goal;
}

+ (instancetype)goalToSeparateFromAgents:(NSArray<GKAgent *> *)agents maxDistance:(float)maxDistance maxAngle:(float)maxAngle
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalSeparate];
    goal->_agents = [agents copy];
    goal->_maxDistance = maxDistance;
    goal->_maxAngle = maxAngle;
    return goal;
}

+ (instancetype)goalToAlignWithAgents:(NSArray<GKAgent *> *)agents maxDistance:(float)maxDistance maxAngle:(float)maxAngle
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalAlign];
    goal->_agents = [agents copy];
    goal->_maxDistance = maxDistance;
    goal->_maxAngle = maxAngle;
    return goal;
}

+ (instancetype)goalToCohereWithAgents:(NSArray<GKAgent *> *)agents maxDistance:(float)maxDistance maxAngle:(float)maxAngle
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalCohere];
    goal->_agents = [agents copy];
    goal->_maxDistance = maxDistance;
    goal->_maxAngle = maxAngle;
    return goal;
}

+ (instancetype)goalToReachTargetSpeed:(float)targetSpeed
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalReachTargetSpeed];
    goal->_value = targetSpeed;
    return goal;
}

+ (instancetype)goalToWander:(float)speed
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalWander];
    goal->_value = speed;
    return goal;
}

+ (instancetype)goalToInterceptAgent:(GKAgent *)target maxPredictionTime:(NSTimeInterval)maxPredictionTime
{
    GKGoal *goal = [self charon_goalWithAgent:target kind:CharonGKGoalIntercept];
    goal->_maxPredictionTime = maxPredictionTime;
    return goal;
}

+ (instancetype)goalToFollowPath:(GKPath *)path maxPredictionTime:(NSTimeInterval)maxPredictionTime forward:(BOOL)forward
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalFollowPath];
    goal->_path = path;
    goal->_maxPredictionTime = maxPredictionTime;
    goal->_forward = forward;
    return goal;
}

+ (instancetype)goalToStayOnPath:(GKPath *)path maxPredictionTime:(NSTimeInterval)maxPredictionTime
{
    GKGoal *goal = [self charon_goalOfKind:CharonGKGoalStayOnPath];
    goal->_path = path;
    goal->_maxPredictionTime = maxPredictionTime;
    return goal;
}

- (id)copyWithZone:(NSZone *)zone
{
    GKGoal *copy = [[[self class] allocWithZone:zone] initWithCharonKind:_kind];
    copy->_agent = _agent;
    copy->_obstacles = [_obstacles copy];
    copy->_agents = [_agents copy];
    copy->_path = _path;
    copy->_maxPredictionTime = _maxPredictionTime;
    copy->_value = _value;
    copy->_maxDistance = _maxDistance;
    copy->_maxAngle = _maxAngle;
    copy->_forward = _forward;
    return copy;
}

@end