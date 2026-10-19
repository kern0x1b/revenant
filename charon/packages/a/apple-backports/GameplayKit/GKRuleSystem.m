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

- (NSArray<GKRule *> *)charon_rankedRules
{
    return [_rules sortedArrayUsingComparator:^NSComparisonResult(GKRule *left, GKRule *right) {
        if (left.salience == right.salience) {
            return NSOrderedSame;
        }
        return left.salience > right.salience ? NSOrderedAscending : NSOrderedDescending;
    }];
}

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
