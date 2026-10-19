#import <UIKit/UIKit.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wnonnull"

typedef NSDiffableDataSourceSectionSnapshot Section;

static uint64_t state = 0x6A09E667F3BCC908ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *normalized(NSString *text)
{
    NSMutableString *result = [text mutableCopy];
    [result replaceOccurrencesOfString:@"CharonHost" withString:@"" options:0 range:NSMakeRange(0, result.length)];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
    return [expression stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"0x"];
}

static NSString *outcome(id (^body)(void))
{
    @try {
        id result = body();
        return result ? [NSString stringWithFormat:@"ok %@", result] : @"ok";
    } @catch (NSException *exception) {
        return normalized([NSString stringWithFormat:@"raises %@ | %@ | %@", exception.name, exception.reason, exception.userInfo]);
    }
}

static NSString *dump(Section *snapshot, BOOL structure)
{
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"%@ | %@ | %@ | %@\n", snapshot.items, snapshot.rootItems, snapshot.visibleItems, snapshot.expandedItems];
    for (id item in @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @1, @"zz", @"p0", @"q1", @"q2"]) {
        [text appendFormat:@"%@: %d %ld ", item, [snapshot containsItem:item], (long)[snapshot indexOfItem:item]];
        [text appendString:outcome(^{ return [NSString stringWithFormat:@"%ld %d %d %@", (long)[snapshot levelOfItem:item], [snapshot isExpanded:item], [snapshot isVisible:item], [snapshot parentOfChildItem:item] ?: @"-"]; })];
        [text appendString:@"\n"];
    }
    [text appendString:normalized([snapshot visualDescription])];
    if (structure)
        [text appendString:normalized([snapshot description])];
    return text;
}

static NSArray *universe(void)
{
    static NSArray *items;
    if (!items)
        items = @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @1, @"zz"];
    return items;
}

static id item(void)
{
    return universe()[next() % universe().count];
}

static id maybe(id (^make)(void))
{
    return next() % 12 == 0 ? nil : make();
}

static NSArray *itemList(void)
{
    if (next() % 14 == 0)
        return nil;
    NSMutableArray *list = [NSMutableArray array];
    NSUInteger count = next() % 4;
    for (NSUInteger index = 0; index < count; index++)
        [list addObject:item()];
    return list;
}

static Section *freshSnapshot(Class cls, BOOL nesting)
{
    NSUInteger counter = next() % 100000 * 10;
    Section *snapshot = [[cls alloc] init];
    NSUInteger count = next() % 4;
    NSMutableArray *roots = [NSMutableArray array];
    for (NSUInteger index = 0; index < count; index++)
        [roots addObject:[NSString stringWithFormat:@"q%lu", (unsigned long)++counter]];
    [snapshot appendItems:roots];
    if (nesting && roots.count == 1 && next() % 2) {
        NSString *child = [NSString stringWithFormat:@"q%lu", (unsigned long)++counter];
        [snapshot appendItems:@[child] intoParentItem:roots.lastObject];
        if (next() % 2)
            [snapshot expandItems:@[roots.lastObject]];
    }
    return snapshot;
}

static NSString *firstDifference(NSString *one, NSString *two)
{
    NSArray *a = [one componentsSeparatedByString:@"\n"], *b = [two componentsSeparatedByString:@"\n"];
    for (NSUInteger index = 0; index < MIN(a.count, b.count); index++)
        if (![a[index] isEqualToString:b[index]])
            return [NSString stringWithFormat:@"line %lu: %@ / %@", (unsigned long)index, a[index], b[index]];
    return a.count == b.count ? @"(same lines)" : @"(different length)";
}

static NSString *lastDescription;

static id randomOperation(Section *target, Class cls)
{
    NSUInteger which = next() % 16;
    NSArray *items = itemList();
    id one = maybe(^{ return item(); });
    switch (which) {
    case 0: lastDescription = [NSString stringWithFormat:@"append %@", items]; [target appendItems:items]; return nil;
    case 1: lastDescription = [NSString stringWithFormat:@"append %@ into %@", items, one]; [target appendItems:items intoParentItem:one]; return nil;
    case 2: lastDescription = [NSString stringWithFormat:@"insert %@ before %@", items, one]; [target insertItems:items beforeItem:one]; return nil;
    case 3: lastDescription = [NSString stringWithFormat:@"insert %@ after %@", items, one]; [target insertItems:items afterItem:one]; return nil;
    case 4: lastDescription = [NSString stringWithFormat:@"delete %@", items]; [target deleteItems:items]; return nil;
    case 5: if (next() % 6) { lastDescription = [NSString stringWithFormat:@"expand %@", items]; [target expandItems:items]; return nil; } lastDescription = @"deleteAll"; [target deleteAllItems]; return nil;
    case 6: lastDescription = [NSString stringWithFormat:@"collapse %@", items]; [target collapseItems:items]; return nil;
    case 7: { Section *snapshot = next() % 10 ? freshSnapshot(cls, YES) : nil; lastDescription = [NSString stringWithFormat:@"replace children of %@ with %@", one, snapshot.items]; [target replaceChildrenOfParentItem:one withSnapshot:snapshot]; return nil; }
    case 8: { Section *snapshot = next() % 10 ? freshSnapshot(cls, NO) : nil; lastDescription = [NSString stringWithFormat:@"insert snapshot %@ before %@", snapshot.items, one]; [target insertSnapshot:snapshot beforeItem:one]; return nil; }
    case 9: { Section *snapshot = next() % 10 ? freshSnapshot(cls, NO) : nil; lastDescription = [NSString stringWithFormat:@"insert snapshot %@ after %@", snapshot.items, one]; return [target insertSnapshot:snapshot afterItem:one] ?: @"(nil)"; }
    case 10: { lastDescription = [NSString stringWithFormat:@"snapshot of %@", one]; Section *part = [target snapshotOfParentItem:one includingParentItem:next() % 2]; return dump(part, NO); }
    case 11: lastDescription = [NSString stringWithFormat:@"replace children of %@ with its own", one]; [target replaceChildrenOfParentItem:one withSnapshot:[target snapshotOfParentItem:one]]; return nil;
    case 12: lastDescription = [NSString stringWithFormat:@"levelOf %@", one]; return @([target levelOfItem:one]);
    case 13: lastDescription = [NSString stringWithFormat:@"expanded %@", one]; return @([target isExpanded:one]);
    case 14: lastDescription = [NSString stringWithFormat:@"visible %@", one]; return @([target isVisible:one]);
    default: lastDescription = [NSString stringWithFormat:@"parentOf %@", one]; return [target parentOfChildItem:one] ?: @"(nil)";
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class port = NSClassFromString(@"CharonHostNSDiffableDataSourceSectionSnapshot");
        CHECK(port != Nil, "the port defines the section snapshot");
        CHECK([port superclass] == [NSObject class] && [port conformsToProtocol:@protocol(NSCopying)] == [Section conformsToProtocol:@protocol(NSCopying)], "it is an NSObject that copies, as the system's is");

        NSUInteger rounds = argc > 1 ? (NSUInteger)atoi(argv[1]) : 5000;
        NSMutableArray *samples = [NSMutableArray array];
        NSUInteger total = 0, wrong = 0;
        NSMutableDictionary *kinds = [NSMutableDictionary dictionary];
        NSUInteger corrupted = 0;
        NSMutableArray *corruptions = [NSMutableArray array];
        for (NSUInteger round = 0; round < rounds; round++) {
            Section *ours = [[port alloc] init], *theirs = [[Section alloc] init];
            NSMutableArray *history = [NSMutableArray array];
            BOOL structured = next() % 2 == 0;
            if (structured) {
                NSArray *roots = @[@"a", @"b", @"c"];
                [ours appendItems:roots];
                [theirs appendItems:roots];
                for (Section *snapshot in @[ours, theirs]) {
                    [snapshot appendItems:@[@"d", @"e"] intoParentItem:@"a"];
                    [snapshot appendItems:@[@"f"] intoParentItem:@"d"];
                    [snapshot appendItems:@[@"g"] intoParentItem:@"c"];
                }
                if (![dump(ours, YES) isEqualToString:dump(theirs, YES)]) {
                    wrong++;
                    [samples addObject:[NSString stringWithFormat:@"structured start\n  %@\n  %@", dump(ours, YES), dump(theirs, YES)]];
                    break;
                }
            }
            NSUInteger steps = 3 + next() % 12;
            for (NSUInteger step = 0; step < steps; step++) {
                uint64_t saved = state;
                NSString *a = outcome(^{ return randomOperation(ours, port); });
                NSString *description = lastDescription;
                uint64_t after = state;
                state = saved;
                NSString *b = outcome(^{ return randomOperation(theirs, [Section class]); });
                (void)after;
                [history addObject:description ?: @"?"];
                total++;
                NSString *kind = [a hasPrefix:@"raises"] ? [[a componentsSeparatedByString:@" | "][1] substringToIndex:MIN(50, [[a componentsSeparatedByString:@" | "][1] length])] : @"ok";
                kinds[kind] = @([kinds[kind] integerValue] + 1);
                NSString *ourState = dump(ours, NO), *theirState = nil;
                @try {
                    theirState = dump(theirs, NO);
                } @catch (NSException *exception) {
                    corrupted++;
                    if (corruptions.count < 8)
                        [corruptions addObject:[NSString stringWithFormat:@"%@ -> %@", [history componentsJoinedByString:@"; "], exception.reason]];
                    break;
                }
                Section *copyOurs = [ours copy], *copyTheirs = [theirs copy];
                if (![a isEqualToString:b] || ![ourState isEqualToString:theirState] || ![dump(copyOurs, NO) isEqualToString:dump(copyTheirs, NO)] || ![copyOurs isEqual:ours]) {
                    wrong++;
                    if (samples.count < 12)
                        [samples addObject:[NSString stringWithFormat:@"%@\n     port   %@\n     system %@\n     port state   %@\n     system state %@", [history componentsJoinedByString:@"; "], [a stringByReplacingOccurrencesOfString:@"\n" withString:@" / "], [b stringByReplacingOccurrencesOfString:@"\n" withString:@" / "], firstDifference(ourState, theirState), samples.count < 2 ? [theirState stringByReplacingOccurrencesOfString:@"\n" withString:@" / "] : @""]];
                    break;
                }
                if (structured && step < 3 && ![normalized([ours description]) isEqualToString:normalized([theirs description])] && ![history containsObject:@"?"] && [a isEqualToString:@"ok"] == YES && NO) {
                    wrong++;
                    break;
                }
            }
        }
        printf("section snapshot: compared %lu steps, %lu sequences differing, %lu abandoned where the system's own tree was corrupt\n", (unsigned long)total, (unsigned long)wrong, (unsigned long)corrupted);
        for (NSString *corruption in corruptions)
            printf("  corrupt: %s\n", [[corruption stringByReplacingOccurrencesOfString:@"\n" withString:@" / "] UTF8String]);
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        for (NSString *kind in [kinds.allKeys sortedArrayUsingSelector:@selector(compare:)])
            printf("  %5ld %s\n", (long)[kinds[kind] integerValue], kind.UTF8String);
        charon_check(wrong == 0, "random sequences of section snapshot operations end in the system's tree and exception", [NSString stringWithFormat:@"%lu differ", (unsigned long)wrong]);

        NSMutableArray *built = [NSMutableArray array];
        for (NSUInteger round = 0; round < 400; round++) {
            Section *ours = [[port alloc] init], *theirs = [[Section alloc] init];
            NSUInteger sizes = 1 + next() % 4;
            NSMutableArray *level = [NSMutableArray array];
            NSUInteger counter = 0;
            NSMutableArray *roots = [NSMutableArray array];
            for (NSUInteger index = 0; index < sizes; index++)
                [roots addObject:@(counter++)];
            [ours appendItems:roots];
            [theirs appendItems:roots];
            [level addObjectsFromArray:roots];
            for (NSUInteger depth = 0; depth < 3; depth++) {
                NSMutableArray *nextLevel = [NSMutableArray array];
                for (id parent in level) {
                    if (next() % 3)
                        continue;
                    NSMutableArray *children = [NSMutableArray array];
                    for (NSUInteger index = 0, count = 1 + next() % 3; index < count; index++)
                        [children addObject:@(counter++)];
                    [ours appendItems:children intoParentItem:parent];
                    [theirs appendItems:children intoParentItem:parent];
                    [nextLevel addObjectsFromArray:children];
                }
                level = nextLevel;
            }
            for (id expanded in [ours items])
                if (next() % 3 == 0) {
                    [ours expandItems:@[expanded]];
                    [theirs expandItems:@[expanded]];
                }
            if (![normalized([ours description]) isEqualToString:normalized([theirs description])] || ![normalized([ours visualDescription]) isEqualToString:normalized([theirs visualDescription])])
                [built addObject:[NSString stringWithFormat:@"%@\n  port   %@\n  system %@", [ours visualDescription], normalized([ours description]), normalized([theirs description])]];
        }
        for (NSUInteger index = 0; index < MIN(built.count, 3); index++)
            printf("built: %s\n", [built[index] UTF8String]);
        charon_check(built.count == 0, "a tree built one appendItems per parent is described in runs as the system describes it", [NSString stringWithFormat:@"%lu differ", (unsigned long)built.count]);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
