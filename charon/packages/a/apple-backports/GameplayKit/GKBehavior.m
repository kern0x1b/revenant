// GKBehavior.m -- a behaviour: the goals an agent is asked to satisfy, and how much each one counts.
// GameplayKit.framework carries no code at all before iOS 9 (GK_BASE_AVAILABILITY is
// NS_CLASS_AVAILABLE(10_11, 9_0) and the 6.1.3 armv7 cache exports no GameplayKit class), so this is
// this port's own; what the host does was measured by tests/backports/host/gameplaykit-core/measure.m:
//
//   The goals are in the order they were added, -goalCount and -objectAtIndexedSubscript: and the
//   fast enumeration all walk that order, and -weightForGoal: of a goal the behaviour does not have
//   is 0, measured. -objectForKeyedSubscript: of an absent goal is nil and -setObject:forKeyed-
//   Subscript: with a weight adds the goal if it is not there, measured.
//   +behaviorWithGoals: gives every goal a weight of 1, +behaviorWithGoals:andWeights: reads the
//   weights by the goal's index and raises NSRangeException when there are fewer of them than goals,
//   and a nil weights array leaves every goal at nothing -- all three measured over every combination
//   of up to three goals and up to three weights. +behaviorWithWeightedGoals: keeps the weights the
//   dictionary carries, which is what the method is for and what the host answers on this host
//   (measured: a dictionary of one goal at weight 3 gives that goal weight 3; the archived version
//   recorded the host dropping them to 0, and that no longer reproduces here -- see
//   facts/GameplayKit/Behavior.md, where both measurements are written down).
//   -copy is a new behaviour with the same goals in the same order and the same weights, measured.
//
// A goal is what an agent is asked to do: the twelve factories in GKGoal.m build one out of the
// arguments they name, and GKAgent reads it back when it decides. Nothing else of a goal is public,
// so what it holds is this port's own and carries the parameters of the factory it came from.
//
// -goalCount is the one property the SDK declares here, and it is answered from the array beside it,
// with a getter of the class's own, so clang auto-synthesizes nothing and the pragma the archived
// version silenced -Wobjc-missing-property-synthesis with is gone with the thing it hid.

#import "CharonGK.h"

// The goals in the order they were given, and the weight of each beside it. The weights are held
// beside the goals rather than in a dictionary keyed by them: a behaviour holds a handful of goals,
// so a scan is both cheap and free of any question about what a goal's own hashing answers, and the
// goals are matched by identity, which is what an application means when it asks for the weight of
// a goal it made.
@implementation GKBehavior {
    NSMutableArray<GKGoal *> *_goals;
    NSMutableArray<NSNumber *> *_weights;
}

- (NSInteger)goalCount
{
    return (NSInteger)[_goals count];
}

- (NSUInteger)charon_indexOfGoal:(GKGoal *)goal
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

// The weights are read by the goal's own index and are not padded: with fewer weights than goals the
// host raises NSRangeException from the weights array itself, at the first index it does not have,
// and with a nil weights array every goal weighs nothing, because a subscript of nil is nil and a
// subscript of an empty array raises. Measured over every combination of up to three goals and up to
// three weights, and the loop below is the rule that produces all sixteen answers. The archived
// version of this file padded a short weights array with 1.0 instead, which is a rule of its own
// that the host does not have.
+ (instancetype)behaviorWithGoals:(NSArray<GKGoal *> *)goals andWeights:(NSArray<NSNumber *> *)weights
{
    GKBehavior *behavior = [[self alloc] init];
    NSUInteger count = [goals count];
    for (NSUInteger index = 0; index < count; index++) {
        [behavior setWeight:[weights[index] floatValue] forGoal:goals[index]];
    }
    return behavior;
}

// The host keeps the weights this method is given, so the port keeps them too: a dictionary of one
// goal at weight 3 gives that goal weight 3, measured on this host. (The archived version of this
// file recorded the host answering 0 for every goal and kept the weights on purpose; that
// measurement does not reproduce on macOS 27 (26A428), so the port and the host now agree and the
// earlier one is in facts/GameplayKit/Behavior.md rather than in the code.)
//
// The weights are paired with their goals by walking the keys and the values together, not by asking
// the dictionary for the value of each key: an NSDictionary copies its keys, a GKGoal's copy is a goal
// of its own, and on the host a lookup by a key the dictionary itself yielded answers nil for one of
// the two goals of a two-goal dictionary (measured), so a factory built on that lookup drops a weight.
// The host's own answers 3 and 7 for the same dictionary, which is what this pairing gives here too.
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
    NSUInteger index = [self charon_indexOfGoal:goal];
    if (index == NSNotFound) {
        [_goals addObject:goal];
        [_weights addObject:@(weight)];
    } else {
        _weights[index] = @(weight);
    }
}

- (float)weightForGoal:(GKGoal *)goal
{
    NSUInteger index = goal ? [self charon_indexOfGoal:goal] : NSNotFound;
    return index == NSNotFound ? 0.0f : [_weights[index] floatValue];
}

- (void)removeGoal:(GKGoal *)goal
{
    if (!goal) {
        return;
    }
    NSUInteger index = [self charon_indexOfGoal:goal];
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
    NSUInteger index = goal ? [self charon_indexOfGoal:goal] : NSNotFound;
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