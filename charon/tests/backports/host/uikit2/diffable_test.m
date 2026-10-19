#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wnonnull"

static uint64_t state = 0xD1B54A32D192ED03ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *normalized(NSString *text)
{
    NSMutableString *result = [text mutableCopy];
    [result replaceOccurrencesOfString:@"CharonHost" withString:@"" options:0 range:NSMakeRange(0, result.length)];
    for (NSString *pattern in @[@"0x[0-9a-f]+", @"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"]) {
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
        NSString *template = [pattern hasPrefix:@"0x"] ? @"0x" : @"GEN";
        [result setString:[expression stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:template]];
    }
    return result;
}

static NSString *outcome(void (^body)(void))
{
    @try {
        body();
        return @"ok";
    } @catch (NSException *exception) {
        return normalized([NSString stringWithFormat:@"raises %@ | %@ | %@", exception.name, exception.reason, exception.userInfo]);
    }
}

static NSString *dump(NSDiffableDataSourceSnapshot *snapshot)
{
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"%ld %ld %@ %@\n", (long)[snapshot numberOfSections], (long)[snapshot numberOfItems], [snapshot sectionIdentifiers], [snapshot itemIdentifiers]];
    for (id section in [snapshot sectionIdentifiers])
        [text appendFormat:@"%@: %ld %@ | %@\n", section, (long)[snapshot numberOfItemsInSection:section], [snapshot itemIdentifiersInSectionWithIdentifier:section], @([snapshot indexOfSectionIdentifier:section])];
    for (id item in [snapshot itemIdentifiers])
        [text appendFormat:@"%@ in %@ at %ld\n", item, [snapshot sectionIdentifierForSectionContainingItemIdentifier:item], (long)[snapshot indexOfItemIdentifier:item]];
    [text appendFormat:@"%ld %ld\n", (long)[snapshot indexOfItemIdentifier:@"zz"], (long)[snapshot indexOfSectionIdentifier:@"ZZ"]];
    [text appendString:normalized([snapshot description])];
    return text;
}

static id item(void)
{
    static NSArray *items;
    if (!items)
        items = @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @1, @2, @"zz"];
    return items[next() % items.count];
}

static id section(void)
{
    static NSArray *sections;
    if (!sections)
        sections = @[@"A", @"B", @"C", @"D", @"E", @"ZZ"];
    return sections[next() % sections.count];
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

static NSArray *sectionList(void)
{
    if (next() % 14 == 0)
        return nil;
    NSMutableArray *list = [NSMutableArray array];
    NSUInteger count = next() % 3;
    for (NSUInteger index = 0; index < count; index++)
        [list addObject:section()];
    return list;
}

static NSString *lastDescription;

static void randomOperation(NSDiffableDataSourceSnapshot *target)
{
    NSString *__strong *description = &lastDescription;
    NSUInteger which = next() % 19;
    NSArray *items = itemList(), *sections = sectionList();
    id one = maybe(^{ return item(); }), two = maybe(^{ return item(); });
    id sectionOne = maybe(^{ return section(); }), sectionTwo = maybe(^{ return section(); });
    switch (which) {
    case 0: *description = [NSString stringWithFormat:@"appendSections %@", sections]; [target appendSectionsWithIdentifiers:sections]; break;
    case 1: *description = [NSString stringWithFormat:@"appendItems %@", items]; [target appendItemsWithIdentifiers:items]; break;
    case 2: *description = [NSString stringWithFormat:@"appendItems %@ into %@", items, sectionOne]; [target appendItemsWithIdentifiers:items intoSectionWithIdentifier:sectionOne]; break;
    case 3: *description = [NSString stringWithFormat:@"insertItems %@ before %@", items, one]; [target insertItemsWithIdentifiers:items beforeItemWithIdentifier:one]; break;
    case 4: *description = [NSString stringWithFormat:@"insertItems %@ after %@", items, one]; [target insertItemsWithIdentifiers:items afterItemWithIdentifier:one]; break;
    case 5: *description = [NSString stringWithFormat:@"deleteItems %@", items]; [target deleteItemsWithIdentifiers:items]; break;
    case 6: *description = @"deleteAllItems"; [target deleteAllItems]; break;
    case 7: *description = [NSString stringWithFormat:@"moveItem %@ before %@", one, two]; [target moveItemWithIdentifier:one beforeItemWithIdentifier:two]; break;
    case 8: *description = [NSString stringWithFormat:@"moveItem %@ after %@", one, two]; [target moveItemWithIdentifier:one afterItemWithIdentifier:two]; break;
    case 9: *description = [NSString stringWithFormat:@"reloadItems %@", items]; [target reloadItemsWithIdentifiers:items]; break;
    case 10: *description = [NSString stringWithFormat:@"insertSections %@ before %@", sections, sectionOne]; [target insertSectionsWithIdentifiers:sections beforeSectionWithIdentifier:sectionOne]; break;
    case 11: *description = [NSString stringWithFormat:@"insertSections %@ after %@", sections, sectionOne]; [target insertSectionsWithIdentifiers:sections afterSectionWithIdentifier:sectionOne]; break;
    case 12: *description = [NSString stringWithFormat:@"deleteSections %@", sections]; [target deleteSectionsWithIdentifiers:sections]; break;
    case 13: *description = [NSString stringWithFormat:@"moveSection %@ before %@", sectionOne, sectionTwo]; [target moveSectionWithIdentifier:sectionOne beforeSectionWithIdentifier:sectionTwo]; break;
    case 14: *description = [NSString stringWithFormat:@"moveSection %@ after %@", sectionOne, sectionTwo]; [target moveSectionWithIdentifier:sectionOne afterSectionWithIdentifier:sectionTwo]; break;
    case 15: *description = [NSString stringWithFormat:@"reloadSections %@", sections]; [target reloadSectionsWithIdentifiers:sections]; break;
    case 16: *description = [NSString stringWithFormat:@"itemsIn %@", sectionOne]; (void)[target itemIdentifiersInSectionWithIdentifier:sectionOne]; break;
    case 17: *description = [NSString stringWithFormat:@"sectionOf %@", one]; (void)[target sectionIdentifierForSectionContainingItemIdentifier:one]; break;
    default: *description = [NSString stringWithFormat:@"numberIn %@", sectionOne]; (void)[target numberOfItemsInSection:sectionOne]; break;
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class port = NSClassFromString(@"CharonHostNSDiffableDataSourceSnapshot");
        CHECK(port != Nil, "the port defines the snapshot");
        CHECK([port superclass] == [NSObject class] && [port conformsToProtocol:@protocol(NSCopying)] == [NSDiffableDataSourceSnapshot conformsToProtocol:@protocol(NSCopying)]
                  && [port conformsToProtocol:@protocol(NSSecureCoding)] == [NSDiffableDataSourceSnapshot conformsToProtocol:@protocol(NSSecureCoding)], "it is an NSObject that copies and does not archive, as the system's is");
        for (NSString *name in @[@"reloadedSectionIdentifiers", @"reloadedItemIdentifiers", @"reconfiguredItemIdentifiers"])
            CHECK([port instancesRespondToSelector:NSSelectorFromString(name)] == NO, "a member of iOS 15 is not answered by accident");
        CHECK([port instancesRespondToSelector:NSSelectorFromString(@"reconfigureItemsWithIdentifiers:")] == NO, "reconfigureItems is not there");

        NSUInteger rounds = argc > 1 ? (NSUInteger)atoi(argv[1]) : 6000;
        NSMutableArray *samples = [NSMutableArray array];
        NSUInteger total = 0, wrong = 0;
        NSMutableDictionary *kinds = [NSMutableDictionary dictionary];
        for (NSUInteger round = 0; round < rounds; round++) {
            NSDiffableDataSourceSnapshot *ours = [[port alloc] init], *theirs = [[NSDiffableDataSourceSnapshot alloc] init];
            NSMutableArray *history = [NSMutableArray array];
            if (next() % 2) {
                NSArray *sections = @[@"A", @"B", @"C"];
                [ours appendSectionsWithIdentifiers:sections];
                [theirs appendSectionsWithIdentifiers:sections];
                [ours appendItemsWithIdentifiers:@[@"a", @"b"] intoSectionWithIdentifier:@"A"];
                [theirs appendItemsWithIdentifiers:@[@"a", @"b"] intoSectionWithIdentifier:@"A"];
                [ours appendItemsWithIdentifiers:@[@"c", @"d", @"e"] intoSectionWithIdentifier:@"B"];
                [theirs appendItemsWithIdentifiers:@[@"c", @"d", @"e"] intoSectionWithIdentifier:@"B"];
            }
            NSUInteger steps = 3 + next() % 12;
            for (NSUInteger step = 0; step < steps; step++) {
                uint64_t saved = state;
                NSString *a = outcome(^{ randomOperation(ours); });
                NSString *description = lastDescription;
                state = saved;
                NSString *b = outcome(^{ randomOperation(theirs); });
                [history addObject:description ?: @"?"];
                total++;
                NSString *kind = [a hasPrefix:@"raises"] ? [[[a componentsSeparatedByString:@" | "] objectAtIndex:1] substringToIndex:MIN(60, [[[a componentsSeparatedByString:@" | "] objectAtIndex:1] length])] : a;
                kinds[kind] = @([kinds[kind] integerValue] + 1);
                NSString *ourState = dump(ours), *theirState = dump(theirs);
                if (![a isEqualToString:b] || ![ourState isEqualToString:theirState] || [ours isEqual:theirs] != [theirs isEqual:ours]) {
                    wrong++;
                    if (samples.count < 20)
                        [samples addObject:[NSString stringWithFormat:@"%@\n     port   %@\n     system %@\n     port state   %@\n     system state %@", history, a, b, [ourState stringByReplacingOccurrencesOfString:@"\n" withString:@" / "], [theirState stringByReplacingOccurrencesOfString:@"\n" withString:@" / "]]];
                    break;
                }
                NSDiffableDataSourceSnapshot *copyOurs = [ours copy], *copyTheirs = [theirs copy];
                if (![dump(copyOurs) isEqualToString:dump(copyTheirs)] || ![copyOurs isEqual:ours] || [ours isEqual:theirs] != [theirs isEqual:ours]) {
                    wrong++;
                    if (samples.count < 20)
                        [samples addObject:[NSString stringWithFormat:@"copy after %@", history]];
                    break;
                }
            }
        }
        printf("snapshot: compared %lu steps, %lu sequences differing\n", (unsigned long)total, (unsigned long)wrong);
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        printf("outcomes: %lu kinds\n", (unsigned long)kinds.count);
        for (NSString *kind in [kinds.allKeys sortedArrayUsingSelector:@selector(compare:)])
            printf("  %5ld %s\n", (long)[kinds[kind] integerValue], kind.UTF8String);
        charon_check(wrong == 0, "random sequences of snapshot operations end in the system's state or exception", [NSString stringWithFormat:@"%lu differ", (unsigned long)wrong]);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
