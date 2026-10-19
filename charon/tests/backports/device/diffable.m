#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"
#import "diffable-cases.h"
#import "diffable-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

static NSDiffableDataSourceSnapshot *snapshot_from(NSString *spec, NSString *reloadItems, NSString *reloadSections)
{
    NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    for (NSString *part in [spec componentsSeparatedByString:@";"]) {
        if (!part.length)
            continue;
        NSArray *pair = [part componentsSeparatedByString:@":"];
        [snapshot appendSectionsWithIdentifiers:@[pair[0]]];
        if ([pair[1] length])
            [snapshot appendItemsWithIdentifiers:[pair[1] componentsSeparatedByString:@","] intoSectionWithIdentifier:pair[0]];
    }
    if (reloadItems.length)
        [snapshot reloadItemsWithIdentifiers:[reloadItems componentsSeparatedByString:@","]];
    if (reloadSections.length)
        [snapshot reloadSectionsWithIdentifiers:[reloadSections componentsSeparatedByString:@","]];
    return snapshot;
}

@interface CharonDiffableDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonDiffableDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"diffable.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)runAndReport
{
    @try {
        [self run];
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"diffable.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)settle
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

- (NSArray *)askedFor:(void (^)(UIView *view, id source, NSMutableArray *log))body table:(BOOL)table from:(NSString *)from
{
    NSMutableArray *log = [NSMutableArray array];
    UIView *root = self.window.rootViewController.view;
    UIView *view;
    id source;
    if (table) {
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
        tableView.rowHeight = 30;
        [root addSubview:tableView];
        view = tableView;
        source = [[UITableViewDiffableDataSource alloc] initWithTableView:tableView cellProvider:^UITableViewCell *(UITableView *tv, NSIndexPath *path, id item) {
            [log addObject:[NSString stringWithFormat:@"%ld.%ld%@", (long)path.section, (long)path.row, item]];
            return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        }];
    } else {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(30, 30);
        UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 400) collectionViewLayout:layout];
        [collection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
        [root addSubview:collection];
        view = collection;
        source = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:collection cellProvider:^UICollectionViewCell *(UICollectionView *cv, NSIndexPath *path, id item) {
            [log addObject:[NSString stringWithFormat:@"%ld.%ld%@", (long)path.section, (long)path.item, item]];
            return [cv dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
        }];
    }
    [source applySnapshot:snapshot_from(from, nil, nil) animatingDifferences:NO];
    [view layoutIfNeeded];
    [self settle];
    [log removeAllObjects];
    body(view, source, log);
    [view layoutIfNeeded];
    [self settle];
    NSArray *asked = [log copy];
    [view removeFromSuperview];
    return asked;
}

- (void)run
{
    Dl_info info;
    for (Class cls in @[[NSDiffableDataSourceSnapshot class], [NSDiffableDataSourceSectionSnapshot class], [UICollectionViewDiffableDataSource class], [UITableViewDiffableDataSource class]])
        charon_check(dladdr((__bridge const void *)cls, &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libUIKitBackports.dylib"), [NSString stringWithFormat:@"%@ comes from the backports library", NSStringFromClass(cls)].UTF8String, @"dladdr");

    CHECK(sizeof df_expectations / sizeof df_expectations[0] == DIFFABLE_CASE_COUNT, "there is one recorded fingerprint for every case");
    size_t wrong = 0;
    for (size_t index = 0; index < DIFFABLE_CASE_COUNT; index++) {
        NSString *answer = df_answer(index);
        if (df_hash(answer) != df_expectations[index]) {
            wrong++;
            if (wrong <= 3)
                charon_check(NO, [NSString stringWithFormat:@"case %zu answers as the system does", index].UTF8String, answer);
        }
    }
    CHECK(wrong == 0, "all recorded snapshot and section snapshot cases answer as the system does");

    for (NSString *name in @[@"reloadedSectionIdentifiers", @"reloadedItemIdentifiers", @"reconfiguredItemIdentifiers", @"reconfigureItemsWithIdentifiers:"])
        CHECK(![NSDiffableDataSourceSnapshot instancesRespondToSelector:NSSelectorFromString(name)], "a member of iOS 15 is not answered by accident");
    for (NSString *name in @[@"applySnapshotUsingReloadData:", @"applySnapshotUsingReloadData:completion:", @"sectionIdentifierForIndex:", @"indexForSectionIdentifier:"])
        CHECK(![UICollectionViewDiffableDataSource instancesRespondToSelector:NSSelectorFromString(name)] && ![UITableViewDiffableDataSource instancesRespondToSelector:NSSelectorFromString(name)], "the data sources do not answer the reload data members of iOS 15");
    CHECK([UICollectionViewDiffableDataSource instancesRespondToSelector:@selector(applySnapshot:toSection:animatingDifferences:)] && [UICollectionViewDiffableDataSource instancesRespondToSelector:@selector(snapshotForSection:)], "the collection data source has the section snapshot members of iOS 14");
    CHECK(![UITableViewDiffableDataSource instancesRespondToSelector:@selector(snapshotForSection:)], "the table data source has none");
    CHECK(NSClassFromString(@"NSDiffableDataSourceTransaction") == Nil && NSClassFromString(@"NSDiffableDataSourceSectionTransaction") == Nil, "the transaction classes are not there");

    NSArray *scenarios = @[
        @[@"A:x,y,z", @"A:x,y,z", @"y", @"", @[@"0.1y"]],
        @[@"A:x,y,z", @"A:x,y,z", @"", @"A", @[@"0.0x", @"0.1y", @"0.2z"]],
        @[@"A:x,y,z", @"A:z,x,y", @"", @"", @[]],
        @[@"A:x,y,z", @"A:z,x,y", @"z", @"", @[@"0.0z"]],
        @[@"A:x,y,z", @"A:x,y,z,w", @"", @"", @[@"0.3w"]],
        @[@"A:x,y,z", @"A:x,y,z,w", @"w", @"", @[@"0.3w", @"0.3w"]],
        @[@"A:x,y,z", @"A:x,z", @"", @"", @[]],
        @[@"A:x,y,z;B:u", @"A:x,z;B:u,y", @"", @"", @[@"0.0x", @"0.1z", @"1.0u", @"1.1y"]],
        @[@"A:x,y,z;B:u", @"B:u;A:x,y,z", @"", @"", @[]],
        @[@"A:x,y,z;B:u", @"A:x,y,z;B:u;C:w", @"", @"", @[@"2.0w"]],
        @[@"A:x,y,z;B:u", @"B:u,q;A:x,y,z", @"", @"", @[@"0.0u", @"0.1q", @"1.0x", @"1.1y", @"1.2z"]],
    ];
    for (NSArray *scenario in scenarios)
        for (int table = 0; table < 2; table++) {
            NSArray *asked = [self askedFor:^(UIView *view, id source, NSMutableArray *log) {
                [source applySnapshot:snapshot_from(scenario[1], scenario[2], scenario[3]) animatingDifferences:NO];
            } table:table from:scenario[0]];
            NSArray *sorted = [asked sortedArrayUsingSelector:@selector(compare:)], *expected = [scenario[4] sortedArrayUsingSelector:@selector(compare:)];
            NSString *name = [NSString stringWithFormat:@"%@ %@ -> %@ reloading [%@|%@] asks the provider for %@", table ? @"table" : @"collection", scenario[0], scenario[1], scenario[2], scenario[3], [scenario[4] componentsJoinedByString:@" "]];
            charon_check([sorted isEqual:expected], name.UTF8String, [asked componentsJoinedByString:@" "]);
        }

    for (int table = 0; table < 2; table++) {
        __block NSString *failure = nil;
        [self askedFor:^(UIView *view, id source, NSMutableArray *log) {
            uint64_t state = 0x1234ABCDull + (uint64_t)table;
            NSMutableArray *sections = nil;
            for (int step = 0; step < 40; step++) {
                sections = [NSMutableArray arrayWithArray:@[@"A", @"B", @"C", @"D"]];
                for (NSUInteger index = sections.count; index > 1; index--)
                    [sections exchangeObjectAtIndex:index - 1 withObjectAtIndex:df_draw(&state) % index];
                sections = [[sections subarrayWithRange:NSMakeRange(0, df_draw(&state) % 5)] mutableCopy];
                NSMutableArray *items = [NSMutableArray array];
                for (int index = 0; index < 8; index++)
                    if (df_draw(&state) % 4)
                        [items addObject:[NSString stringWithFormat:@"i%d", index]];
                for (NSUInteger index = items.count; index > 1; index--)
                    [items exchangeObjectAtIndex:index - 1 withObjectAtIndex:df_draw(&state) % index];
                NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
                [snapshot appendSectionsWithIdentifiers:sections];
                if (!sections.count)
                    items = [NSMutableArray array];
                for (id item in items)
                    [snapshot appendItemsWithIdentifiers:@[item] intoSectionWithIdentifier:sections[df_draw(&state) % sections.count]];
                if (df_draw(&state) % 4 == 0 && items.count)
                    [snapshot reloadItemsWithIdentifiers:@[items[0]]];
                BOOL animate = df_draw(&state) % 2;
                @try {
                    [source applySnapshot:snapshot animatingDifferences:animate];
                    [view layoutIfNeeded];
                } @catch (NSException *exception) {
                    failure = [NSString stringWithFormat:@"step %d: %@: %@", step, exception.name, exception.reason];
                    return;
                }
                NSInteger count = table ? [(UITableView *)view numberOfSections] : [(UICollectionView *)view numberOfSections];
                if (count != snapshot.numberOfSections) {
                    failure = [NSString stringWithFormat:@"step %d: %ld sections, not %ld", step, (long)count, (long)snapshot.numberOfSections];
                    return;
                }
                for (NSInteger index = 0; index < count; index++) {
                    NSInteger rows = table ? [(UITableView *)view numberOfRowsInSection:index] : [(UICollectionView *)view numberOfItemsInSection:index];
                    if (rows != [snapshot numberOfItemsInSection:snapshot.sectionIdentifiers[(NSUInteger)index]]) {
                        failure = [NSString stringWithFormat:@"step %d: section %ld has %ld items", step, (long)index, (long)rows];
                        return;
                    }
                }
                for (id item in items) {
                    NSIndexPath *path = [source indexPathForItemIdentifier:item];
                    if (!path || ![[source itemIdentifierForIndexPath:path] isEqual:item] || [snapshot indexOfItemIdentifier:item] == NSNotFound) {
                        failure = [NSString stringWithFormat:@"step %d: %@ is at %@", step, item, path];
                        return;
                    }
                }
                if (![[[source snapshot] itemIdentifiers] isEqual:snapshot.itemIdentifiers]) {
                    failure = [NSString stringWithFormat:@"step %d: the snapshot is not the one applied", step];
                    return;
                }
            }
        } table:table from:@"A:seed"];
        CHECK(failure == nil, table ? "forty random snapshots applied to a table view leave it as the snapshot says" : "forty random snapshots applied to a collection view leave it as the snapshot says");
        if (failure)
            printf("  %s\n", failure.UTF8String);
    }

    {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(30, 30);
        UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 400) collectionViewLayout:layout];
        [collection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
        [self.window.rootViewController.view addSubview:collection];
        UICollectionViewDiffableDataSource *source = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:collection cellProvider:^UICollectionViewCell *(UICollectionView *cv, NSIndexPath *path, id item) {
            return [cv dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
        }];
        CHECK(collection.dataSource == source, "creating the data source makes it the view's data source");
        NSDiffableDataSourceSnapshot *base = snapshot_from(@"S1:;S2:p,q", nil, nil);
        [source applySnapshot:base animatingDifferences:NO];
        NSDiffableDataSourceSectionSnapshot *tree = [[NSDiffableDataSourceSectionSnapshot alloc] init];
        [tree appendItems:@[@"a", @"b", @"c"]];
        [tree appendItems:@[@"a1", @"a2"] intoParentItem:@"a"];
        [source applySnapshot:tree toSection:@"S1" animatingDifferences:NO];
        [collection layoutIfNeeded];
        CHECK_EQUAL([[source snapshot] itemIdentifiers], (@[@"a", @"b", @"c", @"p", @"q"]), "a section snapshot puts its visible items into its section");
        [tree expandItems:@[@"a"]];
        [source applySnapshot:tree toSection:@"S1" animatingDifferences:NO];
        [collection layoutIfNeeded];
        CHECK_EQUAL([[source snapshot] itemIdentifiers], (@[@"a", @"a1", @"a2", @"b", @"c", @"p", @"q"]), "and expanding an item shows its children");
        NSDiffableDataSourceSectionSnapshot *back = [source snapshotForSection:@"S1"];
        CHECK([back isExpanded:@"a"] && [back.items isEqual:tree.items], "the section snapshot is given back with its hierarchy and its expanded state");
        CHECK([[source snapshotForSection:@"S2"].rootItems isEqual:(@[@"p", @"q"])] && [[source snapshotForSection:@"none"].items count] == 0, "a section with plain items is given as roots, an unknown one as an empty snapshot");
        [source setReorderingHandlers:[[UICollectionViewDiffableDataSourceReorderingHandlers alloc] init]];
        CHECK([source reorderingHandlers] != nil && [source sectionSnapshotHandlers] != nil, "the handlers are kept");
        [collection removeFromSuperview];
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonDiffableDelegate");
    }
}
