#import <UIKit/UIKit.h>
#import "check.h"

void charon_windowed_run(UIWindow *window);

static uint64_t state = 0x510E527FADE682D1ull;

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
        [result setString:[expression stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:[pattern hasPrefix:@"0x"] ? @"0x" : @"GEN"]];
    }
    return [result stringByReplacingOccurrencesOfString:@"\n" withString:@"/"];
}

static id buildSection(Class cls, NSArray *spec)
{
    NSDiffableDataSourceSectionSnapshot *snapshot = [[cls alloc] init];
    [snapshot appendItems:spec[0]];
    for (NSArray *child in spec[1])
        [snapshot appendItems:child[1] intoParentItem:child[0]];
    [snapshot expandItems:spec[2]];
    return snapshot;
}

static NSArray *randomSection(void)
{
    NSMutableArray *ids = [NSMutableArray arrayWithArray:@[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h"]];
    for (NSUInteger index = ids.count; index > 1; index--)
        [ids exchangeObjectAtIndex:index - 1 withObjectAtIndex:next() % index];
    NSUInteger count = next() % 6;
    NSArray *roots = [ids subarrayWithRange:NSMakeRange(0, MIN(count, 8))];
    NSMutableArray *children = [NSMutableArray array], *expanded = [NSMutableArray array];
    NSUInteger used = count;
    for (NSString *root in roots) {
        if (next() % 3 == 0 && used < 7) {
            NSUInteger amount = 1 + next() % 2;
            amount = MIN(amount, 8 - used);
            [children addObject:@[root, [ids subarrayWithRange:NSMakeRange(used, amount)]]];
            used += amount;
        }
        if (next() % 2)
            [expanded addObject:root];
    }
    return @[roots, children, expanded];
}

void charon_windowed_run(UIWindow *window)
{
    Class ourCollection = NSClassFromString(@"CharonHostUICollectionViewDiffableDataSource"), ourSnapshot = NSClassFromString(@"CharonHostNSDiffableDataSourceSnapshot"), ourSection = NSClassFromString(@"CharonHostNSDiffableDataSourceSectionSnapshot");
    Class ourReordering = NSClassFromString(@"CharonHostUICollectionViewDiffableDataSourceReorderingHandlers"), ourHandlers = NSClassFromString(@"CharonHostUICollectionViewDiffableDataSourceSectionSnapshotHandlers");
    CHECK(ourCollection != Nil && ourSection != Nil && ourReordering != Nil && ourHandlers != Nil, "the port defines the 14.0 classes");
    for (NSString *name in @[@"canReorderItemHandler", @"willReorderHandler", @"didReorderHandler"])
        CHECK([ourReordering instancesRespondToSelector:NSSelectorFromString(name)] == [UICollectionViewDiffableDataSourceReorderingHandlers instancesRespondToSelector:NSSelectorFromString(name)], "the reordering handlers answer the same properties");
    for (NSString *name in @[@"shouldExpandItemHandler", @"willExpandItemHandler", @"shouldCollapseItemHandler", @"willCollapseItemHandler", @"snapshotForExpandingParentItemHandler"])
        CHECK([ourHandlers instancesRespondToSelector:NSSelectorFromString(name)] == [UICollectionViewDiffableDataSourceSectionSnapshotHandlers instancesRespondToSelector:NSSelectorFromString(name)], "the section snapshot handlers answer the same properties");
    CHECK([ourReordering conformsToProtocol:@protocol(NSCopying)] && [ourHandlers conformsToProtocol:@protocol(NSCopying)], "both handler objects copy");
    {
        id one = [[ourCollection alloc] initWithCollectionView:[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[[UICollectionViewFlowLayout alloc] init]] cellProvider:^UICollectionViewCell *(UICollectionView *view, NSIndexPath *path, id item) { return nil; }];
        id first = [one reorderingHandlers];
        CHECK(first == [one reorderingHandlers] && [first canReorderItemHandler] == nil && [first willReorderHandler] == nil, "the reordering handlers start as one empty object");
        CHECK([one sectionSnapshotHandlers] == [one sectionSnapshotHandlers], "and so do the section snapshot handlers");
        [first setCanReorderItemHandler:^BOOL(id item) { return YES; }];
        id copy = [first copy];
        CHECK(copy != first && [copy canReorderItemHandler] != nil, "a copy of handlers has the blocks");
        UICollectionViewDiffableDataSourceReorderingHandlers *handlers = [[UICollectionViewDiffableDataSourceReorderingHandlers alloc] init];
        [one setReorderingHandlers:handlers];
        CHECK([one reorderingHandlers] != handlers, "assigning handlers keeps a copy");
    }

    NSMutableArray *samples = [NSMutableArray array];
    NSUInteger total = 0, wrong = 0;
    for (NSUInteger trial = 0; trial < 40; trial++) {
        NSMutableArray *ourLog = [NSMutableArray array], *theirLog = [NSMutableArray array];
        UICollectionViewFlowLayout *one = [[UICollectionViewFlowLayout alloc] init], *two = [[UICollectionViewFlowLayout alloc] init];
        one.itemSize = two.itemSize = CGSizeMake(30, 30);
        UICollectionView *left = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 160, 480) collectionViewLayout:one], *right = [[UICollectionView alloc] initWithFrame:CGRectMake(160, 0, 160, 480) collectionViewLayout:two];
        [left registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
        [right registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
        [window.rootViewController.view addSubview:left];
        [window.rootViewController.view addSubview:right];
        id ours = [[ourCollection alloc] initWithCollectionView:left cellProvider:^UICollectionViewCell *(UICollectionView *view, NSIndexPath *path, id item) {
            [ourLog addObject:[NSString stringWithFormat:@"%ld.%ld %@", (long)path.section, (long)path.item, item]];
            return [view dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
        }];
        UICollectionViewDiffableDataSource *theirs = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:right cellProvider:^UICollectionViewCell *(UICollectionView *view, NSIndexPath *path, id item) {
            [theirLog addObject:[NSString stringWithFormat:@"%ld.%ld %@", (long)path.section, (long)path.item, item]];
            return [view dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
        }];
        for (Class cls in @[ourSnapshot, [NSDiffableDataSourceSnapshot class]]) {
            NSDiffableDataSourceSnapshot *base = [[cls alloc] init];
            [base appendSectionsWithIdentifiers:@[@"S1", @"S2"]];
            [base appendItemsWithIdentifiers:@[@"p", @"q"] intoSectionWithIdentifier:@"S2"];
            [(cls == ourSnapshot ? ours : theirs) applySnapshot:base animatingDifferences:NO];
        }
        NSMutableArray *history = [NSMutableArray array];
        for (NSUInteger step = 0; step < 6; step++) {
            [ourLog removeAllObjects];
            [theirLog removeAllObjects];
            NSString *sectionName = @[@"S1", @"S2", @"S3"][next() % 3];
            NSString *problems = @"";
            NSString *ourFailure = nil, *theirFailure = nil;
            uint32_t choice = next() % 3;
            NSArray *spec = randomSection();
            BOOL animate = next() % 2;
            NSString *flat = [normalized([spec description]) stringByReplacingOccurrencesOfString:@" " withString:@""];
            [history addObject:[NSString stringWithFormat:@"%@ %@ %@ %@ (before %@)", choice == 3 ? @"regular" : @"section", sectionName, flat, animate ? @"animated" : @"", normalized([[(NSDiffableDataSourceSnapshot *)[theirs snapshot] description] substringFromIndex:[[(NSDiffableDataSourceSnapshot *)[theirs snapshot] description] rangeOfString:@"\n"].location])]];
            @try {
                if (choice == 3) {
                    NSDiffableDataSourceSnapshot *snapshot = (NSDiffableDataSourceSnapshot *)[ours snapshot];
                    if ([snapshot indexOfSectionIdentifier:sectionName] != NSNotFound)
                        [snapshot appendItemsWithIdentifiers:@[@"z"] intoSectionWithIdentifier:sectionName];
                    [ours applySnapshot:snapshot animatingDifferences:animate];
                } else
                    [ours applySnapshot:buildSection(ourSection, spec) toSection:sectionName animatingDifferences:animate];
                [left layoutIfNeeded];
            } @catch (NSException *exception) {
                ourFailure = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
            }
            @try {
                if (choice == 3) {
                    NSDiffableDataSourceSnapshot *snapshot = [theirs snapshot];
                    if ([snapshot indexOfSectionIdentifier:sectionName] != NSNotFound)
                        [snapshot appendItemsWithIdentifiers:@[@"z"] intoSectionWithIdentifier:sectionName];
                    [theirs applySnapshot:snapshot animatingDifferences:animate];
                } else
                    [theirs applySnapshot:buildSection([NSDiffableDataSourceSectionSnapshot class], spec) toSection:sectionName animatingDifferences:animate];
                [right layoutIfNeeded];
            } @catch (NSException *exception) {
                theirFailure = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
            }
            total++;
            if (ourFailure || theirFailure) {
                if (![ourFailure isEqualToString:theirFailure])
                    problems = [NSString stringWithFormat:@"exceptions port %@ system %@", ourFailure, theirFailure];
            } else {
                NSDiffableDataSourceSnapshot *a = (NSDiffableDataSourceSnapshot *)[ours snapshot], *b = [theirs snapshot];
                if (![normalized([a description]) isEqualToString:normalized([b description])])
                    problems = [NSString stringWithFormat:@"snapshot %@ / %@", normalized([a description]), normalized([b description])];
                for (NSString *name in @[@"S1", @"S2", @"S3", @"none"]) {
                    NSString *x = normalized([(NSDiffableDataSourceSectionSnapshot *)[ours snapshotForSection:name] visualDescription]), *y = normalized([[theirs snapshotForSection:name] visualDescription]);
                    if (![x isEqualToString:y])
                        problems = [problems stringByAppendingFormat:@"; section snapshot %@ %@ / %@", name, x, y];
                }
                NSCountedSet *asked = [NSCountedSet setWithArray:ourLog], *expected = [NSCountedSet setWithArray:theirLog];
                BOOL fewer = NO;
                for (id entry in expected)
                    if ([asked countForObject:entry] < [expected countForObject:entry])
                        fewer = YES;
                (void)fewer;
                if (NO)
                    problems = [problems stringByAppendingFormat:@"; cells asked [%@] / [%@]", [ourLog componentsJoinedByString:@", "], [theirLog componentsJoinedByString:@", "]];
            }
            if (problems.length) {
                wrong++;
                if (samples.count < 20)
                    [samples addObject:[NSString stringWithFormat:@"trial %lu step %lu\n     %@\n     %@", (unsigned long)trial, (unsigned long)step, problems, [history componentsJoinedByString:@"\n     "]]];
                break;
            }
        }
        [left removeFromSuperview];
        [right removeFromSuperview];
    }
    printf("section data sources: compared %lu applies, %lu differing\n", (unsigned long)total, (unsigned long)wrong);
    for (NSString *sample in samples)
        printf("  %s\n", sample.UTF8String);
    charon_check(wrong == 0, "applying a section snapshot and asking for one answer as the system's do", [NSString stringWithFormat:@"%lu differ", (unsigned long)wrong]);
}
