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
