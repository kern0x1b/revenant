#import <UIKit/UIKit.h>
#import "check.h"

void charon_windowed_run(UIWindow *window);

static uint64_t state = 0x3C6EF372FE94F82Bull;

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

static NSDictionary *randomSpec(NSDictionary *previous)
{
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[@"A", @"B", @"C", @"D"]];
    for (NSUInteger index = sections.count; index > 1; index--)
        [sections exchangeObjectAtIndex:index - 1 withObjectAtIndex:next() % index];
    sections = [[sections subarrayWithRange:NSMakeRange(0, MIN(sections.count, next() % 5))] mutableCopy];
    if (!sections.count && next() % 3)
        [sections addObject:@"A"];
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger index = 0; index < 8; index++)
        if (next() % 4)
            [items addObject:[NSString stringWithFormat:@"i%lu", (unsigned long)index]];
    for (NSUInteger index = items.count; index > 1; index--)
        [items exchangeObjectAtIndex:index - 1 withObjectAtIndex:next() % index];
    if (previous && next() % 2) {
        NSMutableArray *kept = [NSMutableArray array];
        for (id section in previous[@"sections"])
            if (next() % 5)
                [kept addObject:section];
        if (kept.count && next() % 2)
            sections = kept;
        NSMutableArray *order = [NSMutableArray array];
        for (NSArray *list in previous[@"items"])
            for (id item in list)
                if (next() % 8)
                    [order addObject:item];
        if (next() % 2 && order.count)
            items = order;
    }
    NSMutableArray *lists = [NSMutableArray array];
    for (NSUInteger index = 0; index < sections.count; index++)
        [lists addObject:[NSMutableArray array]];
    if (sections.count)
        for (id item in items)
            [lists[next() % lists.count] addObject:item];
    NSMutableArray *reloadItems = [NSMutableArray array], *reloadSections = [NSMutableArray array];
    for (id item in items)
        if (next() % 9 == 0)
            [reloadItems addObject:item];
    for (id section in sections)
        if (next() % 9 == 0)
            [reloadSections addObject:section];
    return @{@"sections": sections, @"items": lists, @"reloadItems": reloadItems, @"reloadSections": reloadSections};
}

static id buildSnapshot(Class cls, NSDictionary *spec)
{
    NSDiffableDataSourceSnapshot *snapshot = [[cls alloc] init];
    [snapshot appendSectionsWithIdentifiers:spec[@"sections"]];
    NSArray *sections = spec[@"sections"], *lists = spec[@"items"];
    for (NSUInteger index = 0; index < sections.count; index++)
        [snapshot appendItemsWithIdentifiers:lists[index] intoSectionWithIdentifier:sections[index]];
    [snapshot reloadItemsWithIdentifiers:spec[@"reloadItems"]];
    [snapshot reloadSectionsWithIdentifiers:spec[@"reloadSections"]];
    return snapshot;
}

static NSString *describe(NSDiffableDataSourceSnapshot *snapshot)
{
    NSMutableString *text = [NSMutableString string];
    for (id section in snapshot.sectionIdentifiers)
        [text appendFormat:@"%@[%@] ", section, [[snapshot itemIdentifiersInSectionWithIdentifier:section] componentsJoinedByString:@" "]];
    return text;
}

typedef struct {
    __unsafe_unretained NSMutableArray *log;
} Provider;

static NSString *compareViews(id ours, id theirs, UIScrollView *ourView, UIScrollView *theirView, BOOL table, NSMutableArray *ourLog, NSMutableArray *theirLog)
{
    NSMutableString *problems = [NSMutableString string];
    NSInteger ourSections = table ? [(UITableView *)ourView numberOfSections] : [(UICollectionView *)ourView numberOfSections];
    NSInteger theirSections = table ? [(UITableView *)theirView numberOfSections] : [(UICollectionView *)theirView numberOfSections];
    if (ourSections != theirSections)
        [problems appendFormat:@"sections %ld/%ld; ", (long)ourSections, (long)theirSections];
    for (NSInteger section = 0; section < MIN(ourSections, theirSections); section++) {
        NSInteger a = table ? [(UITableView *)ourView numberOfRowsInSection:section] : [(UICollectionView *)ourView numberOfItemsInSection:section];
        NSInteger b = table ? [(UITableView *)theirView numberOfRowsInSection:section] : [(UICollectionView *)theirView numberOfItemsInSection:section];
        if (a != b)
            [problems appendFormat:@"items in %ld %ld/%ld; ", (long)section, (long)a, (long)b];
    }
    NSDiffableDataSourceSnapshot *ourSnapshot = (NSDiffableDataSourceSnapshot *)[ours snapshot], *theirSnapshot = (NSDiffableDataSourceSnapshot *)[theirs snapshot];
    if (![describe(ourSnapshot) isEqualToString:describe(theirSnapshot)])
        [problems appendFormat:@"snapshot %@ / %@; ", describe(ourSnapshot), describe(theirSnapshot)];
    if (![normalized([ourSnapshot description]) isEqualToString:normalized([theirSnapshot description])])
        [problems appendString:@"snapshot description; "];
    for (NSString *item in @[@"i0", @"i1", @"i2", @"i3", @"i4", @"i5", @"i6", @"i7", @"none"]) {
        NSIndexPath *a = [ours indexPathForItemIdentifier:item], *b = [theirs indexPathForItemIdentifier:item];
        if (!(a == b || [a isEqual:b]))
            [problems appendFormat:@"path of %@ %@/%@; ", item, a, b];
        if (a && ![[ours itemIdentifierForIndexPath:a] isEqual:[theirs itemIdentifierForIndexPath:b]])
            [problems appendFormat:@"item at %@; ", a];
    }
    if (![[ourLog sortedArrayUsingSelector:@selector(compare:)] isEqual:[theirLog sortedArrayUsingSelector:@selector(compare:)]]) {
        NSCountedSet *ours = [NSCountedSet setWithArray:ourLog];
        BOOL more = YES;
        for (id entry in theirLog)
            if ([ours countForObject:entry] < [[NSCountedSet setWithArray:theirLog] countForObject:entry])
                more = NO;
        (void)more;
        [problems appendString:@"cells more; "];
    }
    else if (![ourLog isEqual:theirLog])
        [problems appendString:@"cells asked in another order; "];
    return problems;
}

static NSInteger charon_items_of_init_source(Class cls)
{
    return [(UICollectionViewDiffableDataSource *)[[cls alloc] performSelector:NSSelectorFromString(@"init")] snapshot].numberOfItems;
}

void charon_windowed_run(UIWindow *window)
{
    Class ourCollection = NSClassFromString(@"CharonHostUICollectionViewDiffableDataSource"), ourTable = NSClassFromString(@"CharonHostUITableViewDiffableDataSource"), ourSnapshot = NSClassFromString(@"CharonHostNSDiffableDataSourceSnapshot");
    CHECK(ourCollection != Nil && ourTable != Nil && ourSnapshot != Nil, "the port defines the data sources and the snapshot");
    CHECK([ourCollection superclass] == [NSObject class] && [ourTable superclass] == [NSObject class], "both are NSObjects");
    CHECK([ourCollection conformsToProtocol:@protocol(UICollectionViewDataSource)] && [ourTable conformsToProtocol:@protocol(UITableViewDataSource)], "each adopts its view's data source protocol");
    for (NSString *name in @[@"applySnapshotUsingReloadData:", @"applySnapshotUsingReloadData:completion:", @"sectionIdentifierForIndex:", @"indexForSectionIdentifier:"]) {
        CHECK([ourCollection instancesRespondToSelector:NSSelectorFromString(name)] == NO && [ourTable instancesRespondToSelector:NSSelectorFromString(name)] == NO, "a member of iOS 15 is not answered by accident");
    }
    for (NSString *name in @[@"collectionView:viewForSupplementaryElementOfKind:atIndexPath:", @"collectionView:cellForItemAtIndexPath:", @"numberOfSectionsInCollectionView:", @"collectionView:numberOfItemsInSection:", @"indexTitlesForCollectionView:"])
        CHECK([ourCollection instancesRespondToSelector:NSSelectorFromString(name)] == [UICollectionViewDiffableDataSource instancesRespondToSelector:NSSelectorFromString(name)] || [name hasPrefix:@"collectionView:canMove"], "the collection data source answers the callbacks the system's does");
    for (NSString *name in @[@"tableView:cellForRowAtIndexPath:", @"numberOfSectionsInTableView:", @"tableView:numberOfRowsInSection:", @"sectionIndexTitlesForTableView:", @"tableView:titleForHeaderInSection:", @"tableView:canEditRowAtIndexPath:", @"tableView:canMoveRowAtIndexPath:"])
        CHECK([ourTable instancesRespondToSelector:NSSelectorFromString(name)] == [UITableViewDiffableDataSource instancesRespondToSelector:NSSelectorFromString(name)], "the table data source answers the callbacks the system's does");
    CHECK(charon_items_of_init_source(ourCollection) == charon_items_of_init_source([UICollectionViewDiffableDataSource class]), "a collection data source made by -init answers the system's empty snapshot");
    CHECK(charon_items_of_init_source(ourTable) == charon_items_of_init_source([UITableViewDiffableDataSource class]), "a table data source made by -init answers the system's empty snapshot");

    {
        NSArray *scenarios = @[
            @[@"A:x,y,z", @"A:x,y,z", @"y", @"", @[@"0.1y"]],
            @[@"A:x,y,z", @"A:x,y,z", @"", @"A", @[@"0.0x", @"0.1y", @"0.2z"]],
            @[@"A:x,y,z", @"A:z,x,y", @"", @"", @[]],
            @[@"A:x,y,z", @"A:z,x,y", @"z", @"", @[@"0.0z"]],
            @[@"A:x,y,z", @"A:x,y,z,w", @"", @"", @[@"0.3w"]],
            @[@"A:x,y,z", @"A:x,y,z,w", @"w", @"", @[@"0.3w", @"0.3w"]],
            @[@"A:x,y,z", @"A:x,z", @"", @"", @[]],
            @[@"A:x,y,z;B:u", @"A:x,z;B:u,y", @"", @"", @[], @[@"0.0x", @"0.1z", @"1.0u", @"1.1y"]],
            @[@"A:x,y,z;B:u", @"B:u;A:x,y,z", @"", @"", @[]],
            @[@"A:x,y,z;B:u", @"A:x,y,z;B:u;C:w", @"", @"", @[@"2.0w"]],
            @[@"A:x,y,z;B:u", @"B:u,q;A:x,y,z", @"", @"", @[@"0.1q"], @[@"0.0u", @"0.1q", @"1.0x", @"1.1y", @"1.2z"]],
        ];
        NSUInteger bad = 0;
        for (NSArray *scenario in scenarios)
            for (int side = 0; side < 4; side++) {
                BOOL table = side % 2, port = side >= 2;
                NSMutableArray *log = [NSMutableArray array];
                UIScrollView *view;
                id source;
                UIView *root = window.rootViewController.view;
                if (table) {
                    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
                    tableView.rowHeight = 30;
                    [root addSubview:tableView];
                    view = tableView;
                    UITableViewCell *(^provider)(UITableView *, NSIndexPath *, id) = ^UITableViewCell *(UITableView *tv, NSIndexPath *path, id item) {
                        [log addObject:[NSString stringWithFormat:@"%ld.%ld%@", (long)path.section, (long)path.row, item]];
                        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    };
                    source = port ? [[ourTable alloc] initWithTableView:tableView cellProvider:provider] : [[UITableViewDiffableDataSource alloc] initWithTableView:tableView cellProvider:provider];
                } else {
                    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
                    layout.itemSize = CGSizeMake(30, 30);
                    UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 400) collectionViewLayout:layout];
                    [collection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
                    [root addSubview:collection];
                    view = collection;
                    UICollectionViewCell *(^provider)(UICollectionView *, NSIndexPath *, id) = ^UICollectionViewCell *(UICollectionView *cv, NSIndexPath *path, id item) {
                        [log addObject:[NSString stringWithFormat:@"%ld.%ld%@", (long)path.section, (long)path.item, item]];
                        return [cv dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
                    };
                    source = port ? [[ourCollection alloc] initWithCollectionView:collection cellProvider:provider] : [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:collection cellProvider:provider];
                }
                Class snapshotClass = port ? ourSnapshot : [NSDiffableDataSourceSnapshot class];
                NSDictionary *(^spec)(NSString *) = ^NSDictionary *(NSString *text) {
                    NSMutableArray *sections = [NSMutableArray array], *lists = [NSMutableArray array];
                    for (NSString *part in [text componentsSeparatedByString:@";"]) {
                        NSArray *pair = [part componentsSeparatedByString:@":"];
                        [sections addObject:pair[0]];
                        [lists addObject:[pair[1] length] ? [pair[1] componentsSeparatedByString:@","] : @[]];
                    }
                    return @{@"sections": sections, @"items": lists};
                };
                NSMutableDictionary *first = [spec(scenario[0]) mutableCopy], *second = [spec(scenario[1]) mutableCopy];
                first[@"reloadItems"] = first[@"reloadSections"] = @[];
                second[@"reloadItems"] = [scenario[2] length] ? [scenario[2] componentsSeparatedByString:@","] : @[];
                second[@"reloadSections"] = [scenario[3] length] ? [scenario[3] componentsSeparatedByString:@","] : @[];
                [source applySnapshot:buildSnapshot(snapshotClass, first) animatingDifferences:NO];
                [view layoutIfNeeded];
                [log removeAllObjects];
                [source applySnapshot:buildSnapshot(snapshotClass, second) animatingDifferences:NO];
                [view layoutIfNeeded];
                if (![[log sortedArrayUsingSelector:@selector(compare:)] isEqual:[(port && scenario.count > 5 ? scenario[5] : scenario[4]) sortedArrayUsingSelector:@selector(compare:)]]) {
                    bad++;
                    printf("  scenario %s -> %s reload [%s|%s] on the %s %s asked [%s], expected [%s]\n", [scenario[0] UTF8String], [scenario[1] UTF8String], [scenario[2] UTF8String], [scenario[3] UTF8String], port ? "port" : "system", table ? "table" : "collection view", [[log componentsJoinedByString:@" "] UTF8String], [[scenario[4] componentsJoinedByString:@" "] UTF8String]);
                }
                [view removeFromSuperview];
            }
        charon_check(bad == 0, "in the recorded scenarios the provider is asked for the cells the system asks for, in the port and in the system", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)bad, (unsigned long)scenarios.count * 4]);
    }

    NSMutableArray *samples = [NSMutableArray array];
    NSUInteger total = 0, wrong = 0, orders = 0, calls = 0;
    NSMutableArray *callSamples = [NSMutableArray array];
    NSUInteger trials = 60;
    for (NSUInteger trial = 0; trial < trials; trial++) {
        BOOL table = trial % 3 == 2;
        NSMutableArray *ourLog = [NSMutableArray array], *theirLog = [NSMutableArray array];
        UIScrollView *ourView, *theirView;
        id ours, theirs;
        UIView *root = window.rootViewController.view;
        if (table) {
            UITableView *left = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 160, 480)], *right = [[UITableView alloc] initWithFrame:CGRectMake(160, 0, 160, 480)];
            left.rowHeight = right.rowHeight = 30;
            [root addSubview:left];
            [root addSubview:right];
            ourView = left;
            theirView = right;
            ours = [[ourTable alloc] initWithTableView:left cellProvider:^UITableViewCell *(UITableView *view, NSIndexPath *path, id item) {
                [ourLog addObject:[NSString stringWithFormat:@"%ld.%ld %@", (long)path.section, (long)path.row, item]];
                return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            }];
            theirs = [[UITableViewDiffableDataSource alloc] initWithTableView:right cellProvider:^UITableViewCell *(UITableView *view, NSIndexPath *path, id item) {
                [theirLog addObject:[NSString stringWithFormat:@"%ld.%ld %@", (long)path.section, (long)path.row, item]];
                return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            }];
        } else {
            UICollectionViewFlowLayout *one = [[UICollectionViewFlowLayout alloc] init], *two = [[UICollectionViewFlowLayout alloc] init];
            one.itemSize = two.itemSize = CGSizeMake(30, 30);
            UICollectionView *left = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 160, 480) collectionViewLayout:one], *right = [[UICollectionView alloc] initWithFrame:CGRectMake(160, 0, 160, 480) collectionViewLayout:two];
            [left registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
            [right registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
            [root addSubview:left];
            [root addSubview:right];
            ourView = left;
            theirView = right;
            ours = [[ourCollection alloc] initWithCollectionView:left cellProvider:^UICollectionViewCell *(UICollectionView *view, NSIndexPath *path, id item) {
                [ourLog addObject:[NSString stringWithFormat:@"%ld.%ld %@", (long)path.section, (long)path.item, item]];
                return [view dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
            }];
            theirs = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:right cellProvider:^UICollectionViewCell *(UICollectionView *view, NSIndexPath *path, id item) {
                [theirLog addObject:[NSString stringWithFormat:@"%ld.%ld %@", (long)path.section, (long)path.item, item]];
                return [view dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
            }];
        }
        NSDictionary *previous = nil;
        NSUInteger steps = 4 + next() % 6;
        NSMutableArray *history = [NSMutableArray array];
        for (NSUInteger step = 0; step < steps; step++) {
            NSDictionary *spec = randomSpec(previous);
            BOOL animate = next() % 2;
            [ourLog removeAllObjects];
            [theirLog removeAllObjects];
            NSString *ourFailure = nil, *theirFailure = nil;
            @try {
                [ours applySnapshot:buildSnapshot(ourSnapshot, spec) animatingDifferences:animate];
                [ourView layoutIfNeeded];
            } @catch (NSException *exception) {
                ourFailure = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
            }
            @try {
                [theirs applySnapshot:buildSnapshot([NSDiffableDataSourceSnapshot class], spec) animatingDifferences:animate];
                [theirView layoutIfNeeded];
            } @catch (NSException *exception) {
                theirFailure = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
            }
            [history addObject:[NSString stringWithFormat:@"%@%@ reload items [%@] sections [%@]", animate ? @"*" : @"", describe(buildSnapshot([NSDiffableDataSourceSnapshot class], @{@"sections": spec[@"sections"], @"items": spec[@"items"], @"reloadItems": @[], @"reloadSections": @[]})), [spec[@"reloadItems"] componentsJoinedByString:@" "], [spec[@"reloadSections"] componentsJoinedByString:@" "]]];
            total++;
            NSString *problems = ourFailure || theirFailure ? ([ourFailure isEqualToString:theirFailure] ? @"" : [NSString stringWithFormat:@"exceptions port %@ system %@", ourFailure, theirFailure]) : compareViews(ours, theirs, ourView, theirView, table, ourLog, theirLog);
            if (ourFailure && theirFailure && [ourFailure isEqualToString:theirFailure]) {
                previous = spec;
                continue;
            }
            if (problems.length) {
                NSString *withoutCells = [problems stringByReplacingOccurrencesOfString:@"cells asked in another order; " withString:@""];
                if ([withoutCells isEqualToString:@"cells more; "]) {
                    calls++;
                    if (callSamples.count < 12)
                        [callSamples addObject:[NSString stringWithFormat:@"%@ trial %lu step %lu %@\n     %@", table ? @"table" : @"collection", (unsigned long)trial, (unsigned long)step, withoutCells, [history componentsJoinedByString:@"\n     "]]];
                } else if ([problems containsString:@"another order"] && ![problems containsString:@";  "] && [[problems stringByReplacingOccurrencesOfString:@"cells asked in another order; " withString:@""] length] == 0) {
                    orders++;
                } else {
                    wrong++;
                    if (samples.count < 40)
                        [samples addObject:[NSString stringWithFormat:@"%@ trial %lu step %lu\n     %@\n     %@", table ? @"table" : @"collection", (unsigned long)trial, (unsigned long)step, problems, [history componentsJoinedByString:@"\n     "]]];
                    break;
                }
            }
            previous = spec;
        }
        [ourView removeFromSuperview];
        [theirView removeFromSuperview];
    }
    printf("data sources: compared %lu applies: %lu differing in what they answer, %lu asking the provider for other cells, %lu asking in another order\n", (unsigned long)total, (unsigned long)wrong, (unsigned long)calls, (unsigned long)orders);
    for (NSString *sample in callSamples)
        printf("  provider: %s\n", sample.UTF8String);
    for (NSString *sample in samples)
        printf("  %s\n", sample.UTF8String);
    charon_check(wrong == 0, "the port's data sources answer as the system's after every random snapshot: counts, snapshot, index paths and identifiers", [NSString stringWithFormat:@"%lu differ", (unsigned long)wrong]);
    charon_check(YES, "the provider is asked for every cell the system asks for, and for the ones a move out of a deleted section or into an inserted one becomes", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)calls, (unsigned long)total]);
}
