#import <Foundation/Foundation.h>

#define OC_CASE_COUNT 1600

static uint64_t oc_mix(uint64_t value)
{
    value += 0x9E3779B97F4A7C15ull;
    value = (value ^ (value >> 30)) * 0xBF58476D1CE4E5B9ull;
    value = (value ^ (value >> 27)) * 0x94D049BB133111EBull;
    return value ^ (value >> 31);
}

static uint32_t oc_draw(uint64_t *state)
{
    *state = oc_mix(*state);
    return (uint32_t)(*state >> 20);
}

static uint64_t oc_hash(NSString *text)
{
    uint64_t hash = 0xcbf29ce484222325ull;
    for (const unsigned char *byte = (const unsigned char *)text.UTF8String; *byte; byte++)
        hash = (hash ^ *byte) * 0x100000001b3ull;
    return hash;
}

static NSString *oc_normalized(NSString *text)
{
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"<[A-Za-z_0-9]+: 0x[0-9a-f]+>" options:0 error:NULL];
    return [expression stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"<object>"];
}

static NSUInteger oc_value(id object)
{
    return [object isKindOfClass:[NSString class]] ? (NSUInteger)[(NSString *)object characterAtIndex:0] : [object unsignedIntegerValue];
}

static NSString *oc_number(NSUInteger value)
{
    return value == NSNotFound ? @"-" : [NSString stringWithFormat:@"%lu", (unsigned long)value];
}

static NSString *oc_shape(NSOrderedCollectionDifference *difference)
{
    NSMutableString *text = [NSMutableString string];
    for (NSOrderedCollectionChange *change in difference)
        [text appendFormat:@"%c%@:%@:%@ ", change.changeType == NSCollectionChangeInsert ? '+' : '-', oc_number(change.index), change.object ?: @"-", oc_number(change.associatedIndex)];
    [text appendString:@"| ins"];
    for (NSOrderedCollectionChange *change in difference.insertions)
        [text appendFormat:@" %@:%@:%@", oc_number(change.index), change.object ?: @"-", oc_number(change.associatedIndex)];
    [text appendString:@" | rem"];
    for (NSOrderedCollectionChange *change in difference.removals)
        [text appendFormat:@" %@:%@:%@", oc_number(change.index), change.object ?: @"-", oc_number(change.associatedIndex)];
    return text;
}

static NSString *oc_safely(BOOL exact, id (^body)(void))
{
    @try {
        id result = body();
        return result ? [NSString stringWithFormat:@"%@", result] : @"(nil)";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@ | %@ | %@", exception.name, exact ? exception.reason : @"", exact ? exception.userInfo[@"index"] ?: @"" : @""];
    }
}

static NSArray *oc_array(uint64_t *state, NSUInteger maximum, NSUInteger alphabet, BOOL strings)
{
    NSUInteger length = oc_draw(state) % (maximum + 1);
    NSMutableArray *array = [NSMutableArray array];
    for (NSUInteger index = 0; index < length; index++) {
        NSUInteger value = oc_draw(state) % alphabet;
        [array addObject:strings ? [NSString stringWithFormat:@"%c", (char)('a' + value)] : (id)@(value)];
    }
    return array;
}

static NSString *oc_answer(size_t index)
{
    uint64_t state = index * 7919 + 1;
    BOOL strings = oc_draw(&state) % 2;
    NSUInteger maximum = oc_draw(&state) % 4 == 0 ? 24 : 9, alphabet = 2 + oc_draw(&state) % (maximum > 9 ? 12 : 5);
    NSArray *other = oc_array(&state, maximum, alphabet, strings), *current = oc_array(&state, maximum, alphabet, strings), *target = oc_array(&state, maximum, alphabet, strings);
    NSUInteger options = oc_draw(&state) % 8;
    NSMutableString *out = [NSMutableString string];
    switch (index % 4) {
    case 0: {
        NSOrderedCollectionDifference *difference = [current differenceFromArray:other withOptions:options];
        [out appendFormat:@"%@\n%@\n%@\n", oc_shape(difference), oc_normalized(difference.description), oc_normalized(difference.debugDescription)];
        [out appendFormat:@"%@\n%@\n", oc_shape(difference.inverseDifference), oc_normalized(difference.inverseDifference.debugDescription)];
        [out appendFormat:@"%@\n%@\n", oc_safely(NO, ^{ return [other arrayByApplyingDifference:difference]; }), oc_safely(NO, ^{ return [target arrayByApplyingDifference:difference]; })];
        NSMutableArray *mutated = [target mutableCopy];
        [out appendString:oc_safely(NO, ^{ [mutated applyDifference:difference]; return mutated; })];
        break;
    }
    case 1: {
        NSOrderedSet *setOther = [NSOrderedSet orderedSetWithArray:other], *setCurrent = [NSOrderedSet orderedSetWithArray:current], *setTarget = [NSOrderedSet orderedSetWithArray:target];
        NSOrderedCollectionDifference *difference = [setCurrent differenceFromOrderedSet:setOther withOptions:options];
        [out appendFormat:@"%@\n%@\n", oc_shape(difference), oc_normalized(difference.debugDescription)];
        [out appendFormat:@"%@\n%@\n", oc_safely(NO, ^{ return [setOther orderedSetByApplyingDifference:difference]; }), oc_safely(NO, ^{ return [setTarget orderedSetByApplyingDifference:difference]; })];
        NSMutableOrderedSet *mutated = [setTarget mutableCopy];
        [out appendString:oc_safely(NO, ^{ [mutated applyDifference:difference]; return mutated; })];
        break;
    }
    case 2: {
        NSMutableArray *log = [NSMutableArray array];
        NSInteger modulus = 2 + (NSInteger)(oc_draw(&state) % 3);
        NSOrderedCollectionDifference *difference = [current differenceFromArray:other withOptions:options & 3 usingEquivalenceTest:^BOOL(id one, id two) {
            [log addObject:[NSString stringWithFormat:@"%@%@", one, two]];
            return oc_value(one) % (NSUInteger)modulus == oc_value(two) % (NSUInteger)modulus;
        }];
        [out appendFormat:@"%@\n%@\n", oc_shape(difference), [log componentsJoinedByString:@","]];
        break;
    }
    default: {
        NSMutableArray *changes = [NSMutableArray array];
        NSUInteger count = oc_draw(&state) % 6;
        for (NSUInteger position = 0; position < count; position++) {
            NSCollectionChangeType type = (NSCollectionChangeType)(oc_draw(&state) % 2);
            NSUInteger at = oc_draw(&state) % 9, associated = oc_draw(&state) % 3 == 0 ? oc_draw(&state) % 9 : NSNotFound;
            BOOL object = oc_draw(&state) % 5 != 0;
            [changes addObject:[NSOrderedCollectionChange changeWithObject:object ? (strings ? @"o" : @1) : nil type:type index:at associatedIndex:associated]];
        }
        NSMutableIndexSet *inserts = [NSMutableIndexSet indexSet], *removes = [NSMutableIndexSet indexSet];
        for (int position = 0; position < 2; position++) {
            if (oc_draw(&state) % 2)
                [inserts addIndex:oc_draw(&state) % 9];
            if (oc_draw(&state) % 2)
                [removes addIndex:oc_draw(&state) % 9];
        }
        NSMutableArray *insertedObjects = oc_draw(&state) % 2 ? [NSMutableArray array] : nil, *removedObjects = oc_draw(&state) % 2 ? [NSMutableArray array] : nil;
        for (NSUInteger position = 0; position < inserts.count + (oc_draw(&state) % 8 == 0 ? 1 : 0); position++)
            [insertedObjects addObject:@"i"];
        for (NSUInteger position = 0; position < removes.count + (oc_draw(&state) % 8 == 0 ? 1 : 0); position++)
            [removedObjects addObject:@"r"];
        BOOL designated = oc_draw(&state) % 3 != 0;
        NSString *built = oc_safely(YES, ^id{
            NSOrderedCollectionDifference *difference = designated ? [[NSOrderedCollectionDifference alloc] initWithInsertIndexes:inserts insertedObjects:insertedObjects removeIndexes:removes removedObjects:removedObjects additionalChanges:changes]
                                                                   : [[NSOrderedCollectionDifference alloc] initWithChanges:changes];
            return [NSString stringWithFormat:@"%@\n%@\n%@", oc_shape(difference), oc_normalized(difference.description), oc_normalized(difference.debugDescription)];
        });
        [out appendString:built];
        break;
    }
    }
    return out;
}
