// measure.m -- what the host's own GameplayKit answers, for the families this differential holds.
//
// This is the oracle. run.sh does not load the host's framework beside the port's, because the two
// carry the same selectors and ld64 binds each objc_msgSend$selector stub to one implementation of it,
// so a side-by-side process would answer the host's method where the port's was meant. Instead this
// prints what the host answers and differential.m holds the port to those numbers, and run.sh prints
// this output beside the checks so every expectation can be re-measured rather than trusted.
//
// Every family prints its own block. The distributions and the shuffle are measured through a written
// script (CharonGKScriptedSource.h) rather than through a seeded source, because the port's own
// generators are not the host's -- see facts/GameplayKit/GKRandomSource.md -- and what has to agree
// between the two is which protocol methods a family calls and how it combines the answers, not what a
// generator draws.
//
// Run it by hand after a change on the host's side. macOS 27 (26A428), 2026-10-04.

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>
#import "CharonGKScriptedSource.h"

@interface ProbeOne : GKComponent @end
@implementation ProbeOne @end
@interface ProbeTwo : GKComponent @end
@implementation ProbeTwo @end

@interface OpenA : GKState @end
@implementation OpenA
- (void)didEnterWithPreviousState:(GKState *)previous { printf("openA didEnter %s\n", previous ? class_getName([previous class]) : "nil"); }
- (void)willExitWithNextState:(GKState *)next { printf("openA willExit %s\n", next ? class_getName([next class]) : "nil"); }
- (BOOL)isValidNextState:(Class)stateClass { return YES; }
@end
@interface OpenB : GKState @end
@implementation OpenB
- (void)didEnterWithPreviousState:(GKState *)previous { printf("openB didEnter %s\n", previous ? class_getName([previous class]) : "nil"); }
- (void)willExitWithNextState:(GKState *)next { printf("openB willExit %s\n", next ? class_getName([next class]) : "nil"); }
- (BOOL)isValidNextState:(Class)stateClass { return NO; }
@end

static NSString *saliences(NSArray<GKRule *> *rules)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (GKRule *rule in rules) {
        [parts addObject:[NSString stringWithFormat:@"%ld", (long)rule.salience]];
    }
    return [parts componentsJoinedByString:@" "];
}

static NSString *classes(NSArray *objects)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (id object in objects) {
        [parts addObject:NSStringFromClass([object class])];
    }
    return [parts componentsJoinedByString:@" "];
}

static NSString *floats(NSArray<NSNumber *> *numbers)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSNumber *number in numbers) {
        [parts addObject:[NSString stringWithFormat:@"%g", [number floatValue]]];
    }
    return [parts componentsJoinedByString:@" "];
}

int main(void)
{
    // line buffered: a run that traps must leave the lines before it, not a four-kilobyte buffer
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        printf("== state machines ==\n");
        @try {
            [[GKStateMachine alloc] init];
            printf("machine init: no exception\n");
        } @catch (NSException *exception) {
            printf("machine init: %s | %s | userInfo %s\n", [[exception name] UTF8String],
                   [[exception reason] UTF8String], [[exception userInfo] description].UTF8String);
        }
        @try {
            [GKStateMachine new];
            printf("machine new: no exception\n");
        } @catch (NSException *exception) {
            printf("machine new: %s\n", [[exception name] UTF8String]);
        }
        {
            GKState *plain = [GKState state];
            printf("plain state: class %s machine %d isValidNextState %d\n",
                   class_getName([plain class]), plain.stateMachine != nil,
                   (int)[plain isValidNextState:[GKState class]]);
            GKStateMachine *empty = [GKStateMachine stateMachineWithStates:@[]];
            printf("empty machine: current %d canEnter %d stateForClass %d\n", empty.currentState != nil,
                   (int)[empty canEnterState:[GKState class]], [empty stateForClass:[GKState class]] != nil);
            printf("empty machine: stateForClass Nil %d\n", [empty stateForClass:Nil] != nil);
            OpenA *a = [OpenA new];
            OpenB *b = [OpenB new];
            GKStateMachine *machine = [GKStateMachine stateMachineWithStates:@[a, b]];
            printf("machine of two: a knows it %d stateForClass A %d stateForClass B %d\n",
                   a.stateMachine == machine, [machine stateForClass:[OpenA class]] != nil,
                   [machine stateForClass:[OpenB class]] != nil);
            printf("enter A: %d\n", (int)[machine enterState:[OpenA class]]);
            printf("enter B (A allows it): %d\n", (int)[machine enterState:[OpenB class]]);
            printf("enter A again (B forbids it): %d current %s\n", (int)[machine enterState:[OpenA class]],
                   machine.currentState ? class_getName([machine.currentState class]) : "nil");
            printf("canEnter A from B: %d\n", (int)[machine canEnterState:[OpenA class]]);
            printf("canEnter a class with no state: %d\n", (int)[machine canEnterState:[GKEntity class]]);
            printf("enter a class with no state: %d\n", (int)[machine enterState:[GKEntity class]]);
            GKStateMachine *fresh = [GKStateMachine stateMachineWithStates:@[a, b]];
            printf("a second machine takes a: %d\n", a.stateMachine == fresh);
            GKStateMachine *third = [GKStateMachine stateMachineWithStates:@[b]];
            printf("fresh machine: canEnter %d enter B %d current %s\n",
                   (int)[third canEnterState:[OpenB class]], (int)[third enterState:[OpenB class]],
                   third.currentState ? class_getName([third.currentState class]) : "nil");
        }

        printf("== entity and components ==\n");
        {
            GKEntity *entity = [GKEntity entity];
            printf("new entity: components %lu\n", (unsigned long)entity.components.count);
            [entity addComponent:[[ProbeOne alloc] init]];
            [entity addComponent:[[ProbeTwo alloc] init]];
            printf("one then two: %s\n", [classes(entity.components) UTF8String]);
            GKEntity *other = [GKEntity entity];
            [other addComponent:[[ProbeTwo alloc] init]];
            [other addComponent:[[ProbeOne alloc] init]];
            printf("two then one: %s\n", [classes(other.components) UTF8String]);
            GKEntity *replaced = [GKEntity entity];
            [replaced addComponent:[[ProbeOne alloc] init]];
            [replaced addComponent:[[ProbeOne alloc] init]];
            printf("one then one: count %lu\n", (unsigned long)replaced.components.count);
            GKComponent *held = [replaced componentForClass:[ProbeOne class]];
            printf("componentForClass: found %d absent %d Nil %d backpointer %d\n",
                   held != nil, [replaced componentForClass:[ProbeTwo class]] == nil,
                   [replaced componentForClass:Nil] == nil, held.entity == replaced);
            [replaced removeComponentForClass:[ProbeTwo class]];
            printf("removing an absent class: count %lu\n", (unsigned long)replaced.components.count);
            [replaced removeComponentForClass:[ProbeOne class]];
            printf("removing the held one: count %lu backpointer %d\n",
                   (unsigned long)replaced.components.count, held.entity == nil);
            printf("supportsSecureCoding: entity %d component %d\n", (int)[GKEntity supportsSecureCoding],
                   (int)[GKComponent supportsSecureCoding]);
            GKEntity *carried = [GKEntity entity];
            [carried addComponent:[[ProbeOne alloc] init]];
            [carried addComponent:[[ProbeTwo alloc] init]];
            NSError *error = nil;
            NSData *bytes = [NSKeyedArchiver archivedDataWithRootObject:carried requiringSecureCoding:YES error:&error];
            GKEntity *back = [NSKeyedUnarchiver unarchivedObjectOfClass:[GKEntity class] fromData:bytes error:&error];
            printf("archive round trip: %s components %lu (%s)\n", back ? "ok" : "nil",
                   (unsigned long)back.components.count, [classes(back.components) UTF8String]);
            GKEntity *copied = [carried copy];
            printf("copy: distinct %d components %lu own %d\n", copied != carried,
                   (unsigned long)copied.components.count,
                   copied.components.firstObject != carried.components.firstObject);
        }

        printf("== component system ==\n");
        {
            GKComponentSystem *system = [[GKComponentSystem alloc] initWithComponentClass:[ProbeOne class]];
            printf("new system: class %s components %lu\n", class_getName(system.componentClass),
                   (unsigned long)system.components.count);
            printf("generic argument 0/1/9: %s %s %s\n",
                   class_getName([system classForGenericArgumentAtIndex:0]),
                   class_getName([system classForGenericArgumentAtIndex:1]),
                   class_getName([system classForGenericArgumentAtIndex:9]));
            @try {
                [system addComponent:[[ProbeTwo alloc] init]];
                printf("adding another class: %lu\n", (unsigned long)system.components.count);
            } @catch (NSException *exception) {
                printf("adding another class: %s | %s\n", [[exception name] UTF8String],
                       [[exception reason] UTF8String]);
            }
            @try {
                [system addComponent:nil];
                printf("adding nil: %lu\n", (unsigned long)system.components.count);
            } @catch (NSException *exception) {
                printf("adding nil: %s | %s\n", [[exception name] UTF8String],
                       [[exception reason] UTF8String]);
            }
            ProbeOne *one = [[ProbeOne alloc] init];
            [system addComponent:one];
            [system addComponent:[[ProbeOne alloc] init]];
            printf("two of its own: count %lu indexed %d enumerated %lu\n", (unsigned long)system.components.count,
                   (int)([system objectAtIndexedSubscript:0] == one), (unsigned long)system.components.count);
            GKEntity *holder = [GKEntity entity];
            [holder addComponent:[[ProbeOne alloc] init]];
            [system addComponentWithEntity:holder];
            printf("from an entity: %lu\n", (unsigned long)system.components.count);
            GKEntity *wrong = [GKEntity entity];
            [wrong addComponent:[[ProbeTwo alloc] init]];
            [system addComponentWithEntity:wrong];
            printf("from an entity of another class: %lu\n", (unsigned long)system.components.count);
            [system removeComponentWithEntity:holder];
            printf("removing by entity: %lu\n", (unsigned long)system.components.count);
            [system removeComponent:one];
            printf("removing by component: %lu\n", (unsigned long)system.components.count);
        }


        printf("== behaviours and goals ==\n");
        {
            GKGoal *wander = [GKGoal goalToWander:1.0f];
            GKGoal *speed = [GKGoal goalToReachTargetSpeed:2.0f];
            GKBehavior *plain = [GKBehavior behaviorWithGoals:@[wander, speed]];
            printf("two goals: count %ld weights %g %g\n", (long)plain.goalCount,
                   [plain weightForGoal:[plain objectAtIndexedSubscript:0]],
                   [plain weightForGoal:[plain objectAtIndexedSubscript:1]]);
            GKBehavior *empty = [[GKBehavior alloc] init];
            printf("new behaviour: count %ld weight of an absent goal %g\n", (long)empty.goalCount,
                   [empty weightForGoal:wander]);
            GKBehavior *weighted = [GKBehavior behaviorWithWeightedGoals:@{wander: @3, speed: @7}];
            printf("weighted goals: count %ld weights %g %g\n", (long)weighted.goalCount,
                   [weighted weightForGoal:[weighted objectAtIndexedSubscript:0]],
                   [weighted weightForGoal:[weighted objectAtIndexedSubscript:1]]);
            GKBehavior *resent = [GKBehavior behaviorWithGoal:wander weight:1.0f];
            [resent setWeight:5.0f forGoal:wander];
            printf("weight set twice: count %ld weight %g\n", (long)resent.goalCount,
                   [resent weightForGoal:wander]);
            GKBehavior *both = [[GKBehavior alloc] init];
            [both setObject:@2.0f forKeyedSubscript:wander];
            GKGoal *third = [GKGoal goalToWander:3.0f];
            [both setObject:@4.0f forKeyedSubscript:third];
            printf("keyed: count %ld subscript %g %g absent %s\n", (long)both.goalCount,
                   [[both objectForKeyedSubscript:wander] floatValue],
                   [[both objectForKeyedSubscript:third] floatValue],
                   [both objectForKeyedSubscript:speed] ? "non-nil" : "nil");
            NSUInteger enumerated = 0;
            for (GKGoal *goal in both) {
                enumerated++;
            }
            printf("enumerated: %lu\n", (unsigned long)enumerated);
            GKBehavior *copied = [both copy];
            printf("copy: distinct %d count %ld weights %g %g\n", copied != both, (long)copied.goalCount,
                   [copied weightForGoal:wander], [copied weightForGoal:third]);
            [both removeGoal:wander];
            printf("after removing one: count %ld its weight %g\n", (long)both.goalCount,
                   [both weightForGoal:wander]);
            [both removeAllGoals];
            printf("after removing all: count %ld\n", (long)both.goalCount);
            for (NSUInteger goals = 0; goals <= 2; goals++) {
                for (NSUInteger weights = 0; weights <= 2; weights++) {
                    NSMutableArray *goalList = [NSMutableArray array];
                    NSMutableArray *weightList = [NSMutableArray array];
                    for (NSUInteger index = 0; index < goals; index++) {
                        [goalList addObject:[GKGoal goalToWander:(float)index]];
                    }
                    for (NSUInteger index = 0; index < weights; index++) {
                        [weightList addObject:@((NSInteger)(10 + index))];
                    }
                    @try {
                        GKBehavior *made = [GKBehavior behaviorWithGoals:goalList andWeights:weightList];
                        NSMutableArray *got = [NSMutableArray array];
                        for (NSUInteger index = 0; index < (NSUInteger)made.goalCount; index++) {
                            [got addObject:@([made weightForGoal:[made objectAtIndexedSubscript:index]])];
                        }
                        printf("goals %lu weights %lu: %s\n", (unsigned long)goals, (unsigned long)weights,
                               [floats(got) UTF8String]);
                    } @catch (NSException *exception) {
                        printf("goals %lu weights %lu: %s\n", (unsigned long)goals, (unsigned long)weights,
                               [[exception name] UTF8String]);
                    }
                }
            }
            @try {
                GKBehavior *made = [GKBehavior behaviorWithGoals:@[wander] andWeights:nil];
                printf("nil weights: count %ld weight %g\n", (long)made.goalCount,
                       [made weightForGoal:[made objectAtIndexedSubscript:0]]);
            } @catch (NSException *exception) {
                printf("nil weights: %s\n", [[exception name] UTF8String]);
            }
            // The three factories that take ONE agent refuse nil, so a goal of each kind needs an
            // agent of the host's own class -- which the differential cannot build, because the port
            // carries no GKAgent. What both sides can measure is the refusal itself, and the nine
            // factories that answer for nil.
            @try {
                [GKGoal goalToSeekAgent:nil];
                printf("a seek goal with no agent: no exception\n");
            } @catch (NSException *exception) {
                printf("a seek goal with no agent: %s\n", [[exception name] UTF8String]);
            }
            @try {
                [GKGoal goalToFleeAgent:nil];
                printf("a flee goal with no agent: no exception\n");
            } @catch (NSException *exception) {
                printf("a flee goal with no agent: %s\n", [[exception name] UTF8String]);
            }
            @try {
                [GKGoal goalToInterceptAgent:nil maxPredictionTime:1];
                printf("an intercept goal with no agent: no exception\n");
            } @catch (NSException *exception) {
                printf("an intercept goal with no agent: %s\n", [[exception name] UTF8String]);
            }
            GKSphereObstacle *obstacle = [GKSphereObstacle obstacleWithRadius:1];
            NSArray *goals = @[[GKGoal goalToAvoidObstacles:@[obstacle] maxPredictionTime:1],
                               [GKGoal goalToAvoidObstacles:@[] maxPredictionTime:1],
                               [GKGoal goalToAvoidObstacles:nil maxPredictionTime:1],
                               [GKGoal goalToAvoidAgents:@[] maxPredictionTime:1],
                               [GKGoal goalToAvoidAgents:nil maxPredictionTime:1],
                               [GKGoal goalToSeparateFromAgents:@[] maxDistance:1 maxAngle:1],
                               [GKGoal goalToAlignWithAgents:@[] maxDistance:1 maxAngle:1],
                               [GKGoal goalToCohereWithAgents:@[] maxDistance:1 maxAngle:1],
                               [GKGoal goalToReachTargetSpeed:1], [GKGoal goalToWander:1],
                               [GKGoal goalToFollowPath:nil maxPredictionTime:1 forward:YES],
                               [GKGoal goalToStayOnPath:nil maxPredictionTime:1]];
            BOOL everyGoal = YES;
            BOOL everyCopy = YES;
            for (GKGoal *goal in goals) {
                everyGoal = everyGoal && [goal isMemberOfClass:[GKGoal class]];
                GKGoal *copied = [goal copy];
                everyCopy = everyCopy && copied != goal && [copied isMemberOfClass:[GKGoal class]];
            }
            printf("the nine that answer: %lu goals, every one a GKGoal %d, every copy its own %d\n",
                   (unsigned long)goals.count, (int)everyGoal, (int)everyCopy);
        }

        printf("== rule system ==\n");
        {
            NSString *a = @"fact-a";
            NSString *b = @"fact-b";
            NSString *c = @"fact-c";
            GKRuleSystem *system = [[GKRuleSystem alloc] init];
            printf("new system: rules %lu agenda %lu executed %lu facts %lu state %lu\n",
                   (unsigned long)system.rules.count, (unsigned long)system.agenda.count,
                   (unsigned long)system.executed.count, (unsigned long)system.facts.count,
                   (unsigned long)system.state.count);
            GKRule *bare = [[GKRule alloc] init];
            printf("bare rule: salience %ld predicate %d\n", (long)bare.salience,
                   (int)[bare evaluatePredicateWithSystem:system]);
            [bare performActionWithSystem:system];
            printf("bare rule performed: facts %lu\n", (unsigned long)system.facts.count);
            GKRule *one = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]
                                    assertingFact:a grade:0.5f];
            GKRule *two = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]
                                    assertingFact:b grade:0.25f];
            GKRule *three = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"FALSEPREDICATE"]
                                      retractingFact:a grade:0.75f];
            GKRule *four = [GKRule ruleWithBlockPredicate:^BOOL(GKRuleSystem *inner) { return [inner gradeForFact:a] >= 0.5f; }
                                                  action:^(GKRuleSystem *inner) { [inner assertFact:c grade:0.125f]; }];
            printf("factories: %s %s %s %s\n", class_getName([one class]), class_getName([two class]),
                   class_getName([three class]), class_getName([four class]));
            one.salience = 0; two.salience = 5; three.salience = 5; four.salience = -3;
            [system addRulesFromArray:@[one, two, three, four]];
            printf("after four adds: rules %lu agenda '%s'\n", (unsigned long)system.rules.count,
                   [saliences(system.agenda) UTF8String]);
            [system evaluate];
            printf("evaluated: executed '%s' agenda '%s'\n", [saliences(system.executed) UTF8String],
                   [saliences(system.agenda) UTF8String]);
            printf("grades: %g %g %g facts %lu state %lu\n", [system gradeForFact:a], [system gradeForFact:b],
                   [system gradeForFact:c], (unsigned long)system.facts.count, (unsigned long)system.state.count);
            printf("folds: min-empty %g max-empty %g min-ab %g max-ab %g unasserted %g\n",
                   [system minimumGradeForFacts:@[]], [system maximumGradeForFacts:@[]],
                   [system minimumGradeForFacts:@[a, b]], [system maximumGradeForFacts:@[a, b]],
                   [system gradeForFact:@"never-asserted"]);
            [system assertFact:a];
            [system assertFact:a];
            printf("asserted twice: %g\n", [system gradeForFact:a]);
            [system retractFact:a grade:5.0f];
            printf("retracted by five: %g\n", [system gradeForFact:a]);
            [system reset];
            printf("after reset: agenda '%s' executed %lu facts %lu rules %lu grade %g state %lu\n",
                   [saliences(system.agenda) UTF8String], (unsigned long)system.executed.count,
                   (unsigned long)system.facts.count, (unsigned long)system.rules.count,
                   [system gradeForFact:a], (unsigned long)system.state.count);
            GKRule *added = [GKRule ruleWithPredicate:nil assertingFact:@"late" grade:1.0f];
            [system addRule:added];
            printf("added past a reset: rules %lu agenda '%s'\n", (unsigned long)system.rules.count,
                   [saliences(system.agenda) UTF8String]);
            [system removeAllRules];
            printf("after removing every rule: rules %lu agenda '%s'\n", (unsigned long)system.rules.count,
                   [saliences(system.agenda) UTF8String]);
            [system.state setObject:@1 forKey:@"written"];
            printf("state is the caller's: %lu\n", (unsigned long)system.state.count);
        }
        {
            GKRuleSystem *system = [[GKRuleSystem alloc] init];
            [system.state setObject:@1 forKey:@"mine"];
            GKRule *substituted = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"$mine == 1"]
                                               assertingFact:@"f" grade:1.0f];
            printf("a substituted variable: %d\n", (int)[substituted evaluatePredicateWithSystem:system]);
            @try {
                GKRule *absent = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"$absent == 1"]
                                            assertingFact:@"f" grade:1.0f];
                printf("an absent variable: %d\n", (int)[absent evaluatePredicateWithSystem:system]);
            } @catch (NSException *exception) {
                printf("an absent variable: %s\n", [[exception name] UTF8String]);
            }
            GKRule *keyPath = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"state.count == 1"]
                                          assertingFact:@"f" grade:1.0f];
            printf("a key path through state: %d\n", (int)[keyPath evaluatePredicateWithSystem:system]);
            GKRule *block = [GKRule ruleWithBlockPredicate:^BOOL(GKRuleSystem *inner) {
                printf("a block: object is the system %d, state has %lu entries\n", (int)(inner == system),
                       (unsigned long)inner.state.count);
                return YES;
            } action:nil];
            printf("a block predicate: %d\n", (int)[block evaluatePredicateWithSystem:system]);
            GKNSPredicateRule *noPredicate = [[GKNSPredicateRule alloc] initWithPredicate:nil];
            printf("a rule with no predicate: predicate %d evaluates %d\n", [noPredicate predicate] != nil,
                   (int)[noPredicate evaluatePredicateWithSystem:system]);
            GKRuleSystem *keys = [[GKRuleSystem alloc] init];
            GKRule *ranked = [GKRule ruleWithPredicate:nil assertingFact:@"k" grade:1.0f];
            ranked.salience = 10;
            [keys addRule:[[GKRule alloc] init]];
            printf("agenda after one add: %lu\n", (unsigned long)keys.agenda.count);
            [keys addRule:ranked];
            printf("agenda after a higher one: '%s'\n", [saliences(keys.agenda) UTF8String]);
            [keys evaluate];
            printf("after evaluate: agenda '%s' executed '%s'\n", [saliences(keys.agenda) UTF8String],
                   [saliences(keys.executed) UTF8String]);
            [keys addRule:[[GKRule alloc] init]];
            printf("added past an evaluate: rules %lu agenda '%s'\n", (unsigned long)keys.rules.count,
                   [saliences(keys.agenda) UTF8String]);
        }

        printf("== distributions ==\n");
        {
            GKRandomDistribution *plain = [[GKRandomDistribution alloc] init];
            printf("init: lowest %ld highest %ld outcomes %lu\n", (long)plain.lowestValue,
                   (long)plain.highestValue, (unsigned long)plain.numberOfPossibleOutcomes);
            GKRandomDistribution *six = [GKRandomDistribution d6];
            printf("d6: lowest %ld highest %ld outcomes %lu\n", (long)six.lowestValue, (long)six.highestValue,
                   (unsigned long)six.numberOfPossibleOutcomes);
            GKRandomDistribution *twenty = [GKRandomDistribution d20];
            printf("d20: lowest %ld highest %ld outcomes %lu\n", (long)twenty.lowestValue,
                   (long)twenty.highestValue, (unsigned long)twenty.numberOfPossibleOutcomes);
            GKRandomDistribution *oneSide = [GKRandomDistribution distributionForDieWithSideCount:1];
            printf("one side: lowest %ld highest %ld\n", (long)oneSide.lowestValue, (long)oneSide.highestValue);
            GKRandomDistribution *inverted = [[GKRandomDistribution alloc] initWithRandomSource:nil
                                                                                    lowestValue:5 highestValue:1];
            printf("inverted: lowest %ld highest %ld outcomes %lu nextInt %ld nextUniform %g\n",
                   (long)inverted.lowestValue, (long)inverted.highestValue,
                   (unsigned long)inverted.numberOfPossibleOutcomes, (long)[inverted nextInt],
                   [inverted nextUniform]);
            @try {
                printf("inverted bounded by 3: %lu\n", (unsigned long)[inverted nextIntWithUpperBound:3]);
            } @catch (NSException *exception) {
                printf("inverted bounded by 3: %s | %s\n", [[exception name] UTF8String],
                       [[exception reason] UTF8String]);
            }
            GKGaussianDistribution *overRange = [[GKGaussianDistribution alloc] initWithRandomSource:nil
                                                                                          lowestValue:1
                                                                                         highestValue:20];
            printf("gaussian over 1..20: mean %g deviation %g lowest %ld highest %ld outcomes %lu\n",
                   overRange.mean, overRange.deviation, (long)overRange.lowestValue,
                   (long)overRange.highestValue, (unsigned long)overRange.numberOfPossibleOutcomes);
            GKGaussianDistribution *overMoments = [[GKGaussianDistribution alloc] initWithRandomSource:nil
                                                                                                mean:10.5f
                                                                                            deviation:19.0f / 6.0f];
            printf("gaussian over 10.5+/-19/6: mean %g deviation %g lowest %ld highest %ld outcomes %lu\n",
                   overMoments.mean, overMoments.deviation, (long)overMoments.lowestValue,
                   (long)overMoments.highestValue, (unsigned long)overMoments.numberOfPossibleOutcomes);
        }
        {
            // What each distribution asks of its source, over a written script. The trace is the
            // proof that the two sides call the same protocol methods in the same order.
            CharonGKScriptedSource *source = [[CharonGKScriptedSource alloc]
                                              initWithScript:@[@"bounded:6=2", @"bounded:6=5", @"bounded:6=1",
                                                               @"bounded:6=4", @"bounded:6=0", @"bounded:6=3",
                                                               @"bool=1", @"bool=0"]];
            GKRandomDistribution *die = [[GKRandomDistribution alloc] initWithRandomSource:source
                                                                                 lowestValue:1 highestValue:6];
            NSMutableArray *draws = [NSMutableArray array];
            for (NSUInteger index = 0; index < 6; index++) {
                [draws addObject:@([die nextInt])];
            }
            printf("a d6 over the script: %s\n", [floats(draws) UTF8String]);
            printf("  asked: %s\n", [source.log UTF8String]);
            CharonGKScriptedSource *bools = [[CharonGKScriptedSource alloc]
                                             initWithScript:@[@"bool=1", @"bool=0", @"bool=1", @"bool=1", @"bool=0"]];
            GKRandomDistribution *coin = [[GKRandomDistribution alloc] initWithRandomSource:bools
                                                                                 lowestValue:0 highestValue:1];
            printf("nextBool over the script: %d %d %d\n", (int)[coin nextBool], (int)[coin nextBool],
                   (int)[coin nextBool]);
            printf("  asked: %s\n", [bools.log UTF8String]);
            CharonGKScriptedSource *uniform = [[CharonGKScriptedSource alloc]
                                               initWithScript:@[@"bounded:6=3", @"bounded:6=0", @"bounded:6=5"]];
            GKRandomDistribution *faces = [[GKRandomDistribution alloc] initWithRandomSource:uniform
                                                                                  lowestValue:1 highestValue:6];
            printf("nextUniform over the script: %g %g %g\n", [faces nextUniform], [faces nextUniform],
                   [faces nextUniform]);
            printf("  asked: %s\n", [uniform.log UTF8String]);
            CharonGKScriptedSource *bounded = [[CharonGKScriptedSource alloc]
                                               initWithScript:@[@"bounded:3=1", @"bounded:4=2", @"bounded:7=3",
                                                                @"bounded:7=6", @"bounded:1=0"]];
            GKRandomDistribution *over = [[GKRandomDistribution alloc] initWithRandomSource:bounded
                                                                                  lowestValue:2 highestValue:5];
            NSMutableArray *withBound = [NSMutableArray array];
            for (NSUInteger bound = 1; bound <= 6; bound++) {
                @try {
                    [withBound addObject:[NSString stringWithFormat:@"%lu",
                                           (unsigned long)[over nextIntWithUpperBound:bound]]];
                } @catch (NSException *exception) {
                    [withBound addObject:[exception name]];
                }
            }
            printf("nextIntWithUpperBound over 2..5: %s\n", [[withBound componentsJoinedByString:@" "] UTF8String]);
            printf("  asked: %s\n", [bounded.log UTF8String]);
            CharonGKScriptedSource *below = [[CharonGKScriptedSource alloc] initWithScript:@[]];
            GKRandomDistribution *negative = [[GKRandomDistribution alloc] initWithRandomSource:below
                                                                                    lowestValue:-2 highestValue:2];
            NSMutableArray *underBounds = [NSMutableArray array];
            for (NSUInteger bound = 0; bound <= 4; bound++) {
                @try {
                    [underBounds addObject:[NSString stringWithFormat:@"%lu",
                                            (unsigned long)[negative nextIntWithUpperBound:bound]]];
                } @catch (NSException *exception) {
                    [underBounds addObject:[exception name]];
                }
            }
            printf("nextIntWithUpperBound over -2..2: %s\n", [[underBounds componentsJoinedByString:@" "] UTF8String]);
            printf("  asked: %s\n", [below.log UTF8String]);
            // One fresh source per call over a range whose lowest is above zero and whose whole range is
            // a single outcome, so that the span rule is measured where min(bound - lowest, outcomes)
            // and bound - lowest come apart most.
            for (NSUInteger bound = 0; bound <= 8; bound++) {
                CharonGKScriptedSource *fresh = [[CharonGKScriptedSource alloc] initWithScript:@[]];
                GKRandomDistribution *single = [[GKRandomDistribution alloc] initWithRandomSource:fresh
                                                                                     lowestValue:3
                                                                                    highestValue:3];
                @try {
                    printf("  3..3 b%lu = %lu asked '%s'\n", (unsigned long)bound,
                           (unsigned long)[single nextIntWithUpperBound:bound], [fresh.log UTF8String]);
                } @catch (NSException *exception) {
                    printf("  3..3 b%lu raised %s\n", (unsigned long)bound, [[exception name] UTF8String]);
                }
            }
            CharonGKScriptedSource *normal = [[CharonGKScriptedSource alloc]
                                              initWithScript:@[@"uniform=0.25", @"uniform=0.75", @"uniform=0.5",
                                                               @"uniform=0.1", @"uniform=0.9"]];
            GKGaussianDistribution *gaussian = [[GKGaussianDistribution alloc] initWithRandomSource:normal
                                                                                            lowestValue:0
                                                                                           highestValue:100];
            NSMutableArray *normals = [NSMutableArray array];
            for (NSUInteger index = 0; index < 3; index++) {
                [normals addObject:@([gaussian nextInt])];
            }
            printf("a gaussian over the script: %s\n", [floats(normals) UTF8String]);
            printf("  asked: %s\n", [normal.log UTF8String]);
            CharonGKScriptedSource *shuffling = [[CharonGKScriptedSource alloc]
                                                 initWithScript:@[@"bounded:1=0", @"bounded:2=1", @"bounded:3=2",
                                                                  @"bounded:4=0", @"bounded:5=3", @"bounded:6=5",
                                                                  @"bounded:1=0", @"bounded:2=1", @"bounded:3=0"]];
            GKShuffledDistribution *bag = [[GKShuffledDistribution alloc] initWithRandomSource:shuffling
                                                                                    lowestValue:1 highestValue:6];
            NSMutableArray *fromBag = [NSMutableArray array];
            for (NSUInteger index = 0; index < 9; index++) {
                [fromBag addObject:@([bag nextInt])];
            }
            printf("a shuffled d6 over the script: %s\n", [floats(fromBag) UTF8String]);
            printf("  asked: %s\n", [shuffling.log UTF8String]);
        }

        printf("== the shuffle NSArray carries ==\n");
        {
            CharonGKScriptedSource *source = [[CharonGKScriptedSource alloc]
                                              initWithScript:@[@"bounded:1=0", @"bounded:2=1", @"bounded:3=2",
                                                               @"bounded:4=0", @"bounded:5=3", @"bounded:6=5",
                                                               @"bounded:7=1", @"bounded:8=6"]];
            NSArray *shuffled = [@[@1, @2, @3, @4, @5, @6, @7, @8] shuffledArrayWithRandomSource:source];
            printf("eight over the script: %s\n", [[shuffled componentsJoinedByString:@" "] UTF8String]);
            printf("  asked: %s\n", [source.log UTF8String]);
            CharonGKScriptedSource *none = [[CharonGKScriptedSource alloc] initWithScript:@[]];
            printf("an empty array: %lu\n",
                   (unsigned long)[@[] shuffledArrayWithRandomSource:none].count);
            CharonGKScriptedSource *one = [[CharonGKScriptedSource alloc] initWithScript:@[]];
            NSArray *single = @[@1];
            NSArray *oneShuffled = [single shuffledArrayWithRandomSource:one];
            printf("one object: %s count %lu asked '%s'\n", [[oneShuffled description] UTF8String],
                   (unsigned long)oneShuffled.count, [one.log UTF8String]);
        }
    }
    return 0;
}
