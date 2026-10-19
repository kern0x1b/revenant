#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wnonnull"

static uint64_t state = 0x9E3779B97F4A7C15ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static Class portChange, portDifference;

typedef id (^Body)(void);

static NSString *safely(Body body, BOOL exact)
{
    @try {
        id result = body();
        return result ? [NSString stringWithFormat:@"%@", result] : @"(nil)";
    } @catch (NSException *exception) {
        return exact ? [NSString stringWithFormat:@"raises %@ | %@ | %@", exception.name, exception.reason, exception.userInfo] : [NSString stringWithFormat:@"raises %@", exception.name];
    }
}

static NSString *normalized(NSString *text)
{
    NSMutableString *result = [text mutableCopy];
    [result replaceOccurrencesOfString:@"CharonHost" withString:@"" options:0 range:NSMakeRange(0, result.length)];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
    return [expression stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"0x"];
}

static id makeChange(BOOL port, id object, NSInteger type, NSUInteger index, NSUInteger associated)
{
    Class cls = port ? portChange : [NSOrderedCollectionChange class];
    return [cls changeWithObject:object type:(NSCollectionChangeType)type index:index associatedIndex:associated];
}

static NSString *shape(id difference)
{
    NSMutableString *text = [NSMutableString string];
    for (id change in difference)
        [text appendFormat:@"%c%lu:%@:%lu ", [change changeType] == NSCollectionChangeInsert ? '+' : '-', (unsigned long)[change index], [change object] ?: @"-", (unsigned long)[change associatedIndex]];
    [text appendString:@"| ins"];
    for (id change in [difference insertions])
        [text appendFormat:@" %lu:%@:%lu", (unsigned long)[change index], [change object] ?: @"-", (unsigned long)[change associatedIndex]];
    [text appendString:@" | rem"];
    for (id change in [difference removals])
        [text appendFormat:@" %lu:%@:%lu", (unsigned long)[change index], [change object] ?: @"-", (unsigned long)[change associatedIndex]];
    [text appendFormat:@" | %d", [difference hasChanges]];
    return text;
}

static id diffArrays(BOOL port, NSArray *current, NSArray *other, NSUInteger options, BOOL (^test)(id, id))
{
    if (!port)
        return test ? [current differenceFromArray:other withOptions:options usingEquivalenceTest:test] : [current differenceFromArray:other withOptions:options];
    if (test)
        return ((id (*)(id, SEL, id, NSUInteger, id))objc_msgSend)(current, NSSelectorFromString(@"charonHostDifferenceFromArray:withOptions:usingEquivalenceTest:"), other, options, test);
    return ((id (*)(id, SEL, id, NSUInteger))objc_msgSend)(current, NSSelectorFromString(@"charonHostDifferenceFromArray:withOptions:"), other, options);
}

static id diffSets(BOOL port, NSOrderedSet *current, NSOrderedSet *other, NSUInteger options, BOOL (^test)(id, id))
{
    if (!port)
        return test ? [current differenceFromOrderedSet:other withOptions:options usingEquivalenceTest:test] : [current differenceFromOrderedSet:other withOptions:options];
    if (test)
        return ((id (*)(id, SEL, id, NSUInteger, id))objc_msgSend)(current, NSSelectorFromString(@"charonHostDifferenceFromOrderedSet:withOptions:usingEquivalenceTest:"), other, options, test);
    return ((id (*)(id, SEL, id, NSUInteger))objc_msgSend)(current, NSSelectorFromString(@"charonHostDifferenceFromOrderedSet:withOptions:"), other, options);
}

static id applyArray(BOOL port, NSArray *array, id difference)
{
    if (!port)
        return [array arrayByApplyingDifference:difference];
    return ((id (*)(id, SEL, id))objc_msgSend)(array, NSSelectorFromString(@"charonHostArrayByApplyingDifference:"), difference);
}

static id applySet(BOOL port, NSOrderedSet *set, id difference)
{
    if (!port)
        return [set orderedSetByApplyingDifference:difference];
    return ((id (*)(id, SEL, id))objc_msgSend)(set, NSSelectorFromString(@"charonHostOrderedSetByApplyingDifference:"), difference);
}

static void applyMutable(BOOL port, id collection, id difference)
{
    if (!port)
        [collection applyDifference:difference];
    else
        ((void (*)(id, SEL, id))objc_msgSend)(collection, NSSelectorFromString(@"charonHostApplyDifference:"), difference);
}

static NSArray *randomArray(NSUInteger maxLength, NSUInteger alphabet, BOOL strings, BOOL unique)
{
    NSUInteger length = next() % (maxLength + 1);
    NSMutableArray *array = [NSMutableArray array];
    for (NSUInteger index = 0; index < length; index++) {
        NSUInteger value = next() % alphabet;
        id object = strings ? [NSString stringWithFormat:@"%c", (char)('a' + value)] : @(value);
        if (unique && [array containsObject:object])
            continue;
        [array addObject:object];
    }
    return array;
}

static id buildDifference(BOOL port, NSDictionary *spec, NSString **output)
{
    NSMutableArray *changes = [NSMutableArray array];
    for (NSArray *entry in spec[@"changes"])
        [changes addObject:makeChange(port, entry[0] == [NSNull null] ? nil : entry[0], [entry[1] integerValue], [entry[2] unsignedIntegerValue], [entry[3] unsignedIntegerValue])];
    Class cls = port ? portDifference : [NSOrderedCollectionDifference class];
    NSString *(^build)(void) = ^NSString *{
        id difference;
        if ([spec[@"form"] integerValue] == 0)
            difference = [[cls alloc] initWithChanges:changes];
        else {
            NSMutableIndexSet *inserts = [NSMutableIndexSet indexSet], *removes = [NSMutableIndexSet indexSet];
            for (NSNumber *index in spec[@"insertIndexes"])
                [inserts addIndex:index.unsignedIntegerValue];
            for (NSNumber *index in spec[@"removeIndexes"])
                [removes addIndex:index.unsignedIntegerValue];
            difference = [[cls alloc] initWithInsertIndexes:inserts insertedObjects:spec[@"insertObjects"] removeIndexes:removes removedObjects:spec[@"removeObjects"] additionalChanges:changes];
        }
        objc_setAssociatedObject(cls, "difference", difference, OBJC_ASSOCIATION_RETAIN);
        return nil;
    };
    objc_setAssociatedObject(cls, "difference", nil, OBJC_ASSOCIATION_RETAIN);
    NSString *failure = safely(build, YES);
    *output = failure;
    return objc_getAssociatedObject(cls, "difference");
}

static NSDictionary *randomSpec(void)
{
    NSMutableArray *changes = [NSMutableArray array];
    BOOL strings = next() % 2;
    NSUInteger count = next() % 6;
    BOOL objects = next() % 4 != 0;
    NSMutableArray *usedInsert = [NSMutableArray array], *usedRemove = [NSMutableArray array];
    for (NSUInteger index = 0; index < count; index++) {
        NSInteger type = next() % 2;
        NSUInteger at = next() % 9, associated = next() % 3 == 0 ? next() % 9 : NSNotFound;
        if (next() % 5 && [(type ? usedRemove : usedInsert) containsObject:@(at)])
            at = (at + 1 + next() % 8) % 9;
        [(type ? usedRemove : usedInsert) addObject:@(at)];
        id object = objects ? (strings ? [NSString stringWithFormat:@"%c", (char)('a' + next() % 4)] : @(next() % 4)) : (next() % 5 ? nil : @(next() % 4));
        [changes addObject:@[object ?: [NSNull null], @(type), @(at), @(associated)]];
    }
    if (next() % 3 == 0 && changes.count) {
        NSMutableArray *rewritten = [NSMutableArray array];
        for (NSArray *change in changes) {
            NSInteger type = [change[1] integerValue];
            NSUInteger at = [change[2] unsignedIntegerValue];
            [rewritten addObject:change];
            NSUInteger partner = at;
            if (next() % 2 && [change[3] unsignedIntegerValue] == NSNotFound)
                [rewritten addObject:@[change[0], @(1 - type), @(partner), @(at)]];
        }
        changes = rewritten;
    }
    NSMutableDictionary *spec = [NSMutableDictionary dictionaryWithDictionary:@{@"changes": changes, @"form": @(next() % 3 == 0 ? 0 : 1)}];
    NSMutableArray *insertIndexes = [NSMutableArray array], *removeIndexes = [NSMutableArray array];
    for (int index = 0; index < 2; index++) {
        if (next() % 2)
            [insertIndexes addObject:@(next() % 9)];
        if (next() % 2)
            [removeIndexes addObject:@(next() % 9)];
    }
    NSMutableIndexSet *insertSet = [NSMutableIndexSet indexSet], *removeSet = [NSMutableIndexSet indexSet];
    for (NSNumber *index in insertIndexes)
        [insertSet addIndex:index.unsignedIntegerValue];
    for (NSNumber *index in removeIndexes)
        [removeSet addIndex:index.unsignedIntegerValue];
    spec[@"insertIndexes"] = insertIndexes;
    spec[@"removeIndexes"] = removeIndexes;
    if (next() % 2 == 0) {
        NSMutableArray *values = [NSMutableArray array];
        for (NSUInteger index = 0; index < insertSet.count + (next() % 8 == 0 ? 1 : 0); index++)
            [values addObject:strings ? @"i" : @(index)];
        spec[@"insertObjects"] = values;
    }
    if (next() % 2 == 0) {
        NSMutableArray *values = [NSMutableArray array];
        for (NSUInteger index = 0; index < removeSet.count + (next() % 8 == 0 ? 1 : 0); index++)
            [values addObject:strings ? @"r" : @(index)];
        spec[@"removeObjects"] = values;
    }
    return spec;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        portChange = NSClassFromString(@"CharonHostNSOrderedCollectionChange");
        portDifference = NSClassFromString(@"CharonHostNSOrderedCollectionDifference");
        CHECK(portChange != Nil && portDifference != Nil, "the port defines both classes");
        CHECK([portChange superclass] == [NSObject class] && [portDifference superclass] == [NSObject class], "both classes are direct subclasses of NSObject");
        CHECK([portDifference conformsToProtocol:@protocol(NSFastEnumeration)] == [NSOrderedCollectionDifference conformsToProtocol:@protocol(NSFastEnumeration)], "the difference is fast enumerable");
        CHECK([portDifference conformsToProtocol:@protocol(NSCopying)] == [NSOrderedCollectionDifference conformsToProtocol:@protocol(NSCopying)] && [portDifference conformsToProtocol:@protocol(NSSecureCoding)] == [NSOrderedCollectionDifference conformsToProtocol:@protocol(NSSecureCoding)], "neither copies nor archives");
        CHECK([portChange conformsToProtocol:@protocol(NSCopying)] == [NSOrderedCollectionChange conformsToProtocol:@protocol(NSCopying)] && [portChange conformsToProtocol:@protocol(NSSecureCoding)] == [NSOrderedCollectionChange conformsToProtocol:@protocol(NSSecureCoding)], "a change neither copies nor archives");

        NSUInteger rounds = argc > 1 ? (NSUInteger)atoi(argv[1]) : 20000;
        NSMutableArray *samples = [NSMutableArray array];
        __block NSUInteger total = 0, wrong = 0;
        void (^compare)(NSString *, NSString *, NSString *) = ^(NSString *kind, NSString *port, NSString *system) {
            total++;
            if (![port isEqualToString:system]) {
                wrong++;
                if (samples.count < 25)
                    [samples addObject:[NSString stringWithFormat:@"%@\n     port   %@\n     system %@", kind, port, system]];
            }
        };

        for (NSUInteger round = 0; round < rounds; round++) {
            BOOL strings = next() % 2;
            NSUInteger length = next() % 3 == 0 ? 30 : 10;
            NSUInteger alphabet = 2 + next() % (length > 10 ? 20 : 5);
            NSArray *other = randomArray(length, alphabet, strings, NO), *current = randomArray(length, alphabet, strings, NO);
            NSUInteger options = next() % 8;
            id theirs = diffArrays(NO, current, other, options, nil), ours = diffArrays(YES, current, other, options, nil);
            NSString *label = [NSString stringWithFormat:@"%@ from %@ options %lu", [current componentsJoinedByString:@""], [other componentsJoinedByString:@""], (unsigned long)options];
            compare(label, shape(ours), shape(theirs));
            compare([label stringByAppendingString:@" description"], normalized([ours description]), normalized([theirs description]));
            compare([label stringByAppendingString:@" debugDescription"], normalized([ours debugDescription]), normalized([theirs debugDescription]));
            compare([label stringByAppendingString:@" inverse"], shape([ours inverseDifference]), shape([theirs inverseDifference]));
            compare([label stringByAppendingString:@" inverse debug"], normalized([[ours inverseDifference] debugDescription]), normalized([[theirs inverseDifference] debugDescription]));
            compare([label stringByAppendingString:@" hash"], [NSString stringWithFormat:@"%d", [ours hash] == [diffArrays(YES, current, other, options, nil) hash]], @"1");

            NSUInteger testOptions = options & 3;
            NSMutableArray *ourLog = [NSMutableArray array], *theirLog = [NSMutableArray array];
            NSUInteger modulus = 2 + next() % 3;
            BOOL (^ourTest)(id, id) = ^BOOL(id one, id two) {
                [ourLog addObject:@[one, two]];
                return [one integerValue] % (NSInteger)modulus == [two integerValue] % (NSInteger)modulus && ([one isKindOfClass:[NSNumber class]] == [two isKindOfClass:[NSNumber class]]);
            };
            BOOL (^theirTest)(id, id) = ^BOOL(id one, id two) {
                [theirLog addObject:@[one, two]];
                return [one integerValue] % (NSInteger)modulus == [two integerValue] % (NSInteger)modulus && ([one isKindOfClass:[NSNumber class]] == [two isKindOfClass:[NSNumber class]]);
            };
            id theirsTested = diffArrays(NO, current, other, testOptions, theirTest), oursTested = diffArrays(YES, current, other, testOptions, ourTest);
            compare([label stringByAppendingFormat:@" test mod %lu", (unsigned long)modulus], shape(oursTested), shape(theirsTested));
            compare([label stringByAppendingString:@" test calls"], [ourLog description], [theirLog description]);

            NSOrderedSet *setOther = [NSOrderedSet orderedSetWithArray:other], *setCurrent = [NSOrderedSet orderedSetWithArray:current];
            compare([label stringByAppendingString:@" ordered set"], shape(diffSets(YES, setCurrent, setOther, options, nil)), shape(diffSets(NO, setCurrent, setOther, options, nil)));
            compare([label stringByAppendingString:@" ordered set test"], shape(diffSets(YES, setCurrent, setOther, testOptions, ourTest)), shape(diffSets(NO, setCurrent, setOther, testOptions, theirTest)));

            NSArray *target = randomArray(length, alphabet, strings, NO);
            compare([label stringByAppendingString:@" apply"], safely(^{ return applyArray(YES, other, ours); }, NO), safely(^{ return applyArray(NO, other, theirs); }, NO));
            compare([label stringByAppendingFormat:@" apply to %@", [target componentsJoinedByString:@""]], safely(^{ return applyArray(YES, target, ours); }, NO), safely(^{ return applyArray(NO, target, theirs); }, NO));
            compare([label stringByAppendingFormat:@" set apply"], safely(^{ return applySet(YES, setOther, ours); }, NO), safely(^{ return applySet(NO, setOther, theirs); }, NO));
            compare([label stringByAppendingFormat:@" set apply to %@", [target componentsJoinedByString:@""]], safely(^{ return applySet(YES, [NSOrderedSet orderedSetWithArray:target], ours); }, NO), safely(^{ return applySet(NO, [NSOrderedSet orderedSetWithArray:target], theirs); }, NO));
            NSMutableArray *ourMutable = [target mutableCopy], *theirMutable = [target mutableCopy];
            NSString *ourResult = safely(^{ applyMutable(YES, ourMutable, ours); return ourMutable; }, NO), *theirResult = safely(^{ applyMutable(NO, theirMutable, theirs); return theirMutable; }, NO);
            compare([label stringByAppendingFormat:@" mutable apply to %@", [target componentsJoinedByString:@""]], ourResult, theirResult);
            NSMutableOrderedSet *ourSet = [NSMutableOrderedSet orderedSetWithArray:target], *theirSet = [NSMutableOrderedSet orderedSetWithArray:target];
            ourResult = safely(^{ applyMutable(YES, ourSet, ours); return ourSet; }, NO);
            theirResult = safely(^{ applyMutable(NO, theirSet, theirs); return theirSet; }, NO);
            compare([label stringByAppendingFormat:@" mutable set apply to %@", [target componentsJoinedByString:@""]], ourResult, theirResult);
        }
        printf("algorithm: compared %lu, differing %lu\n", (unsigned long)total, (unsigned long)wrong);
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        charon_check(wrong == 0, "differences, their descriptions, inverses, moves, equivalence calls and application agree with the system's on random arrays", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)total]);

        [samples removeAllObjects];
        total = wrong = 0;
        for (NSUInteger round = 0; round < rounds; round++) {
            NSDictionary *spec = randomSpec();
            NSString *ourFailure, *theirFailure;
            id ours = buildDifference(YES, spec, &ourFailure), theirs = buildDifference(NO, spec, &theirFailure);
            NSString *label = [spec description];
            compare(label, normalized(ourFailure ?: @"(built)"), normalized(theirFailure ?: @"(built)"));
            if (ours && theirs) {
                compare([label stringByAppendingString:@" shape"], shape(ours), shape(theirs));
                compare([label stringByAppendingString:@" description"], normalized([ours description]), normalized([theirs description]));
                compare([label stringByAppendingString:@" debugDescription"], normalized([ours debugDescription]), normalized([theirs debugDescription]));
                compare([label stringByAppendingString:@" inverse"], shape([ours inverseDifference]), shape([theirs inverseDifference]));
                NSString *ourTransform = safely(^{ return shape([ours differenceByTransformingChangesWithBlock:^id(id change) {
                    return makeChange(YES, [change object], [change changeType], [change index] + 1, [change associatedIndex] == NSNotFound ? NSNotFound : [change associatedIndex] + 1);
                }]); }, YES);
                NSString *theirTransform = safely(^{ return shape([theirs differenceByTransformingChangesWithBlock:^id(id change) {
                    return makeChange(NO, [change object], [change changeType], [change index] + 1, [change associatedIndex] == NSNotFound ? NSNotFound : [change associatedIndex] + 1);
                }]); }, YES);
                compare([label stringByAppendingString:@" transformed"], ourTransform, theirTransform);
                compare([label stringByAppendingString:@" equality with itself"], [NSString stringWithFormat:@"%d", [ours isEqual:ours]], [NSString stringWithFormat:@"%d", [theirs isEqual:theirs]]);
                NSString *ourEquals, *theirEquals, *ignored;
                id ours2 = buildDifference(YES, spec, &ignored), theirs2 = buildDifference(NO, spec, &ignored);
                ourEquals = [NSString stringWithFormat:@"%d %d", [ours isEqual:ours2], [ours hash] == [ours2 hash]];
                theirEquals = [NSString stringWithFormat:@"%d %d", [theirs isEqual:theirs2], [theirs hash] == [theirs2 hash]];
                compare([label stringByAppendingString:@" equality with a twin"], ourEquals, theirEquals);
                compare([label stringByAppendingString:@" equality with the inverse"], [NSString stringWithFormat:@"%d", [ours isEqual:[ours inverseDifference]]], [NSString stringWithFormat:@"%d", [theirs isEqual:[theirs inverseDifference]]]);
            }
        }
        printf("construction: compared %lu, differing %lu\n", (unsigned long)total, (unsigned long)wrong);
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        charon_check(wrong == 0, "differences built from changes and index sets accept, refuse and describe as the system's do", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)total]);

        [samples removeAllObjects];
        total = wrong = 0;
        NSArray *values = @[@"a", @"", @42, [NSNull null], [NSObject new], @[@1, @2], @"multi\nline"];
        for (id value in values) {
            for (NSInteger type = 0; type < 2; type++) {
                for (NSUInteger index = 0; index < 3; index++) {
                    id one = makeChange(YES, value, type, index, index == 2 ? NSNotFound : index), two = makeChange(NO, value, type, index, index == 2 ? NSNotFound : index);
                    compare(@"debugDescription of a change", normalized([one debugDescription]), normalized([two debugDescription]));
                    compare(@"description of a change", normalized([one description]), normalized([two description]));
                    compare(@"accessors of a change", [NSString stringWithFormat:@"%@ %ld %lu %lu", [one object], (long)[one changeType], (unsigned long)[one index], (unsigned long)[one associatedIndex]], [NSString stringWithFormat:@"%@ %ld %lu %lu", [two object], (long)[two changeType], (unsigned long)[two index], (unsigned long)[two associatedIndex]]);
                    compare(@"equality of changes", [NSString stringWithFormat:@"%d %d %d", [one isEqual:makeChange(YES, value, type, index, index == 2 ? NSNotFound : index)], [one isEqual:makeChange(YES, value, 1 - type, index, NSNotFound)], [one isEqual:@"x"]], [NSString stringWithFormat:@"%d %d %d", [two isEqual:makeChange(NO, value, type, index, index == 2 ? NSNotFound : index)], [two isEqual:makeChange(NO, value, 1 - type, index, NSNotFound)], [two isEqual:@"x"]]);
                }
            }
        }
        NSArray *bodies = @[
            ^id(BOOL port) { return [[(port ? portChange : [NSOrderedCollectionChange class]) alloc] initWithObject:@"a" type:(NSCollectionChangeType)7 index:1]; },
            ^id(BOOL port) { return [[(port ? portChange : [NSOrderedCollectionChange class]) alloc] initWithObject:@"a" type:(NSCollectionChangeType)-1 index:1 associatedIndex:4]; },
            ^id(BOOL port) { return [(port ? portChange : [NSOrderedCollectionChange class]) changeWithObject:@"a" type:(NSCollectionChangeType)5 index:1]; },
            ^id(BOOL port) { return [[(port ? portChange : [NSOrderedCollectionChange class]) alloc] initWithObject:@"a" type:NSCollectionChangeInsert index:1]; },
            ^id(BOOL port) { return [[(port ? portChange : [NSOrderedCollectionChange class]) alloc] initWithObject:nil type:NSCollectionChangeRemove index:9]; },
            ^id(BOOL port) { return [(id)[(port ? portChange : [NSOrderedCollectionChange class]) alloc] init]; },
            ^id(BOOL port) { return [(id)makeChange(port, @"a", 0, 1, NSNotFound) copy]; },
            ^id(BOOL port) { return [(id)[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] init]; },
            ^id(BOOL port) { return [[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] initWithChanges:nil]; },
            ^id(BOOL port) { return [[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] initWithChanges:@[@1]]; },
            ^id(BOOL port) { return [[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] initWithInsertIndexes:nil insertedObjects:nil removeIndexes:nil removedObjects:nil]; },
            ^id(BOOL port) { return [[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] initWithInsertIndexes:[NSIndexSet indexSetWithIndex:1] insertedObjects:@[@"a", @"b"] removeIndexes:[NSIndexSet indexSet] removedObjects:nil]; },
            ^id(BOOL port) { return [[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] initWithInsertIndexes:[NSIndexSet indexSetWithIndex:1] insertedObjects:@[@"a"] removeIndexes:[NSIndexSet indexSetWithIndex:2] removedObjects:@[@"a", @"b"]]; },
            ^id(BOOL port) { return [(id)[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] init]; },
            ^id(BOOL port) { return [[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] initWithChanges:@[makeChange(port, @"a", 0, 1, 2), makeChange(port, @"b", 1, 2, 1)]]; },
            ^id(BOOL port) { return [[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] initWithChanges:@[makeChange(port, @"a", 0, 1, 2), makeChange(port, @"b", 1, 2, 2)]]; },
            ^id(BOOL port) { return [(id)makeChange(port, @"a", 0, 1, NSNotFound) isEqual:nil] ? @1 : @0; },
            ^id(BOOL port) { return [[[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] initWithChanges:@[]] hasChanges] ? @1 : @0; },
            ^id(BOOL port) { id one = [[(port ? portDifference : [NSOrderedCollectionDifference class]) alloc] init]; return [one hash] ? @1 : @0; },
        ];
        for (NSUInteger index = 0; index < bodies.count; index++) {
            id (^body)(BOOL) = bodies[index];
            NSString *ours = safely(^{ return body(YES); }, YES), *theirs = safely(^{ return body(NO); }, YES);
            NSString *label = [NSString stringWithFormat:@"direct case %lu", (unsigned long)index];
            compare(label, normalized(ours), normalized(theirs));
        }
        NSArray *nilCases = @[
            ^id(BOOL port) { return diffArrays(port, @[@1], nil, 0, nil); },
            ^id(BOOL port) { return diffArrays(port, @[@1], @[@1], 4, ^BOOL(id one, id two) { return YES; }); },
            ^id(BOOL port) { return diffSets(port, [NSOrderedSet orderedSetWithObject:@1], [NSOrderedSet orderedSetWithObject:@1], 5, ^BOOL(id one, id two) { return YES; }); },
            ^id(BOOL port) { return applyArray(port, @[@1, @2], nil); },
            ^id(BOOL port) { return diffSets(port, [NSOrderedSet orderedSetWithObject:@1], nil, 0, nil); },
            ^id(BOOL port) { return applySet(port, [NSOrderedSet orderedSetWithObject:@1], nil); },
            ^id(BOOL port) { NSMutableArray *array = [@[@1] mutableCopy]; applyMutable(port, array, nil); return array; },
        ];
        for (NSUInteger index = 0; index < nilCases.count; index++) {
            id (^body)(BOOL) = nilCases[index];
            compare([NSString stringWithFormat:@"nil case %lu", (unsigned long)index], normalized(safely(^{ return body(YES); }, YES)), normalized(safely(^{ return body(NO); }, YES)));
        }
        printf("direct: compared %lu, differing %lu\n", (unsigned long)total, (unsigned long)wrong);
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        charon_check(wrong == 0, "changes and the exceptions of both classes agree with the system's", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)total]);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
