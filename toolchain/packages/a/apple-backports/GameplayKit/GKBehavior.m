#import "RevenantGK.h"

@implementation GKBehavior {
    NSMutableArray<GKGoal *> *_goals;
    NSMutableArray<NSNumber *> *_weights;
}

- (NSInteger)goalCount
{
    return (NSInteger)[_goals count];
}

- (NSUInteger)revenant_indexOfGoal:(GKGoal *)goal
{
    NSUInteger index = 0;
    for (GKGoal *known in _goals) {
        if (known == goal) {
            return index;
        }
        index++;
    }
    return NSNotFound;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _goals = [NSMutableArray array];
        _weights = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)behaviorWithGoal:(GKGoal *)goal weight:(float)weight
{
    GKBehavior *behavior = [[self alloc] init];
    [behavior setWeight:weight forGoal:goal];
    return behavior;
}

+ (instancetype)behaviorWithGoals:(NSArray<GKGoal *> *)goals
{
    GKBehavior *behavior = [[self alloc] init];
    for (GKGoal *goal in goals) {
        [behavior setWeight:1.0f forGoal:goal];
    }
    return behavior;
}

+ (instancetype)behaviorWithGoals:(NSArray<GKGoal *> *)goals andWeights:(NSArray<NSNumber *> *)weights
{
    GKBehavior *behavior = [[self alloc] init];
    NSUInteger count = [goals count];
    for (NSUInteger index = 0; index < count; index++) {
        [behavior setWeight:[weights[index] floatValue] forGoal:goals[index]];
    }
    return behavior;
}

+ (instancetype)behaviorWithWeightedGoals:(NSDictionary<GKGoal *, NSNumber *> *)weightedGoals
{
    GKBehavior *behavior = [[self alloc] init];
    [weightedGoals enumerateKeysAndObjectsUsingBlock:^(GKGoal *goal, NSNumber *weight, BOOL *stop) {
        [behavior setWeight:[weight floatValue] forGoal:goal];
    }];
    return behavior;
}

- (void)setWeight:(float)weight forGoal:(GKGoal *)goal
{
    if (!goal) {
        return;
    }
    NSUInteger index = [self revenant_indexOfGoal:goal];
    if (index == NSNotFound) {
        [_goals addObject:goal];
        [_weights addObject:@(weight)];
    } else {
        _weights[index] = @(weight);
    }
}

- (float)weightForGoal:(GKGoal *)goal
{
    NSUInteger index = goal ? [self revenant_indexOfGoal:goal] : NSNotFound;
    return index == NSNotFound ? 0.0f : [_weights[index] floatValue];
}

- (void)removeGoal:(GKGoal *)goal
{
    if (!goal) {
        return;
    }
    NSUInteger index = [self revenant_indexOfGoal:goal];
    if (index != NSNotFound) {
        [_weights removeObjectAtIndex:index];
        [_goals removeObjectAtIndex:index];
    }
}

- (void)removeAllGoals
{
    [_weights removeAllObjects];
    [_goals removeAllObjects];
}

- (GKGoal *)objectAtIndexedSubscript:(NSUInteger)idx
{
    return [_goals objectAtIndex:idx];
}

- (void)setObject:(NSNumber *)weight forKeyedSubscript:(GKGoal *)goal
{
    [self setWeight:[weight floatValue] forGoal:goal];
}

- (NSNumber *)objectForKeyedSubscript:(GKGoal *)goal
{
    NSUInteger index = goal ? [self revenant_indexOfGoal:goal] : NSNotFound;
    return index == NSNotFound ? nil : _weights[index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained *)buffer count:(NSUInteger)length
{
    return [_goals countByEnumeratingWithState:state objects:buffer count:length];
}

- (id)copyWithZone:(NSZone *)zone
{
    GKBehavior *copy = [[[self class] allocWithZone:zone] init];
    for (NSUInteger index = 0; index < [_goals count]; index++) {
        [copy setWeight:[_weights[index] floatValue] forGoal:_goals[index]];
    }
    return copy;
}

@end
