#import <UIKit/UIKit.h>

#define DIFFABLE_CASE_COUNT 800

static uint64_t df_mix(uint64_t value)
{
    value += 0x9E3779B97F4A7C15ull;
    value = (value ^ (value >> 30)) * 0xBF58476D1CE4E5B9ull;
    value = (value ^ (value >> 27)) * 0x94D049BB133111EBull;
    return value ^ (value >> 31);
}

static uint32_t df_draw(uint64_t *state)
{
    *state = df_mix(*state);
    return (uint32_t)(*state >> 20);
}

static uint64_t df_hash(NSString *text)
{
    uint64_t hash = 0xcbf29ce484222325ull;
    for (const unsigned char *byte = (const unsigned char *)text.UTF8String; *byte; byte++)
        hash = (hash ^ *byte) * 0x100000001b3ull;
    return hash;
}

static NSString *df_normalized(NSString *text)
{
    NSMutableString *result = [text mutableCopy];
    [result replaceOccurrencesOfString:@"CharonHost" withString:@"" options:0 range:NSMakeRange(0, result.length)];
    for (NSString *pattern in @[@"0x[0-9a-fA-F]+", @"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"]) {
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
        [result setString:[expression stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:[pattern hasPrefix:@"0x"] ? @"0x" : @"GEN"]];
    }
    return result;
}

static NSString *df_outcome(void (^body)(void))
{
    @try {
        body();
        return @"ok";
    } @catch (NSException *exception) {
        BOOL ours = [exception.name isEqual:NSInternalInconsistencyException];
        return df_normalized([NSString stringWithFormat:@"raises %@ | %@ | %@ %@", exception.name, ours ? exception.reason : @"", exception.userInfo[@"NSAssertFile"] ?: @"", exception.userInfo[@"NSAssertLine"] ?: @""]);
    }
}

static NSString *df_dump(NSDiffableDataSourceSnapshot *snapshot)
{
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"%ld %ld [%@] [%@]\n", (long)snapshot.numberOfSections, (long)snapshot.numberOfItems, [snapshot.sectionIdentifiers componentsJoinedByString:@" "], [snapshot.itemIdentifiers componentsJoinedByString:@" "]];
    for (id section in snapshot.sectionIdentifiers)
        [text appendFormat:@"%@: %ld [%@] %ld\n", section, (long)[snapshot numberOfItemsInSection:section], [[snapshot itemIdentifiersInSectionWithIdentifier:section] componentsJoinedByString:@" "], (long)[snapshot indexOfSectionIdentifier:section]];
    for (id item in snapshot.itemIdentifiers)
        [text appendFormat:@"%@ in %@ at %ld\n", item, [snapshot sectionIdentifierForSectionContainingItemIdentifier:item], (long)[snapshot indexOfItemIdentifier:item]];
    [text appendString:df_normalized(snapshot.description)];
    return text;
}

static NSString *df_section_dump(NSDiffableDataSourceSectionSnapshot *snapshot)
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"[%@] [%@] [%@] [%@]\n", [snapshot.items componentsJoinedByString:@" "], [snapshot.rootItems componentsJoinedByString:@" "], [snapshot.visibleItems componentsJoinedByString:@" "], [snapshot.expandedItems componentsJoinedByString:@" "]];
    for (id item in @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @"zz"]) {
        [text appendFormat:@"%@: %d %ld ", item, [snapshot containsItem:item], (long)([snapshot indexOfItem:item] == NSNotFound ? -1 : [snapshot indexOfItem:item])];
        [text appendString:df_outcome(^{ [text appendFormat:@"%ld %d %d %@", (long)[snapshot levelOfItem:item], [snapshot isExpanded:item], [snapshot isVisible:item], [snapshot parentOfChildItem:item] ?: @"-"]; })];
        [text appendString:@"\n"];
    }
    [text appendString:df_normalized(snapshot.visualDescription)];
    return text;
}

static id df_pick(uint64_t *state, NSArray *universe, NSUInteger nilOneIn)
{
    return nilOneIn && df_draw(state) % nilOneIn == 0 ? nil : universe[df_draw(state) % universe.count];
}

static NSArray *df_list(uint64_t *state, NSArray *universe)
{
    if (df_draw(state) % 14 == 0)
        return nil;
    NSMutableArray *list = [NSMutableArray array];
    for (NSUInteger index = 0, count = df_draw(state) % 4; index < count; index++)
        [list addObject:universe[df_draw(state) % universe.count]];
    return list;
}

static NSString *df_snapshot_case(uint64_t *state)
{
    NSArray *items = @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @1, @2, @"zz"], *sections = @[@"A", @"B", @"C", @"D", @"E", @"ZZ"];
    NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    NSMutableString *out = [NSMutableString string];
    if (df_draw(state) % 2) {
        [snapshot appendSectionsWithIdentifiers:@[@"A", @"B", @"C"]];
        [snapshot appendItemsWithIdentifiers:@[@"a", @"b"] intoSectionWithIdentifier:@"A"];
        [snapshot appendItemsWithIdentifiers:@[@"c", @"d", @"e"] intoSectionWithIdentifier:@"B"];
    }
    for (NSUInteger step = 0, steps = 3 + df_draw(state) % 10; step < steps; step++) {
        NSArray *itemList = df_list(state, items), *sectionList = df_list(state, sections);
        id one = df_pick(state, items, 12), two = df_pick(state, items, 12), sectionOne = df_pick(state, sections, 12), sectionTwo = df_pick(state, sections, 12);
        NSString *result;
        switch (df_draw(state) % 18) {
        case 0: { result = df_outcome(^{ [snapshot appendSectionsWithIdentifiers:sectionList]; }); break; }
        case 1: { result = df_outcome(^{ [snapshot appendItemsWithIdentifiers:itemList]; }); break; }
        case 2: { result = df_outcome(^{ [snapshot appendItemsWithIdentifiers:itemList intoSectionWithIdentifier:sectionOne]; }); break; }
        case 3: { result = df_outcome(^{ [snapshot insertItemsWithIdentifiers:itemList beforeItemWithIdentifier:one]; }); break; }
        case 4: { result = df_outcome(^{ [snapshot insertItemsWithIdentifiers:itemList afterItemWithIdentifier:one]; }); break; }
        case 5: { result = df_outcome(^{ [snapshot deleteItemsWithIdentifiers:itemList]; }); break; }
        case 6: { result = df_outcome(^{ [snapshot deleteAllItems]; }); break; }
        case 7: { result = df_outcome(^{ [snapshot moveItemWithIdentifier:one beforeItemWithIdentifier:two]; }); break; }
        case 8: { result = df_outcome(^{ [snapshot moveItemWithIdentifier:one afterItemWithIdentifier:two]; }); break; }
        case 9: { result = df_outcome(^{ [snapshot reloadItemsWithIdentifiers:itemList]; }); break; }
        case 10: { result = df_outcome(^{ [snapshot insertSectionsWithIdentifiers:sectionList beforeSectionWithIdentifier:sectionOne]; }); break; }
        case 11: { result = df_outcome(^{ [snapshot insertSectionsWithIdentifiers:sectionList afterSectionWithIdentifier:sectionOne]; }); break; }
        case 12: { result = df_outcome(^{ [snapshot deleteSectionsWithIdentifiers:sectionList]; }); break; }
        case 13: { result = df_outcome(^{ [snapshot moveSectionWithIdentifier:sectionOne beforeSectionWithIdentifier:sectionTwo]; }); break; }
        case 14: { result = df_outcome(^{ [snapshot moveSectionWithIdentifier:sectionOne afterSectionWithIdentifier:sectionTwo]; }); break; }
        case 15: { result = df_outcome(^{ [snapshot reloadSectionsWithIdentifiers:sectionList]; }); break; }
        case 16: { result = df_outcome(^{ (void)[snapshot itemIdentifiersInSectionWithIdentifier:sectionOne]; }); break; }
        default: { result = df_outcome(^{ (void)[snapshot numberOfItemsInSection:sectionOne]; }); break; }
        }
        [out appendFormat:@"%@\n%@\n", result, df_dump(snapshot)];
        NSDiffableDataSourceSnapshot *copy = [snapshot copy];
        [out appendFormat:@"%d %@\n", [copy isEqual:snapshot], df_dump(copy) ];
    }
    return out;
}

static NSString *df_section_case(uint64_t *state)
{
    NSArray *items = @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @"zz"];
    NSDiffableDataSourceSectionSnapshot *snapshot = [[NSDiffableDataSourceSectionSnapshot alloc] init];
    NSMutableString *out = [NSMutableString string];
    if (df_draw(state) % 2) {
        [snapshot appendItems:@[@"a", @"b", @"c"]];
        [snapshot appendItems:@[@"d", @"e"] intoParentItem:@"a"];
        [snapshot appendItems:@[@"f"] intoParentItem:@"d"];
        [snapshot appendItems:@[@"g"] intoParentItem:@"c"];
    }
    for (NSUInteger step = 0, steps = 3 + df_draw(state) % 10; step < steps; step++) {
        NSArray *list = df_list(state, items);
        id one = df_pick(state, items, 12), two = df_pick(state, items, 12);
        NSString *result;
        switch (df_draw(state) % 12) {
        case 0: { result = df_outcome(^{ [snapshot appendItems:list]; }); break; }
        case 1: { result = df_outcome(^{ [snapshot appendItems:list intoParentItem:one]; }); break; }
        case 2: { result = df_outcome(^{ [snapshot insertItems:list beforeItem:one]; }); break; }
        case 3: { result = df_outcome(^{ [snapshot insertItems:list afterItem:one]; }); break; }
        case 4: { result = df_outcome(^{ [snapshot deleteItems:list]; }); break; }
        case 5: { result = df_outcome(^{ [snapshot expandItems:list]; }); break; }
        case 6: { result = df_outcome(^{ [snapshot collapseItems:list]; }); break; }
        case 7: { result = df_outcome(^{ NSDiffableDataSourceSectionSnapshot *child = [[NSDiffableDataSourceSectionSnapshot alloc] init]; [child appendItems:@[[NSString stringWithFormat:@"q%u", df_draw(state) % 1000]]]; [snapshot replaceChildrenOfParentItem:one withSnapshot:child]; }); break; }
        case 8: { result = df_outcome(^{ NSDiffableDataSourceSectionSnapshot *child = [[NSDiffableDataSourceSectionSnapshot alloc] init]; [child appendItems:@[[NSString stringWithFormat:@"r%u", df_draw(state) % 1000], [NSString stringWithFormat:@"s%u", df_draw(state) % 1000]]]; [snapshot insertSnapshot:child beforeItem:one]; }); break; }
        case 9: { result = df_outcome(^{ NSDiffableDataSourceSectionSnapshot *child = [[NSDiffableDataSourceSectionSnapshot alloc] init]; [child appendItems:@[[NSString stringWithFormat:@"t%u", df_draw(state) % 1000]]]; [out appendFormat:@"returned %@\n", [snapshot insertSnapshot:child afterItem:one]]; }); break; }
        case 10: { result = df_outcome(^{ [out appendString:df_section_dump([snapshot snapshotOfParentItem:one includingParentItem:df_draw(state) % 2])]; }); break; }
        default: { result = df_outcome(^{ (void)[snapshot levelOfItem:two]; }); break; }
        }
        [out appendFormat:@"%@\n%@\n", result, df_section_dump(snapshot)];
    }
    return out;
}

static NSString *df_answer(size_t index)
{
    uint64_t state = index * 104729 + 7;
    return index % 3 == 2 ? df_section_case(&state) : df_snapshot_case(&state);
}
