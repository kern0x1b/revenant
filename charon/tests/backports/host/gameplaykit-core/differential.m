// differential.m -- the port's state machines, entity/component system, behaviours, rules,
// distributions and shuffle held against what the host's own GameplayKit answers.
//
// The host is the oracle and it is measured, not called: measure.m prints its answers and every number
// below is one of its lines. run.sh does not load the host's framework beside the port's, because the
// two carry the same selectors and ld64 binds each objc_msgSend$selector stub to one implementation of
// it, so a side-by-side process would answer the host's method where the port's was meant. This links
// Foundation only, so every GK* class in the process is the port's own, named as the SDK's headers name
// it, which is how an application reaching the port finds it.
//
// Three kinds of check appear, and every one of them names the measure.m line it came from:
//   host      the port must answer what the host was measured to answer
//   contract  a property the API promises, with no oracle for it (an archive round trip, a permutation,
//             an order nothing defines)
//   diverge   the two part on purpose and the check fails if they ever stop parting
//
// The distributions and the shuffle are measured through a written script
// (CharonGKScriptedSource.h), because the port's own random generators are NOT the host's -- see
// facts/GameplayKit/GKRandomSource.md, where that is measured -- so no number that came out of one
// source can be compared with the same number out of the other. What has to agree is which protocol
// methods a family reaches for, in which order, and how it combines the answers.

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>
#import "CharonGKScriptedSource.h"

static int checksRun = 0;
static int checksFailed = 0;

static void failed(NSString *kind, NSString *what, NSString *detail)
{
    checksFailed++;
    fprintf(stdout, "FAIL %s: %s%s%s\n", [kind UTF8String], [what UTF8String],
            detail.length ? " -- " : "", detail.length ? [detail UTF8String] : "");
}

static void host(BOOL ok, NSString *what, NSString *detail)
{
    checksRun++;
    if (!ok) {
        failed(@"host", what, detail);
    }
}

static void contract(BOOL ok, NSString *what, NSString *detail)
{
    checksRun++;
    if (!ok) {
        failed(@"contract", what, detail);
    }
}

// A place where the port and the host answer differently on purpose, and the check fails if they ever
// stop: that is what tells a later change on either side from the divergence recorded here.
static void diverge(BOOL apart, NSString *what)
{
    checksRun++;
    if (!apart) {
        failed(@"diverge", what, @"the two answer the same now, so the divergence recorded here is gone");
    }
}

// The three helpers the checks read their answers with, kept out of the checks themselves so that a
// message send never has to be nested inside another one: `[floats(x) isEqual:@"...", @"what", nil]`.
static NSString *floats(NSArray<NSNumber *> *numbers)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSNumber *number in numbers) {
        [parts addObject:[NSString stringWithFormat:@"%g", [number floatValue]]];
    }
    return [parts componentsJoinedByString:@" "];
}

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

static NSString *named(id object)
{
    return object ? NSStringFromClass([object class]) : @"nil";
}

static BOOL is(NSString *got, NSString *want)
{
    return [got isEqualToString:want];
}

// The hook log the two state classes below write into, so the order they are called in can be read off.
static NSMutableString *CharonGKHookLog(void)
{
    static NSMutableString *log;
    if (!log) {
        log = [NSMutableString string];
    }
    return log;
}

// ------------------------------------------------------------------ state machines

@interface OpenA : GKState @end
@implementation OpenA
- (BOOL)isValidNextState:(Class)stateClass { return YES; }
@end

@interface OpenB : GKState @end
@implementation OpenB
- (BOOL)isValidNextState:(Class)stateClass { return NO; }
@end

// The hooks in the order the machine calls them. Nothing in the host's answer names them, so the check
// on their order is a contract check on the header's own account: the state leaving is told before the
// state arriving, and the first entry has no previous state.
@interface Leaving : GKState @end
@implementation Leaving
- (void)didEnterWithPreviousState:(GKState *)previous { [CharonGKHookLog() appendFormat:@"A<%@ ", named(previous)]; }
- (void)willExitWithNextState:(GKState *)next { [CharonGKHookLog() appendFormat:@"A>%@ ", named(next)]; }
@end

@interface Arriving : GKState @end
@implementation Arriving
- (void)didEnterWithPreviousState:(GKState *)previous { [CharonGKHookLog() appendFormat:@"B<%@ ", named(previous)]; }
- (void)willExitWithNextState:(GKState *)next { [CharonGKHookLog() appendFormat:@"B>%@ ", named(next)]; }
@end

static void stateMachines(void)
{
    // measure.m, "machine init" and "machine new".
    @try {
        [[GKStateMachine alloc] init];
        host(NO, @"a machine built with -init raises, as the host's does", @"it did not raise");
    } @catch (NSException *exception) {
        BOOL right = is([exception name], @"GKInitNotAllowedException") &&
            is([exception reason], @"initWithStates is the destignated initialize for GKStateMachine.  Use that instead") &&
            [exception userInfo] == nil;
        host(right, @"a machine built with -init raises GKInitNotAllowedException with the host's own reason",
             [NSString stringWithFormat:@"%s | %s", [[exception name] UTF8String], [[exception reason] UTF8String]]);
    }
    @try {
        [GKStateMachine new];
        host(NO, @"a machine built with +new raises, as the host's does", @"it did not raise");
    } @catch (NSException *exception) {
        host(is([exception name], @"GKInitNotAllowedException"),
             @"a machine built with +new raises GKInitNotAllowedException", [exception name]);
    }
    // measure.m, "plain state" and "empty machine".
    {
        GKState *plain = [GKState state];
        host([plain isMemberOfClass:[GKState class]] && plain.stateMachine == nil &&
             [plain isValidNextState:[GKState class]],
             @"a plain state knows no machine and allows every transition, as the host's does",
             [NSString stringWithFormat:@"machine %d valid %d", plain.stateMachine != nil,
              (int)[plain isValidNextState:[GKState class]]]);
        GKStateMachine *empty = [GKStateMachine stateMachineWithStates:@[]];
        host(empty.currentState == nil && [empty canEnterState:[GKState class]] &&
             [empty stateForClass:[GKState class]] == nil && [empty stateForClass:Nil] == nil,
             @"a machine with no states has none, allows anything and finds nothing, as the host's does", nil);
    }
    // measure.m, "machine of two" through "fresh machine".
    {
        OpenA *a = [OpenA new];
        OpenB *b = [OpenB new];
        GKStateMachine *machine = [GKStateMachine stateMachineWithStates:@[a, b]];
        host(a.stateMachine == machine && [machine stateForClass:[OpenA class]] == a &&
             [machine stateForClass:[OpenB class]] == b,
             @"every state knows its machine and is found by its own class, as the host's does", nil);
        host([machine enterState:[OpenA class]] && machine.currentState == a,
             @"entering a state the machine allows enters it", nil);
        host([machine enterState:[OpenB class]] && machine.currentState == b,
             @"entering the next state, which the state leaving allows, enters it", nil);
        host(![machine enterState:[OpenA class]] && machine.currentState == b,
             @"entering a state the state leaving refuses does nothing and keeps the current state",
             named(machine.currentState));
        host(![machine canEnterState:[GKEntity class]] && ![machine enterState:[GKEntity class]],
             @"a class the machine holds no state of is neither enterable nor entered", nil);
        GKStateMachine *second = [GKStateMachine stateMachineWithStates:@[a, b]];
        host(a.stateMachine == second, @"a state given to a second machine belongs to that one, as the host's does", nil);
        GKStateMachine *third = [GKStateMachine stateMachineWithStates:@[b]];
        host([third canEnterState:[OpenB class]] && [third enterState:[OpenB class]] && third.currentState == b,
             @"a machine that has entered nothing allows anything, as the host's does", nil);
    }
    // The hooks, and the order of them.
    {
        NSMutableString *log = CharonGKHookLog();
        [log setString:@""];
        Leaving *a = [Leaving new];
        Arriving *b = [Arriving new];
        GKStateMachine *machine = [GKStateMachine stateMachineWithStates:@[a, b]];
        [machine enterState:[Leaving class]];
        [machine enterState:[Arriving class]];
        contract(is(log, @"A<nil A>Arriving B<Leaving "),
                 @"the state arriving is told it was entered after the state leaving was told it was left, "
                 @"and the first entry has no previous state", log);
    }
}

// -------------------------------------------------- entities, components, behaviours

@interface ProbeOne : GKComponent
@property (nonatomic, readonly) NSMutableString *log;
@end
@implementation ProbeOne
- (instancetype)init { self = [super init]; if (self) { _log = [NSMutableString string]; } return self; }
- (void)didAddToEntity { [_log appendString:@"add "]; }
- (void)willRemoveFromEntity { [_log appendString:@"remove "]; }
- (void)updateWithDeltaTime:(NSTimeInterval)seconds { [_log appendString:@"update "]; }
@end

@interface ProbeTwo : GKComponent @end
@implementation ProbeTwo @end

static void entitiesAndBehaviours(void)
{
    // measure.m, "new entity" through "removing the held one".
    {
        GKEntity *entity = [GKEntity entity];
        host(entity.components.count == 0, @"a new entity has no components, as the host's does", nil);
        [entity addComponent:[[ProbeOne alloc] init]];
        [entity addComponent:[[ProbeTwo alloc] init]];
        contract(entity.components.count == 2 &&
                 [entity componentForClass:[ProbeOne class]] != nil &&
                 [entity componentForClass:[ProbeTwo class]] != nil,
                 @"an entity holds a component of each class it is given", classes(entity.components));
        // measure.m gives "ProbeOne ProbeTwo" here and "ProbeTwo ProbeOne" for the other order, and
        // "C2 C1" for BOTH orders with two other class names: the host's order is a dictionary's and is
        // no order at all. The port's is the order the caller added in, which is the one it can rely on.
        contract(is(classes(entity.components), @"ProbeOne ProbeTwo"),
                 @"the port's own -components answers in the order the components were added, which the "
                 @"host's dictionary order is not", classes(entity.components));
        GKEntity *replaced = [GKEntity entity];
        [replaced addComponent:[[ProbeOne alloc] init]];
        [replaced addComponent:[[ProbeOne alloc] init]];
        host(replaced.components.count == 1, @"an entity holds one component per class, as the host's does", nil);
        GKComponent *held = [replaced componentForClass:[ProbeOne class]];
        host(held != nil && [replaced componentForClass:[ProbeTwo class]] == nil &&
             [replaced componentForClass:Nil] == nil && held.entity == replaced,
             @"a component is found by its class, an absent one is nil and it knows its entity", nil);
        [replaced removeComponentForClass:[ProbeTwo class]];
        host(replaced.components.count == 1, @"removing a class the entity has no component of changes nothing", nil);
        [replaced removeComponentForClass:[ProbeOne class]];
        host(replaced.components.count == 0 && held.entity == nil,
             @"removing the component takes it and makes it forget its entity", nil);
        host([GKEntity supportsSecureCoding] && [GKComponent supportsSecureCoding],
             @"an entity and a component both answer for secure coding, as the host's do", nil);
    }
    // measure.m, "archive round trip" and "copy".
    {
        GKEntity *carried = [GKEntity entity];
        [carried addComponent:[[ProbeOne alloc] init]];
        [carried addComponent:[[ProbeTwo alloc] init]];
        NSError *error = nil;
        NSData *bytes = nil;
        @try {
            bytes = [NSKeyedArchiver archivedDataWithRootObject:carried requiringSecureCoding:YES error:&error];
        } @catch (NSException *exception) {
            failed(@"contract", @"an entity archives with the secure-coding archiver", [exception reason]);
        }
        GKEntity *back = bytes ? [NSKeyedUnarchiver unarchivedObjectOfClass:[GKEntity class] fromData:bytes error:&error] : nil;
        contract(back != nil && back.components.count == 2 &&
                 [back componentForClass:[ProbeOne class]] != nil &&
                 [back componentForClass:[ProbeTwo class]] != nil,
                 @"an entity comes back from an archive with a component of each class it had",
                 classes(back.components));
        GKEntity *copied = [carried copy];
        contract(copied != carried && copied.components.count == 2 &&
                 copied.components.firstObject != carried.components.firstObject,
                 @"a copied entity is an entity of its own with a copy of each component", nil);
    }
    // What an entity tells a component. A contract check: the host's answer is in the facts file, and
    // the hooks are what the header says they are for.
    {
        GKEntity *entity = [GKEntity entity];
        ProbeOne *one = [[ProbeOne alloc] init];
        [entity addComponent:one];
        [entity updateWithDeltaTime:0.25];
        [entity removeComponentForClass:[ProbeOne class]];
        contract(is(one.log, @"add update remove "),
                 @"an entity tells a component it was added, updates it, and tells it when it is taken off",
                 one.log);
    }
    // measure.m, the component system.
    {
        GKComponentSystem *system = [[GKComponentSystem alloc] initWithComponentClass:[ProbeOne class]];
        host(system.componentClass == [ProbeOne class] && system.components.count == 0 &&
             [system classForGenericArgumentAtIndex:0] == [ProbeOne class] &&
             [system classForGenericArgumentAtIndex:1] == [ProbeOne class] &&
             [system classForGenericArgumentAtIndex:9] == [ProbeOne class],
             @"a component system knows its component class and answers it for every index, as the host's does", nil);
        @try {
            [system addComponent:[[ProbeTwo alloc] init]];
            host(NO, @"a component of another class is refused, as the host refuses it", @"it was taken");
        } @catch (NSException *exception) {
            host(is([exception name], @"NSInvalidArgumentException") &&
                 is([exception reason], @"component class is not supported by this system"),
                 @"a component of another class raises NSInvalidArgumentException with the host's own reason",
                 [NSString stringWithFormat:@"%s | %s", [[exception name] UTF8String], [[exception reason] UTF8String]]);
        }
        @try {
            [system addComponent:nil];
            host(NO, @"nil is refused the same way, as the host refuses it", @"it was taken");
        } @catch (NSException *exception) {
            host(is([exception name], @"NSInvalidArgumentException"),
                 @"adding nil raises NSInvalidArgumentException too", [exception name]);
        }
        ProbeOne *one = [[ProbeOne alloc] init];
        [system addComponent:one];
        [system addComponent:[[ProbeOne alloc] init]];
        host(system.components.count == 2 && [system objectAtIndexedSubscript:0] == one,
             @"a component system holds its own components in the order they were added, as the host's does", nil);
        NSUInteger enumerated = 0;
        for (id component in system) {
            enumerated++;
        }
        contract(enumerated == 2, @"a component system enumerates every component it holds", nil);
        GKEntity *holder = [GKEntity entity];
        [holder addComponent:[[ProbeOne alloc] init]];
        [system addComponentWithEntity:holder];
        host(system.components.count == 3, @"the entity's component of the system's class is taken, as the host's is", nil);
        GKEntity *wrong = [GKEntity entity];
        [wrong addComponent:[[ProbeTwo alloc] init]];
        [system addComponentWithEntity:wrong];
        host(system.components.count == 3, @"an entity with no component of the system's class adds nothing, as the host's does", nil);
        [system removeComponentWithEntity:holder];
        host(system.components.count == 2, @"removing by the entity takes the component it gave, as the host's does", nil);
        [system removeComponent:one];
        host(system.components.count == 1, @"removing by the component takes it out, as the host's does", nil);
    }
    // measure.m, the behaviour.
    {
        GKGoal *wander = [GKGoal goalToWander:1.0f];
        GKGoal *speed = [GKGoal goalToReachTargetSpeed:2.0f];
        GKBehavior *plain = [GKBehavior behaviorWithGoals:@[wander, speed]];
        host(plain.goalCount == 2 && [plain weightForGoal:[plain objectAtIndexedSubscript:0]] == 1.0f &&
             [plain weightForGoal:[plain objectAtIndexedSubscript:1]] == 1.0f,
             @"a behaviour of goals gives each of them a weight of one, as the host's does", nil);
        GKBehavior *empty = [[GKBehavior alloc] init];
        host(empty.goalCount == 0 && [empty weightForGoal:wander] == 0.0f,
             @"a new behaviour has no goals and weighs an absent one at zero, as the host's does", nil);
        // Read through the goals the behaviour itself holds: an NSDictionary copies its keys, and a
        // GKGoal's copy is a goal of its own, so the goals a behaviour ends up with are the copies the
        // dictionary made. Asking for a weight by the goal that went in would therefore find nothing --
        // on the host as much as here -- and the weight of each goal the behaviour holds is the thing
        // this method is for.
        GKBehavior *weighted = [GKBehavior behaviorWithWeightedGoals:@{wander: @3, speed: @7}];
        NSMutableArray *weights = [NSMutableArray array];
        for (GKGoal *goal in weighted) {
            [weights addObject:@([[weighted objectForKeyedSubscript:goal] floatValue])];
        }
        [weights sortUsingSelector:@selector(compare:)];
        host(weighted.goalCount == 2 && is(floats(weights), @"3 7"),
             @"a behaviour of weighted goals gives every goal the weight the dictionary carried for it",
             floats(weights));
        GKBehavior *resent = [GKBehavior behaviorWithGoal:wander weight:1.0f];
        [resent setWeight:5.0f forGoal:wander];
        host(resent.goalCount == 1 && [resent weightForGoal:wander] == 5.0f,
             @"weighing a goal twice keeps one goal and the last weight, as the host's does", nil);
        GKBehavior *keyed = [[GKBehavior alloc] init];
        [keyed setObject:@2.0f forKeyedSubscript:wander];
        GKGoal *third = [GKGoal goalToWander:3.0f];
        [keyed setObject:@4.0f forKeyedSubscript:third];
        host(keyed.goalCount == 2 && [[keyed objectForKeyedSubscript:wander] floatValue] == 2.0f &&
             [[keyed objectForKeyedSubscript:third] floatValue] == 4.0f &&
             [keyed objectForKeyedSubscript:speed] == nil,
             @"the keyed subscript of a goal is its weight and an absent goal has none, as the host's does", nil);
        NSUInteger enumerated = 0;
        for (GKGoal *goal in keyed) {
            enumerated++;
        }
        contract(enumerated == 2, @"a behaviour enumerates its goals", nil);
        GKBehavior *copied = [keyed copy];
        contract(copied != keyed && copied.goalCount == 2 && [copied weightForGoal:wander] == 2.0f &&
                 [copied weightForGoal:third] == 4.0f,
                 @"a copied behaviour is a behaviour of its own with the same goals and weights", nil);
        [keyed removeGoal:wander];
        host(keyed.goalCount == 1 && [keyed weightForGoal:wander] == 0.0f,
             @"removing a goal takes it and its weight, as the host's does", nil);
        [keyed removeAllGoals];
        host(keyed.goalCount == 0, @"removing every goal empties the behaviour, as the host's does", nil);
    }
    // measure.m, "goals N weights M" over every combination up to two and two, and "nil weights".
    {
        NSArray *expected = @[@[], @[], @[],
                              @"NSRangeException", @[@10], @[@10],
                              @"NSRangeException", @"NSRangeException", @[@10, @11]];
        NSUInteger at = 0;
        for (NSUInteger goals = 0; goals <= 2; goals++) {
            for (NSUInteger weights = 0; weights <= 2; weights++) {
                id want = expected[at++];
                NSMutableArray *goalList = [NSMutableArray array];
                NSMutableArray *weightList = [NSMutableArray array];
                for (NSUInteger index = 0; index < goals; index++) {
                    [goalList addObject:[GKGoal goalToWander:(float)index]];
                }
                for (NSUInteger index = 0; index < weights; index++) {
                    [weightList addObject:@((NSInteger)(10 + index))];
                }
                NSString *shape = [NSString stringWithFormat:@"%lu goals, %lu weights", (unsigned long)goals,
                                   (unsigned long)weights];
                if ([want isKindOfClass:[NSString class]]) {
                    @try {
                        [GKBehavior behaviorWithGoals:goalList andWeights:weightList];
                        host(NO, @"fewer weights than goals raises, as the host raises",
                             [shape stringByAppendingString:@": no exception"]);
                    } @catch (NSException *exception) {
                        host(is([exception name], want),
                             @"fewer weights than goals raises NSRangeException, as the host does",
                             [shape stringByAppendingString:@": "]);
                        host(is([exception name], want), @"fewer weights than goals raises the host's own exception",
                             [shape stringByAppendingString:[exception name]]);
                    }
                } else {
                    GKBehavior *made = [GKBehavior behaviorWithGoals:goalList andWeights:weightList];
                    NSMutableArray *weightsOut = [NSMutableArray array];
                    for (NSUInteger index = 0; index < (NSUInteger)made.goalCount; index++) {
                        [weightsOut addObject:@([made weightForGoal:[made objectAtIndexedSubscript:index]])];
                    }
                    NSString *answer = floats(weightsOut);
                    host(is(answer, floats(want)),
                         @"the weights a behaviour of goals and weights gives are the host's",
                         [shape stringByAppendingString:answer]);
                }
            }
        }
        GKBehavior *unweighted = [GKBehavior behaviorWithGoals:@[[GKGoal goalToWander:1.0f]] andWeights:nil];
        host(unweighted.goalCount == 1 && [unweighted weightForGoal:[unweighted objectAtIndexedSubscript:0]] == 0.0f,
             @"a nil weights array leaves every goal weighing nothing, as the host's does", nil);
    }
    // measure.m, the goals.
    {
        NSArray *refusals = @[@"goalToSeekAgent:", @"goalToFleeAgent:", @"goalToInterceptAgent:"];
        for (NSString *name in refusals) {
            @try {
                if ([name isEqualToString:@"goalToSeekAgent:"]) {
                    [GKGoal goalToSeekAgent:nil];
                } else if ([name isEqualToString:@"goalToFleeAgent:"]) {
                    [GKGoal goalToFleeAgent:nil];
                } else {
                    [GKGoal goalToInterceptAgent:nil maxPredictionTime:1];
                }
                host(NO, ([NSString stringWithFormat:@"+%@ with no agent raises, as the host's does", name]),
                     @"it did not raise");
            } @catch (NSException *exception) {
                host(is([exception name], @"NSInvalidArgumentException"),
                     ([NSString stringWithFormat:@"+%@ with no agent raises NSInvalidArgumentException, as the host's does", name]),
                     [exception name]);
            }
        }
        NSArray *goals = @[[GKGoal goalToAvoidObstacles:@[] maxPredictionTime:1],
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
        host(everyGoal, @"each of the other factories builds a GKGoal, as the host's do", nil);
        contract(everyCopy, @"each of them copies into a goal of its own", nil);
        contract([[[GKGoal alloc] init] isMemberOfClass:[GKGoal class]], @"a goal made with -init is a goal", nil);
    }
}

// ------------------------------------------------------------------------- rules

static void rules(void)
{
    // measure.m, the four-rule pass.
    {
        NSString *a = @"fact-a";
        NSString *b = @"fact-b";
        NSString *c = @"fact-c";
        GKRuleSystem *system = [[GKRuleSystem alloc] init];
        host(system.rules.count == 0 && system.agenda.count == 0 && system.executed.count == 0 &&
             system.facts.count == 0 && system.state.count == 0,
             @"a new system has no rules, no agenda, nothing executed, no facts and an empty state, as the host's does", nil);
        GKRule *bare = [[GKRule alloc] init];
        host(bare.salience == 0 && ![bare evaluatePredicateWithSystem:system],
             @"a bare rule has salience zero and never runs, as the host's does", nil);
        [bare performActionWithSystem:system];
        host(system.facts.count == 0, @"a bare rule's action does nothing, as the host's does", nil);
        GKRule *one = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]
                                assertingFact:a grade:0.5f];
        GKRule *two = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]
                                assertingFact:b grade:0.25f];
        GKRule *three = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"FALSEPREDICATE"]
                                  retractingFact:a grade:0.75f];
        GKRule *four = [GKRule ruleWithBlockPredicate:^BOOL(GKRuleSystem *inner) { return [inner gradeForFact:a] >= 0.5f; }
                                              action:^(GKRuleSystem *inner) { [inner assertFact:c grade:0.125f]; }];
        one.salience = 0;
        two.salience = 5;
        three.salience = 5;
        four.salience = -3;
        [system addRulesFromArray:@[one, two, three, four]];
        host(system.rules.count == 4 && is(saliences(system.agenda), @"5 5 0 -3"),
             @"the agenda holds every rule by salience, highest first, as soon as they are added, as the host's does",
             saliences(system.agenda));
        [system evaluate];
        host(is(saliences(system.executed), @"5 0 -3") && is(saliences(system.agenda), @"5"),
             @"a rule whose predicate an earlier action made true fires in the same pass, and the one that "
             @"never fired stays in the agenda, as the host's does",
             [NSString stringWithFormat:@"executed %@ agenda %@", saliences(system.executed), saliences(system.agenda)]);
        host([system gradeForFact:a] == 0.5f && [system gradeForFact:b] == 0.25f &&
             [system gradeForFact:c] == 0.125f && system.facts.count == 3 && system.state.count == 0,
             @"the three grades are what the actions left and the state is still empty, as the host's does", nil);
        host([system minimumGradeForFacts:@[]] == 1.0f && [system maximumGradeForFacts:@[]] == 0.0f &&
             [system minimumGradeForFacts:@[a, b]] == 0.25f && [system maximumGradeForFacts:@[a, b]] == 0.5f &&
             [system gradeForFact:@"never-asserted"] == 0.0f,
             @"the folds of an empty list are one and zero and an unasserted fact weighs zero, as the host's do", nil);
        [system assertFact:a];
        [system assertFact:a];
        host([system gradeForFact:a] == 1.0f, @"a grade is clamped at one, as the host clamps it", nil);
        [system retractFact:a grade:5.0f];
        host([system gradeForFact:a] == 0.0f, @"a grade is clamped at zero, as the host clamps it", nil);
        [system reset];
        host(is(saliences(system.agenda), @"5 5 0 -3") && system.executed.count == 0 &&
             system.facts.count == 0 && system.rules.count == 4 && [system gradeForFact:a] == 0.0f &&
             system.state.count == 0,
             @"a reset puts every rule back in the agenda and takes the facts, the grades and the state, as the host's does",
             saliences(system.agenda));
        [system addRule:[GKRule ruleWithPredicate:nil assertingFact:@"late" grade:1.0f]];
        host(system.rules.count == 5 && is(saliences(system.agenda), @"5 5 0 0 -3"),
             @"a rule added after a reset joins the agenda, as the host's does", saliences(system.agenda));
        [system removeAllRules];
        host(system.rules.count == 0 && system.agenda.count == 0,
             @"removing every rule takes the agenda with them, as the host's does", nil);
        system.state[@"written"] = @1;
        host(system.state.count == 1, @"the state is the caller's to write in, as the host's is", nil);
    }
    // measure.m, "a substituted variable", "an absent variable", "a key path through state",
    // "a block predicate" and "a rule with no predicate".
    {
        GKRuleSystem *system = [[GKRuleSystem alloc] init];
        [system.state setObject:@1 forKey:@"mine"];
        GKRule *substituted = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"$mine == 1"]
                                          assertingFact:@"f" grade:1.0f];
        host([substituted evaluatePredicateWithSystem:system],
             @"a predicate's substitution variables are the system's state, as the host reads them", nil);
        @try {
            GKRule *absent = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"$absent == 1"]
                                       assertingFact:@"f" grade:1.0f];
            [absent evaluatePredicateWithSystem:system];
            host(NO, @"a predicate with a missing binding raises, as the host's does", @"it answered");
        } @catch (NSException *exception) {
            host(is([exception name], @"NSInvalidArgumentException"),
                 @"a predicate with a missing binding raises NSInvalidArgumentException, as the host's does",
                 [exception name]);
        }
        GKRule *keyPath = [GKRule ruleWithPredicate:[NSPredicate predicateWithFormat:@"state.count == 1"]
                                     assertingFact:@"f" grade:1.0f];
        host(![keyPath evaluatePredicateWithSystem:system],
             @"a key path reads the system's key-value coding and not its state, as the host's does", nil);
        __block BOOL sawSystem = NO;
        __block NSUInteger bindings = 0;
        GKRule *block = [GKRule ruleWithBlockPredicate:^BOOL(GKRuleSystem *inner) {
            sawSystem = inner == system;
            bindings = inner.state.count;
            return YES;
        } action:nil];
        host([block evaluatePredicateWithSystem:system] && sawSystem && bindings == 1,
             @"a block predicate is handed the system itself, with the state's entries reachable", nil);
        GKNSPredicateRule *noPredicate = [[GKNSPredicateRule alloc] initWithPredicate:nil];
        host([noPredicate predicate] == nil && ![noPredicate evaluatePredicateWithSystem:system],
             @"a rule with no predicate never fires, as the host's does not", nil);
        GKRule *fromFactory = [GKRule ruleWithPredicate:nil assertingFact:@"k" grade:1.0f];
        host([fromFactory isMemberOfClass:[GKNSPredicateRule class]],
             @"a predicate rule is a GKNSPredicateRule, the public class the port answers",
             NSStringFromClass([fromFactory class]));
        GKRule *fromBlock = [GKRule ruleWithBlockPredicate:nil action:nil];
        host([fromBlock isKindOfClass:[GKRule class]],
             @"a block rule is a rule, and the port answers the public class its header names",
             NSStringFromClass([fromBlock class]));
    }
    // measure.m, "agenda after one add" through "added past an evaluate".
    {
        GKRuleSystem *keys = [[GKRuleSystem alloc] init];
        [keys addRule:[[GKRule alloc] init]];
        host(keys.agenda.count == 1, @"one rule added is one rule in the agenda, as the host's is", nil);
        GKRule *ranked = [GKRule ruleWithPredicate:nil assertingFact:@"k" grade:1.0f];
        ranked.salience = 10;
        [keys addRule:ranked];
        host(is(saliences(keys.agenda), @"10 0"),
             @"a higher rule goes to the front of the agenda, as the host's does", saliences(keys.agenda));
        [keys evaluate];
        host(is(saliences(keys.agenda), @"10 0") && keys.executed.count == 0,
             @"a rule whose predicate is absent does not fire, so the agenda keeps both, as the host's does",
             [NSString stringWithFormat:@"agenda %@ executed %@", saliences(keys.agenda), saliences(keys.executed)]);
        [keys addRule:[[GKRule alloc] init]];
        host(keys.rules.count == 3 && is(saliences(keys.agenda), @"10 0 0"),
             @"a rule added after an evaluation joins the agenda that evaluation left, as the host's does",
             saliences(keys.agenda));
    }
}

// ------------------------------------------------------------ distributions and the shuffle

static void distributions(void)
{
    // measure.m, the ranges.
    {
        GKRandomDistribution *plain = [[GKRandomDistribution alloc] init];
        host(plain.lowestValue == 0 && plain.highestValue == 0 && plain.numberOfPossibleOutcomes == 1,
             @"a distribution with no range of its own is the degenerate one over zero and zero, as the host's is",
             [NSString stringWithFormat:@"%ld..%ld", (long)plain.lowestValue, (long)plain.highestValue]);
        GKRandomDistribution *six = [GKRandomDistribution d6];
        GKRandomDistribution *twenty = [GKRandomDistribution d20];
        GKRandomDistribution *oneSide = [GKRandomDistribution distributionForDieWithSideCount:1];
        host(six.lowestValue == 1 && six.highestValue == 6 && six.numberOfPossibleOutcomes == 6 &&
             twenty.lowestValue == 1 && twenty.highestValue == 20 && twenty.numberOfPossibleOutcomes == 20 &&
             oneSide.lowestValue == 1 && oneSide.highestValue == 1,
             @"the three die factories give the ranges their names say, as the host's do", nil);
        GKRandomDistribution *inverted = [[GKRandomDistribution alloc] initWithRandomSource:nil
                                                                                  lowestValue:5 highestValue:1];
        host(inverted.lowestValue == 5 && inverted.highestValue == 1 &&
             inverted.numberOfPossibleOutcomes == (NSUInteger)0xFFFFFFFFFFFFFFFDULL &&
             [inverted nextInt] == 5 && [inverted nextUniform] == 5.0f,
             @"an inverted range is kept, and its outcome count wraps, as the host's wraps",
             [NSString stringWithFormat:@"%lu outcomes", (unsigned long)inverted.numberOfPossibleOutcomes]);
        @try {
            [inverted nextIntWithUpperBound:3];
            host(NO, @"a bound below the lowest raises, as the host raises", @"it answered");
        } @catch (NSException *exception) {
            host(is([exception name], @"NSInvalidArgumentException") &&
                 is([exception reason], @"upper bound provided is less than lowestInclusive"),
                 @"a bound below the lowest raises NSInvalidArgumentException with the host's own reason",
                 [NSString stringWithFormat:@"%s | %s", [[exception name] UTF8String], [[exception reason] UTF8String]]);
        }
        GKGaussianDistribution *overRange = [[GKGaussianDistribution alloc] initWithRandomSource:nil
                                                                                     lowestValue:1
                                                                                    highestValue:20];
        GKGaussianDistribution *overMoments = [[GKGaussianDistribution alloc] initWithRandomSource:nil
                                                                                             mean:10.5f
                                                                                         deviation:19.0f / 6.0f];
        host(overRange.mean == 10.5f && overRange.deviation == 19.0f / 6.0f &&
             overMoments.mean == 10.5f && overMoments.deviation == 19.0f / 6.0f &&
             overRange.lowestValue == 1 && overRange.highestValue == 20 &&
             overMoments.lowestValue == 1 && overMoments.highestValue == 20,
             @"a gaussian takes the middle of a range and a sixth of it, and three deviations around a "
             @"mean, as the host's does",
             [NSString stringWithFormat:@"%g %g %ld..%ld %ld..%ld", overRange.mean, overRange.deviation,
              (long)overRange.lowestValue, (long)overRange.highestValue,
              (long)overMoments.lowestValue, (long)overMoments.highestValue]);
    }
    // measure.m, "a d6 over the script" and the line under it.
    {
        CharonGKScriptedSource *source = [[CharonGKScriptedSource alloc]
                                          initWithScript:@[@"bounded:6=2", @"bounded:6=5", @"bounded:6=1",
                                                           @"bounded:6=4", @"bounded:6=0", @"bounded:6=3"]];
        GKRandomDistribution *die = [[GKRandomDistribution alloc] initWithRandomSource:source
                                                                           lowestValue:1 highestValue:6];
        NSMutableArray *draws = [NSMutableArray array];
        for (NSUInteger index = 0; index < 6; index++) {
            [draws addObject:@([die nextInt])];
        }
        BOOL right = is(source.log, @"bounded:6=2 bounded:6=5 bounded:6=1 bounded:6=4 bounded:6=0 bounded:6=3") &&
            is(floats(draws), @"3 6 2 5 1 4");
        host(right, @"a distribution draws from its source for the whole range and adds the lowest, as the host's does",
             [NSString stringWithFormat:@"asked '%s' gave %@", source.log, floats(draws)]);
    }
    {
        CharonGKScriptedSource *bools = [[CharonGKScriptedSource alloc]
                                         initWithScript:@[@"bool=1", @"bool=0", @"bool=1", @"bool=1", @"bool=0"]];
        GKRandomDistribution *coin = [[GKRandomDistribution alloc] initWithRandomSource:bools
                                                                           lowestValue:0 highestValue:1];
        BOOL first = [coin nextBool];
        BOOL second = [coin nextBool];
        BOOL third = [coin nextBool];
        host(is(bools.log, @"bool=1 bool=0 bool=1") && first && !second && third,
             @"a distribution's -nextBool is the source's own -nextBool, as the host's is",
             [NSString stringWithFormat:@"asked '%s'", bools.log]);
    }
    {
        CharonGKScriptedSource *uniform = [[CharonGKScriptedSource alloc]
                                           initWithScript:@[@"bounded:6=3", @"bounded:6=0", @"bounded:6=5"]];
        GKRandomDistribution *faces = [[GKRandomDistribution alloc] initWithRandomSource:uniform
                                                                            lowestValue:1 highestValue:6];
        float first = [faces nextUniform];
        float second = [faces nextUniform];
        float third = [faces nextUniform];
        host(is(uniform.log, @"bounded:6=3 bounded:6=0 bounded:6=5") &&
             first == 4.0f / 6.0f && second == 1.0f / 6.0f && third == 6.0f / 6.0f,
             @"a distribution's -nextUniform is its own integer over the highest value, quantised, as the "
             @"host's is",
             [NSString stringWithFormat:@"asked '%s' gave %g %g %g", uniform.log, first, second, third]);
    }
    // measure.m, "nextIntWithUpperBound over 2..5" and "over -2..2": which span is asked for.
    {
        const NSInteger lows[] = {-2, 0, 2, 3};
        const NSInteger highs[] = {2, 2, 5, 3};
        // measure.m prints the same lines with an empty script: what the source was asked for, as
        // starved(bounded:N) because the script had nothing left to give.
        const char *asks[] = {
            "starved(bounded:5) starved(bounded:3) starved(bounded:4) starved(bounded:5) starved(bounded:5) "
            "starved(bounded:5) starved(bounded:5) starved(bounded:5) starved(bounded:5)",
            "starved(bounded:3) starved(bounded:1) starved(bounded:2) starved(bounded:3) starved(bounded:3) "
            "starved(bounded:3) starved(bounded:3) starved(bounded:3) starved(bounded:3)",
            "starved(bounded:0) starved(bounded:1) starved(bounded:2) starved(bounded:3) starved(bounded:4) "
            "starved(bounded:4) starved(bounded:4)",
            // over 3..3, bounds 3..8: the span is 0 for the bound that matches the lowest and 1 for
            // every bound above it, because the whole range is one outcome.
            "starved(bounded:0) starved(bounded:1) starved(bounded:1) starved(bounded:1) "
            "starved(bounded:1) starved(bounded:1)"};
        for (unsigned range = 0; range < 4; range++) {
            NSMutableArray *got = [NSMutableArray array];
            for (NSUInteger bound = 0; bound <= 8; bound++) {
                CharonGKScriptedSource *fresh = [[CharonGKScriptedSource alloc] initWithScript:@[]];
                GKRandomDistribution *distribution = [[GKRandomDistribution alloc] initWithRandomSource:fresh
                                                                                            lowestValue:lows[range]
                                                                                           highestValue:highs[range]];
                if ((NSInteger)bound < lows[range]) {
                    @try {
                        [distribution nextIntWithUpperBound:bound];
                        host(NO, @"a bound below the lowest raises",
                             [NSString stringWithFormat:@"%lu answered", (unsigned long)bound]);
                    } @catch (NSException *exception) {
                        host(is([exception name], @"NSInvalidArgumentException"),
                             @"a bound below the lowest raises NSInvalidArgumentException", [exception name]);
                    }
                    continue;
                }
                [distribution nextIntWithUpperBound:bound];
                [got addObject:fresh.log];
            }
            NSString *want = [NSString stringWithUTF8String:asks[range]];
            host(is([got componentsJoinedByString:@" "], want),
                 @"the spans a bounded draw asks its source for are the host's, and a bound of zero asks "
                 @"for the whole range", [got componentsJoinedByString:@" "]);
        }
        // And the answer: the draw plus the lowest, or the draw alone when the lowest is below zero.
        CharonGKScriptedSource *drawn = [[CharonGKScriptedSource alloc] initWithScript:@[@"bounded:4=3"]];
        GKRandomDistribution *negative = [[GKRandomDistribution alloc] initWithRandomSource:drawn
                                                                                lowestValue:-2 highestValue:2];
        unsigned long first = (unsigned long)[negative nextIntWithUpperBound:2];
        host(first == 3,
             @"a draw over a range whose lowest is below zero answers the draw and not the draw plus the lowest",
             [NSString stringWithFormat:@"%lu", first]);
    }
    // measure.m, "a gaussian over the script" and the line under it.
    {
        CharonGKScriptedSource *source = [[CharonGKScriptedSource alloc]
                                          initWithScript:@[@"uniform=0.25", @"uniform=0.75", @"uniform=0.5",
                                                           @"uniform=0.1", @"uniform=0.9"]];
        GKGaussianDistribution *gaussian = [[GKGaussianDistribution alloc] initWithRandomSource:source
                                                                                    lowestValue:0
                                                                                   highestValue:100];
        NSMutableArray *draws = [NSMutableArray array];
        for (NSUInteger index = 0; index < 3; index++) {
            [draws addObject:@([gaussian nextInt])];
        }
        host(is(floats(draws), @"50 66 58"),
             @"a gaussian asks for two uniforms per draw and combines them the host's way",
             [NSString stringWithFormat:@"gave %@ asked '%s'", floats(draws), source.log]);
    }
    // measure.m, "a shuffled d6 over the script" and the line under it.
    {
        CharonGKScriptedSource *source = [[CharonGKScriptedSource alloc]
                                          initWithScript:@[@"bounded:1=0", @"bounded:2=1", @"bounded:3=2",
                                                           @"bounded:4=0", @"bounded:5=3", @"bounded:6=5",
                                                           @"bounded:1=0", @"bounded:2=1", @"bounded:3=0"]];
        GKShuffledDistribution *bag = [[GKShuffledDistribution alloc] initWithRandomSource:source
                                                                                lowestValue:1 highestValue:6];
        NSMutableArray *draws = [NSMutableArray array];
        for (NSUInteger index = 0; index < 9; index++) {
            [draws addObject:@([bag nextInt])];
        }
        BOOL right = is(floats(draws), @"6 1 5 3 2 4 5 4 3") &&
            [source.log hasPrefix:@"bounded:1=0 bounded:2=1 bounded:3=2 bounded:4=0 bounded:5=3 bounded:6=5 bounded:1=0"];
        host(right, @"a shuffled distribution shuffles forward once per pass and hands the values out from "
             @"the back, as the host's does",
             [NSString stringWithFormat:@"gave %@ asked '%s'", floats(draws), source.log]);
        contract([source.log rangeOfString:@"starved"].location != NSNotFound,
                 @"a nine-draw pass over a six-value range asks for a second pass and runs out of script",
                 source.log);
    }
    // measure.m, the shuffle NSArray carries: the host hands the array to the source and returns what
    // the source answers.
    {
        CharonGKScriptedSource *source = [[CharonGKScriptedSource alloc] initWithScript:@[]];
        NSArray *array = @[@1, @2, @3, @4];
        NSArray *given = [array shuffledArrayWithRandomSource:source];
        host(is(source.log, @"shuffle(4)") && source.shuffleAskedWith == array && given == array,
             @"the shuffle a caller asks for is the source's own, as the host's is",
             [NSString stringWithFormat:@"asked '%s' with %lu", source.log,
              (unsigned long)source.shuffleAskedWith.count]);
        CharonGKScriptedSource *empty = [[CharonGKScriptedSource alloc] initWithScript:@[]];
        CharonGKScriptedSource *single = [[CharonGKScriptedSource alloc] initWithScript:@[]];
        contract([@[] shuffledArrayWithRandomSource:empty].count == 0 &&
                 [@[@1] shuffledArrayWithRandomSource:single].count == 1,
                 @"a shuffle of four objects is four and of none is none", nil);
        NSArray *own = [@[@1, @2, @3, @4, @5, @6, @7, @8] shuffledArray];
        contract(own.count == 8, @"the system's own shuffle keeps every object", nil);
        NSMutableArray *seen = [NSMutableArray array];
        for (NSNumber *number in own) {
            [seen addObject:number];
        }
        contract([seen count] == 8, @"the shuffle is a permutation of what went in", nil);
        for (NSNumber *number in own) {
            contract([seen containsObject:number], @"every object of the input is in the output", nil);
        }
    }
    // The one place the port answers where the host's is undefined, recorded so a later change is told
    // from it: -[GKEntity components] has no order on the host at all.
    {
        GKEntity *entity = [GKEntity entity];
        [entity addComponent:[[ProbeOne alloc] init]];
        [entity addComponent:[[ProbeTwo alloc] init]];
        diverge(is(classes(entity.components), @"ProbeOne ProbeTwo"),
                @"the port answers -components in the order the components were added, which the host's "
                @"dictionary order is not (measure.m gives ProbeOne ProbeTwo here and C2 C1 for two other "
                @"class names)");
    }
}

int main(void)
{
    @autoreleasepool {
        stateMachines();
        entitiesAndBehaviours();
        rules();
        distributions();
    }
    printf("%d checks, %d failed\n", checksRun, checksFailed);
    return checksFailed == 0 ? 0 : 1;
}
