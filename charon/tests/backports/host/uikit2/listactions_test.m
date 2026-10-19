#import "listops.h"
#import <objc/message.h>
#import <objc/runtime.h>

void charon_windowed_run(UIWindow *window);

static UIWindow *test_window;

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static SEL renamed(int side, NSString *getter)
{
    if (!side)
        return NSSelectorFromString(getter);
    NSString *tail = [[[getter substringToIndex:1] uppercaseString] stringByAppendingString:[getter substringFromIndex:1]];
    return NSSelectorFromString([@"charonHost" stringByAppendingString:tail]);
}

static NSString *items_of(id source)
{
    NSDiffableDataSourceSnapshot *snapshot = [source snapshot];
    return [snapshot.itemIdentifiers componentsJoinedByString:@","];
}

static UIControl *outline_control(UIView *cell)
{
    for (UIView *sub in cell.subviews)
        if ([sub isKindOfClass:[UIControl class]])
            return (UIControl *)sub;
    return nil;
}

static double chevron_angle(UIView *cell)
{
    UIControl *control = outline_control(cell);
    UIView *inner = control.subviews.firstObject;
    return inner ? round(atan2(inner.transform.b, inner.transform.a) * 100) / 100 : -9;
}

static NSString *rows_text(int side, UICollectionView *view, id source)
{
    NSMutableString *text = [NSMutableString string];
    NSInteger count = [view numberOfItemsInSection:0];
    for (NSInteger index = 0; index < count; index++) {
        NSIndexPath *path = [NSIndexPath indexPathForItem:index inSection:0];
        UICollectionViewCell *cell = [view cellForItemAtIndexPath:path];
        id state = ((id (*)(id, SEL))objc_msgSend)(cell, renamed(side, @"configurationState"));
        [text appendFormat:@"[%@ i%ld e%d r%g c%d] ", [source itemIdentifierForIndexPath:path], (long)[(UICollectionViewListCell *)cell indentationLevel], [state isExpanded], chevron_angle(cell), outline_control(cell) != nil];
    }
    return text;
}

static UICollectionView *list_view(int side, id *sourceOut, NSMutableArray *log, BOOL (^denyExpand)(id))
{
    Class configurationClass = named(side, @"UICollectionLayoutListConfiguration"), layoutClass = named(side, @"UICollectionViewCompositionalLayout"), cellClass = named(side, @"UICollectionViewListCell");
    id configuration = [[configurationClass alloc] initWithAppearance:UICollectionLayoutListAppearancePlain];
    id layout = [layoutClass layoutWithListConfiguration:configuration];
    UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) collectionViewLayout:layout];
    [view registerClass:cellClass forCellWithReuseIdentifier:@"c"];
    [test_window.rootViewController.view addSubview:view];
    __block id source;
    source = [[named(side, @"UICollectionViewDiffableDataSource") alloc] initWithCollectionView:view cellProvider:^UICollectionViewCell *(UICollectionView *v, NSIndexPath *path, id item) {
        UICollectionViewListCell *cell = [v dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
        // The plain name on both sides: -defaultContentConfiguration is the SDK's own member of
        // UICollectionViewListCell (UICollectionViewListCell.h:21), and the port's cell is a subclass of it, so
        // it answers the name it inherits. renamed() is for a selector a port CATEGORY adds, and this one is not
        // one of those: over the group's own objects only UITableViewCell and UITableViewHeaderFooterView
        // define the prefixed form, in @implementation UITableViewCell (CharonConfiguration) and
        // UITableViewHeaderFooterView (CharonConfiguration). Asking the port's cell for the prefixed name raised
        // -[CharonHostUICollectionViewListCell charonHostDefaultContentConfiguration]: unrecognized selector.
        // listcell_test.m:679 asks the same question of UICollectionViewCell and expects the same answer.
        id content = ((id (*)(id, SEL))objc_msgSend)(cell, @selector(defaultContentConfiguration));
        [content setText:item];
        ((void (*)(id, SEL, id))objc_msgSend)(cell, side ? NSSelectorFromString(@"charonHostSetContentConfiguration:") : NSSelectorFromString(@"setContentConfiguration:"), content);
        id ss = [source snapshotForSection:@"s"];
        BOOL parent = [ss containsItem:item] && [[ss snapshotOfParentItem:item] items].count;
        cell.accessories = parent ? @[[[named(side, @"UICellAccessoryOutlineDisclosure") alloc] init]] : @[];
        return cell;
    }];
    id handlers = [source sectionSnapshotHandlers];
    [handlers setShouldExpandItemHandler:^BOOL(id item) {
        [log addObject:[NSString stringWithFormat:@"shouldExpand %@ ds=%@ rows=%ld", item, items_of(source), (long)[view numberOfItemsInSection:0]]];
        return denyExpand ? !denyExpand(item) : YES;
    }];
    [handlers setWillExpandItemHandler:^(id item) {
        [log addObject:[NSString stringWithFormat:@"willExpand %@ ds=%@", item, items_of(source)]];
    }];
    [handlers setShouldCollapseItemHandler:^BOOL(id item) {
        [log addObject:[NSString stringWithFormat:@"shouldCollapse %@", item]];
        return YES;
    }];
    [handlers setWillCollapseItemHandler:^(id item) {
        [log addObject:[NSString stringWithFormat:@"willCollapse %@ ds=%@", item, items_of(source)]];
    }];
    [handlers setSnapshotForExpandingParentItemHandler:^id(id item, id snapshot) {
        [log addObject:[NSString stringWithFormat:@"snapshotFor %@ items=%@ visible=%@ ds=%@", item, [[snapshot items] componentsJoinedByString:@","], [[snapshot visibleItems] componentsJoinedByString:@","], items_of(source)]];
        if ([item isEqual:@"a2"]) {
            id replaced = [[named(side, @"NSDiffableDataSourceSectionSnapshot") alloc] init];
            [replaced appendItems:@[@"n1", @"n2"]];
            return replaced;
        }
        return snapshot;
    }];
    *sourceOut = source;
    return view;
}

static void run_outline(void)
{
    NSMutableArray *answers[2] = {[NSMutableArray array], [NSMutableArray array]};
    for (int side = 0; side < 2; side++) {
        NSMutableArray *out = answers[side], *log = [NSMutableArray array];
        id source = nil;
        __block BOOL deny = NO;
        UICollectionView *view = list_view(side, &source, log, ^BOOL(id item) { return deny && [item isEqual:@"B"]; });
        id snapshot = [[named(side, @"NSDiffableDataSourceSectionSnapshot") alloc] init];
        [snapshot appendItems:@[@"A", @"B", @"C"]];
        [snapshot appendItems:@[@"a1", @"a2"] intoParentItem:@"A"];
        [snapshot appendItems:@[@"a2x"] intoParentItem:@"a2"];
        [snapshot appendItems:@[@"b1"] intoParentItem:@"B"];
        [snapshot appendItems:@[@"c1", @"c2"] intoParentItem:@"C"];
        [snapshot expandItems:@[@"C"]];
        [source applySnapshot:snapshot toSection:@"s" animatingDifferences:NO];
        spin(0.3);
        [view layoutIfNeeded];
        [out addObject:[NSString stringWithFormat:@"initial %@ | %@", items_of(source), rows_text(side, view, source)]];
        void (^toggle)(NSString *, NSString *) = ^(NSString *item, NSString *name) {
            [log removeAllObjects];
            NSIndexPath *path = [source indexPathForItemIdentifier:item];
            UICollectionViewCell *cell = [view cellForItemAtIndexPath:path];
            UIControl *control = outline_control(cell);
            [control sendActionsForControlEvents:side ? UIControlEventTouchUpInside : UIControlEventPrimaryActionTriggered];
            spin(0.6);
            [view layoutIfNeeded];
            [out addObject:[NSString stringWithFormat:@"%@ log=%@ | ds=%@ rows=%ld | %@", name, [log componentsJoinedByString:@"; "], items_of(source), (long)[view numberOfItemsInSection:0], rows_text(side, view, source)]];
            [out addObject:[NSString stringWithFormat:@"%@ stored=%@ expanded=%@", name, [[[source snapshotForSection:@"s"] items] componentsJoinedByString:@","], [[[source snapshotForSection:@"s"] expandedItems] componentsJoinedByString:@","]]];
        };
        toggle(@"A", @"expand A");
        toggle(@"a2", @"expand a2");
        toggle(@"A", @"collapse A");
        deny = YES;
        toggle(@"B", @"denied B");
        deny = NO;
        toggle(@"B", @"expand B");
        toggle(@"C", @"collapse C");
        [view removeFromSuperview];
    }
    for (NSUInteger index = 0; index < answers[0].count; index++)
        same([NSString stringWithFormat:@"outline step %lu", (unsigned long)index], answers[0][index], answers[1][index]);
}

static NSString *transaction_text(NSDiffableDataSourceTransaction *transaction)
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"initial=%@ final=%@ diff=[", [transaction.initialSnapshot.itemIdentifiers componentsJoinedByString:@","], [transaction.finalSnapshot.itemIdentifiers componentsJoinedByString:@","]];
    for (NSOrderedCollectionChange *change in transaction.difference)
        [text appendFormat:@"%@ %ld %@ %ld; ", change.changeType == NSCollectionChangeInsert ? @"ins" : @"rem", (long)change.index, change.object, (long)change.associatedIndex];
    [text appendString:@"]"];
    for (NSDiffableDataSourceSectionTransaction *section in transaction.sectionTransactions)
        [text appendFormat:@" {%@ %@ > %@}", section.sectionIdentifier, [section.initialSnapshot.items componentsJoinedByString:@","], [section.finalSnapshot.items componentsJoinedByString:@","]];
    return text;
}

static void run_reorder(void)
{
    NSMutableArray *answers[2] = {[NSMutableArray array], [NSMutableArray array]};
    for (int side = 0; side < 2; side++) {
        NSMutableArray *out = answers[side], *log = [NSMutableArray array];
        UICollectionViewCompositionalLayout *layout = [named(side, @"UICollectionViewCompositionalLayout") layoutWithListConfiguration:[[named(side, @"UICollectionLayoutListConfiguration") alloc] initWithAppearance:UICollectionLayoutListAppearancePlain]];
        UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) collectionViewLayout:layout];
        [view registerClass:named(side, @"UICollectionViewListCell") forCellWithReuseIdentifier:@"c"];
        [test_window.rootViewController.view addSubview:view];
        id source = [[named(side, @"UICollectionViewDiffableDataSource") alloc] initWithCollectionView:view cellProvider:^UICollectionViewCell *(UICollectionView *v, NSIndexPath *path, id item) {
            return [v dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:path];
        }];
        id snapshot = [[named(side, @"NSDiffableDataSourceSnapshot") alloc] init];
        [snapshot appendSectionsWithIdentifiers:@[@"s1", @"s2"]];
        [snapshot appendItemsWithIdentifiers:@[@"a", @"b", @"c", @"d"] intoSectionWithIdentifier:@"s1"];
        [snapshot appendItemsWithIdentifiers:@[@"x", @"y", @"z"] intoSectionWithIdentifier:@"s2"];
        [source applySnapshot:snapshot animatingDifferences:NO];
        spin(0.3);
        [view layoutIfNeeded];
        id handlers = [source reorderingHandlers];
        [handlers setCanReorderItemHandler:^BOOL(id item) {
            [log addObject:[NSString stringWithFormat:@"can %@", item]];
            return ![item isEqual:@"d"];
        }];
        [handlers setWillReorderHandler:^(id transaction) {
            [log addObject:[NSString stringWithFormat:@"will %@ ds=%@", transaction_text(transaction), items_of(source)]];
        }];
        [handlers setDidReorderHandler:^(id transaction) {
            [log addObject:[NSString stringWithFormat:@"did %@ ds=%@", transaction_text(transaction), items_of(source)]];
        }];
        void (^drag)(NSString *, NSString *, BOOL) = ^(NSString *item, NSString *over, BOOL cancel) {
            [log removeAllObjects];
            NSIndexPath *from = [source indexPathForItemIdentifier:item];
            BOOL began = ((BOOL (*)(id, SEL, id))objc_msgSend)(view, renamed(side, @"beginInteractiveMovementForItemAtIndexPath:"), from);
            [log addObject:[NSString stringWithFormat:@"began %d", began]];
            if (began) {
                UICollectionViewCell *target = [view cellForItemAtIndexPath:[source indexPathForItemIdentifier:over]];
                ((void (*)(id, SEL, CGPoint))objc_msgSend)(view, renamed(side, @"updateInteractiveMovementTargetPosition:"), target.center);
                spin(0.4);
                [log addObject:[NSString stringWithFormat:@"during ds=%@", items_of(source)]];
                ((void (*)(id, SEL))objc_msgSend)(view, renamed(side, cancel ? @"cancelInteractiveMovement" : @"endInteractiveMovement"));
                spin(0.5);
                [view layoutIfNeeded];
            }
            NSMutableString *order = [NSMutableString string];
            for (NSInteger section = 0; section < 2; section++)
                [order appendFormat:@"%ld ", (long)[view numberOfItemsInSection:section]];
            [out addObject:[NSString stringWithFormat:@"%@ over %@ cancel=%d: %@ | ds=%@ rows=%@", item, over, cancel, [log componentsJoinedByString:@"; "], items_of(source), order]];
        };
        drag(@"a", @"c", NO);
        drag(@"d", @"a", NO);
        drag(@"y", @"b", NO);
        drag(@"b", @"z", NO);
        drag(@"c", @"a", YES);
        drag(@"x", @"y", NO);
        [view removeFromSuperview];
    }
    for (NSUInteger index = 0; index < answers[0].count; index++)
        same([NSString stringWithFormat:@"reorder step %lu", (unsigned long)index], answers[0][index], answers[1][index]);
}

void charon_windowed_run(UIWindow *window)
{
    test_window = window;
    run_outline();
    run_reorder();
}
