#import "RevenantGK.h"

@implementation GKGoal {
    RevenantGKGoalKind _kind;
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

+ (instancetype)revenant_goalOfKind:(RevenantGKGoalKind)kind
{
    return [[self alloc] initWithRevenantKind:kind];
}

- (instancetype)initWithRevenantKind:(RevenantGKGoalKind)kind
{
    self = [super init];
    if (self) {
        _kind = kind;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithRevenantKind:RevenantGKGoalWander];
}

- (RevenantGKGoalKind)revenant_kind
{
    return _kind;
}

- (GKAgent *)revenant_agent
{
    return _agent;
}

- (NSArray<GKObstacle *> *)revenant_obstacles
{
    return _obstacles;
}

- (NSArray<GKAgent *> *)revenant_agents
{
    return _agents;
}

- (GKPath *)revenant_path
{
    return _path;
}

- (NSTimeInterval)revenant_maxPredictionTime
{
    return _maxPredictionTime;
}

- (float)revenant_value
{
    return _value;
}

- (float)revenant_maxDistance
{
    return _maxDistance;
}

- (float)revenant_maxAngle
{
    return _maxAngle;
}

- (BOOL)revenant_forward
{
    return _forward;
}

+ (instancetype)goalToSeekAgent:(GKAgent *)agent
{
    return [self revenant_goalWithAgent:agent kind:RevenantGKGoalSeek];
}

+ (instancetype)goalToFleeAgent:(GKAgent *)agent
{
    return [self revenant_goalWithAgent:agent kind:RevenantGKGoalFlee];
}

+ (instancetype)revenant_goalWithAgent:(GKAgent *)agent kind:(RevenantGKGoalKind)kind
{
    if (!agent) {
        [NSException raise:NSInvalidArgumentException format:@"%@ needs an agent", NSStringFromSelector(_cmd)];
        return nil;
    }
    GKGoal *goal = [self revenant_goalOfKind:kind];
    goal->_agent = agent;
    return goal;
}

+ (instancetype)goalToAvoidObstacles:(NSArray<GKObstacle *> *)obstacles maxPredictionTime:(NSTimeInterval)maxPredictionTime
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalAvoidObstacles];
    goal->_obstacles = [obstacles copy];
    goal->_maxPredictionTime = maxPredictionTime;
    return goal;
}

+ (instancetype)goalToAvoidAgents:(NSArray<GKAgent *> *)agents maxPredictionTime:(NSTimeInterval)maxPredictionTime
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalAvoidAgents];
    goal->_agents = [agents copy];
    goal->_maxPredictionTime = maxPredictionTime;
    return goal;
}

+ (instancetype)goalToSeparateFromAgents:(NSArray<GKAgent *> *)agents maxDistance:(float)maxDistance maxAngle:(float)maxAngle
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalSeparate];
    goal->_agents = [agents copy];
    goal->_maxDistance = maxDistance;
    goal->_maxAngle = maxAngle;
    return goal;
}

+ (instancetype)goalToAlignWithAgents:(NSArray<GKAgent *> *)agents maxDistance:(float)maxDistance maxAngle:(float)maxAngle
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalAlign];
    goal->_agents = [agents copy];
    goal->_maxDistance = maxDistance;
    goal->_maxAngle = maxAngle;
    return goal;
}

+ (instancetype)goalToCohereWithAgents:(NSArray<GKAgent *> *)agents maxDistance:(float)maxDistance maxAngle:(float)maxAngle
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalCohere];
    goal->_agents = [agents copy];
    goal->_maxDistance = maxDistance;
    goal->_maxAngle = maxAngle;
    return goal;
}

+ (instancetype)goalToReachTargetSpeed:(float)targetSpeed
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalReachTargetSpeed];
    goal->_value = targetSpeed;
    return goal;
}

+ (instancetype)goalToWander:(float)speed
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalWander];
    goal->_value = speed;
    return goal;
}

+ (instancetype)goalToInterceptAgent:(GKAgent *)target maxPredictionTime:(NSTimeInterval)maxPredictionTime
{
    GKGoal *goal = [self revenant_goalWithAgent:target kind:RevenantGKGoalIntercept];
    goal->_maxPredictionTime = maxPredictionTime;
    return goal;
}

+ (instancetype)goalToFollowPath:(GKPath *)path maxPredictionTime:(NSTimeInterval)maxPredictionTime forward:(BOOL)forward
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalFollowPath];
    goal->_path = path;
    goal->_maxPredictionTime = maxPredictionTime;
    goal->_forward = forward;
    return goal;
}

+ (instancetype)goalToStayOnPath:(GKPath *)path maxPredictionTime:(NSTimeInterval)maxPredictionTime
{
    GKGoal *goal = [self revenant_goalOfKind:RevenantGKGoalStayOnPath];
    goal->_path = path;
    goal->_maxPredictionTime = maxPredictionTime;
    return goal;
}

- (id)copyWithZone:(NSZone *)zone
{
    GKGoal *copy = [[[self class] allocWithZone:zone] initWithRevenantKind:_kind];
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
