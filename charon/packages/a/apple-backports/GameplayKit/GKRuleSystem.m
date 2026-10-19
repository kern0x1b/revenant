// GKRuleSystem.m -- a rule, the system of rules, and the rule over an NSPredicate. GameplayKit
// framework carries no code at all before iOS 9 (GK_BASE_AVAILABILITY is NS_CLASS_AVAILABLE(10_11, 9_0)
// and the 6.1.3 armv7 cache exports no GameplayKit class), so this is this port's own; what the system
// does was measured on the host by tests/backports/host/gameplaykit-core/measure.m, rule by rule:
//
//   -evaluate puts the rules in the agenda by salience, highest first, ties in the order they were
//   added, then walks the agenda once and fires every rule whose predicate is true *at the moment
//   it is reached* -- so an action that raises a grade can make a later rule's predicate true, which
//   is what the host does: four rules with saliences 0, 5, 5 and -3, of which the third's predicate
//   was false and the fourth's read a grade the second and the first had not yet raised, fire in the
//   order 5, 0, -3 and leave the rule of salience 5 that never fired in the agenda, measured. A rule
//   fires at most once in a pass and every rule that fires is in -executed in the order it fired.
//   A predicate is evaluated with the *system* as its object, so -[NSPredicate evaluateWithObject:]
//   is called with the system and a key path in a predicate reads the system's key-value coding, not
//   its -state dictionary, measured.
//   A fact's grade is raised by -assertFact:grade: and lowered by -retractFact:grade:, and both clamp
//   it to [0, 1]: asserting twice with a grade of 1 leaves 1 and retracting with a grade of 5 leaves
//   0, measured. -assertFact: and -retractFact: are those with a grade of 1.
//   -gradeForFact: of a fact never asserted is 0, -minimumGradeForFacts: of an empty list is 1 and
//   -maximumGradeForFacts: of an empty list is 0, the neutral elements of the two, measured.
//   -reset clears the agenda, the executed rules, the facts and the grades and keeps the rules;
//   -removeAllRules takes the rules as well, measured. The agenda is kept, not built at -evaluate:
//   -addRule: puts the rule in it at its place by salience, so a system that has just been given
//   rules already has an agenda of them, an addition past an -evaluate goes into the agenda the
//   -evaluate left behind, and a -reset re-ranks it over every rule, all measured.
//   -state is an empty mutable dictionary the caller may use, and stays empty unless the caller puts
//   something in it: the grades live in the system itself, not in -state, measured, and it is the
//   predicate's substitution variables, measured.
//   A rule's salience is 0 until it is set, measured. A rule built by either predicate factory is a
//   private subclass of the host's (_GKNSPredicateRule, _GKBlockRule); the port answers the public
//   class its own header names, and facts/GameplayKit/RuleSystem.md says so.
//
// Every property here is answered from an ivar this file keeps with a getter of the class's own, so
// clang auto-synthesizes none and no pragma says it should.

#import "CharonGK.h"

@implementation GKRule {
    NSInteger _salience;
    void (^_action)(GKRuleSystem *);
    id _fact;
    float _grade;
    BOOL _asserts;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _asserts = YES;
    }
    return self;
}

- (NSInteger)salience
{
    return _salience;
}

- (void)setSalience:(NSInteger)salience
{
    _salience = salience;
}

// A rule that has no predicate of its own -- a bare GKRule, which a subclass fills in -- does not run:
// the host's own bare rule answers NO here, measured, and a subclass is expected to override this to
// say YES. Every rule the factories build is a GKNSPredicateRule, which has a predicate of its own.
- (BOOL)evaluatePredicateWithSystem:(GKRuleSystem *)system
{
    return NO;
}

- (void)performActionWithSystem:(GKRuleSystem *)system
{
    if (_action) {
        _action(system);
    } else if (_fact) {
        if (_asserts) {
            [system assertFact:_fact grade:_grade];
        } else {
            [system retractFact:_fact grade:_grade];
        }
    }
}

+ (instancetype)ruleWithPredicate:(NSPredicate *)predicate assertingFact:(id<NSObject>)fact grade:(float)grade
{
    GKNSPredicateRule *rule = [[GKNSPredicateRule alloc] initWithPredicate:predicate];
    [rule charon_grade:grade asserting:YES fact:fact];
    return rule;
}

+ (instancetype)ruleWithPredicate:(NSPredicate *)predicate retractingFact:(id<NSObject>)fact grade:(float)grade
{
    GKNSPredicateRule *rule = [[GKNSPredicateRule alloc] initWithPredicate:predicate];
    [rule charon_grade:grade asserting:NO fact:fact];
    return rule;
}

+ (instancetype)ruleWithBlockPredicate:(BOOL (^)(GKRuleSystem *))predicate action:(void (^)(GKRuleSystem *))action
{
    // The block is handed the system, which is what a rule's predicate is evaluated with, so it is
    // wrapped in a predicate of the same shape rather than answered from a side channel.
    NSPredicate *wrapped = predicate ? [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return predicate((GKRuleSystem *)object);
    }] : nil;
    GKNSPredicateRule *rule = [[GKNSPredicateRule alloc] initWithPredicate:wrapped];
    [rule charon_setAction:action];
    return rule;
}

- (void)charon_setAction:(void (^)(GKRuleSystem *))action
{
    _action = [action copy];
}

- (void)charon_grade:(float)grade asserting:(BOOL)asserts fact:(id<NSObject>)fact
{
    _grade = grade;
    _asserts = asserts;
    _fact = fact;
}

@end

@implementation GKNSPredicateRule {
    NSPredicate *_predicate;
}

- (instancetype)initWithPredicate:(NSPredicate *)predicate
{
    self = [super init];
    if (self) {
        _predicate = predicate;
    }
    return self;
}

- (NSPredicate *)predicate
{
    return _predicate;
}

- (BOOL)evaluatePredicateWithSystem:(GKRuleSystem *)system
{
    // The system is the predicate's object and the system's own -state dictionary is the source of
    // its substitution variables, which is what GKRuleSystem.h says and what the host does: with
    // state[@"mine"] = 1 the predicate "$mine == 1" answers YES and "$absent == 1" raises
    // NSInvalidArgumentException from NSPredicate for the missing binding, measured. A rule with no
    // predicate at all never fires, measured: the two factories both build a rule with a predicate,
    // and a predicate handed as nil leaves it with none.
    if (!_predicate) {
        return NO;
    }
    return [_predicate evaluateWithObject:system substitutionVariables:[system state]];
}

@end

@implementation GKRuleSystem {
    NSMutableArray<GKRule *> *_rules;
    NSMutableArray<GKRule *> *_agenda;
    NSMutableArray<GKRule *> *_executed;
    NSMutableDictionary *_grades;
    NSMutableDictionary *_state;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _rules = [NSMutableArray array];
        _agenda = [NSMutableArray array];
        _executed = [NSMutableArray array];
        _grades = [NSMutableDictionary dictionary];
        _state = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSMutableDictionary *)state
{
    return _state;
}

- (NSArray<GKRule *> *)rules
{
    return [_rules copy];
}

- (NSArray<GKRule *> *)agenda
{
    return [_agenda copy];
}

- (NSArray<GKRule *> *)executed
{
    return [_executed copy];
}

- (NSArray *)facts
{
    return [_grades allKeys];
}

// The agenda is kept as it stands: every rule by salience, highest first, ties in the order they
// were added, and a rule that fired is out of it until a reset puts it back. A reset leaves the
// system in this state, which is what the host's own reset answers -- a system that has been reset
// is ready to be evaluated again, and its agenda is the whole of its rules until an evaluation
// moves the ones that fire out of it.
- (NSArray<GKRule *> *)charon_rankedRules
{
    return [_rules sortedArrayUsingComparator:^NSComparisonResult(GKRule *left, GKRule *right) {
        if (left.salience == right.salience) {
            return NSOrderedSame;
        }
        return left.salience > right.salience ? NSOrderedAscending : NSOrderedDescending;
    }];
}

// The place a rule of this salience belongs in the agenda: after every rule of at least its own
// salience, and before every rule of a lower one, so that a tie keeps the order it was added in.
- (NSUInteger)charon_placeInAgendaFor:(GKRule *)rule
{
    NSUInteger index = 0;
    while (index < [_agenda count] && [_agenda[index] salience] >= [rule salience]) {
        index++;
    }
    return index;
}

- (void)addRule:(GKRule *)rule
{
    if (rule) {
        [_rules addObject:rule];
        [_agenda insertObject:rule atIndex:[self charon_placeInAgendaFor:rule]];
    }
}

- (void)addRulesFromArray:(NSArray<GKRule *> *)rules
{
    for (GKRule *rule in rules) {
        [self addRule:rule];
    }
}

- (void)removeAllRules
{
    [_rules removeAllObjects];
    [_agenda removeAllObjects];
    [_executed removeAllObjects];
}

- (void)evaluate
{
    // The rules that fire are taken out of the agenda as they fire, so what is left in the agenda
    // afterwards is what did not fire. A rule's predicate is asked at the moment the walk reaches
    // it, so a rule that fires early can be the reason a rule further down the agenda fires at all.
    // The agenda is the one the system has been keeping, not one built here: a rule added since the
    // last -evaluate is in it and a rule that fired is not, both measured.
    [_executed removeAllObjects];
    for (NSUInteger index = 0; index < [_agenda count]; index++) {
        GKRule *rule = _agenda[index];
        if ([rule evaluatePredicateWithSystem:self]) {
            [_agenda removeObjectAtIndex:index];
            index--;
            [_executed addObject:rule];
            [rule performActionWithSystem:self];
        }
    }
}

- (float)gradeForFact:(id<NSObject>)fact
{
    return fact ? [_grades[fact] floatValue] : 0.0f;
}

- (float)minimumGradeForFacts:(NSArray *)facts
{
    float lowest = 1.0f;
    for (id<NSObject> fact in facts) {
        lowest = MIN(lowest, [self gradeForFact:fact]);
    }
    return lowest;
}

- (float)maximumGradeForFacts:(NSArray *)facts
{
    float highest = 0.0f;
    for (id<NSObject> fact in facts) {
        highest = MAX(highest, [self gradeForFact:fact]);
    }
    return highest;
}

- (void)assertFact:(id<NSObject>)fact
{
    [self assertFact:fact grade:1.0f];
}

- (void)assertFact:(id<NSObject>)fact grade:(float)grade
{
    [self charon_moveFact:fact by:grade];
}

- (void)retractFact:(id<NSObject>)fact
{
    [self retractFact:fact grade:1.0f];
}

- (void)retractFact:(id<NSObject>)fact grade:(float)grade
{
    [self charon_moveFact:fact by:-grade];
}

- (void)charon_moveFact:(id<NSObject>)fact by:(float)delta
{
    if (!fact) {
        return;
    }
    float grade = [self gradeForFact:fact] + delta;
    if (grade < 0.0f) {
        grade = 0.0f;
    }
    if (grade > 1.0f) {
        grade = 1.0f;
    }
    _grades[fact] = @(grade);
}

- (void)reset
{
    [_agenda setArray:[self charon_rankedRules]];
    [_executed removeAllObjects];
    [_grades removeAllObjects];
    [_state removeAllObjects];
}

@end