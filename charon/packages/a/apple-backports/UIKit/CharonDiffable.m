#import "CharonDiffable.h"

static void charon_script(NSArray *old, NSArray *current, NSMutableIndexSet *removed, NSMutableIndexSet *inserted)
{
    NSMapTable *codes = [NSMapTable strongToStrongObjectsMapTable];
    NSInteger n = (NSInteger)old.count, m = (NSInteger)current.count, limit = n + m;
    NSInteger *from = malloc(sizeof(NSInteger) * (size_t)(n + 1)), *to = malloc(sizeof(NSInteger) * (size_t)(m + 1));
    for (NSInteger index = 0; index < n; index++) {
        NSNumber *code = [codes objectForKey:old[(NSUInteger)index]];
        if (!code) {
            code = @(codes.count);
            [codes setObject:code forKey:old[(NSUInteger)index]];
        }
        from[index] = code.integerValue;
    }
    for (NSInteger index = 0; index < m; index++) {
        NSNumber *code = [codes objectForKey:current[(NSUInteger)index]];
        to[index] = code ? code.integerValue : -1 - index;
    }
    NSInteger *row = calloc((size_t)(2 * limit + 3), sizeof(NSInteger)), *middle = row + limit + 1;
    NSInteger **trace = calloc((size_t)limit + 2, sizeof(NSInteger *));
    NSInteger found = -1;
    for (NSInteger d = 0; d <= limit && found < 0; d++) {
        trace[d] = malloc(sizeof(NSInteger) * (size_t)(d + 1));
        for (NSInteger k = 1 - d, slot = 0; k <= d - 1; k += 2)
            trace[d][slot++] = middle[k];
        for (NSInteger k = -d; k <= d; k += 2) {
            BOOL down = k == -d || (k != d && middle[k - 1] < middle[k + 1]);
            NSInteger x = down ? middle[k + 1] : middle[k - 1] + 1, y = x - k;
            while (x < n && y < m && from[x] == to[y]) {
                x++;
                y++;
            }
            middle[k] = x;
            if (x >= n && y >= m) {
                found = d;
                break;
            }
        }
    }
    NSInteger x = n, y = m;
    for (NSInteger d = found; d > 0; d--) {
        NSInteger *before = trace[d], k = x - y;
        BOOL down = k == -d || (k != d && before[(k - 1 + d - 1) / 2] < before[(k + 1 + d - 1) / 2]);
        NSInteger previousK = down ? k + 1 : k - 1, previousX = before[(previousK + d - 1) / 2], previousY = previousX - previousK;
        if (down)
            [inserted addIndex:(NSUInteger)previousY];
        else
            [removed addIndex:(NSUInteger)previousX];
        x = previousX;
        y = previousY;
    }
    for (NSInteger d = 0; d <= found; d++)
        free(trace[d]);
    free(trace);
    free(row);
    free(from);
    free(to);
}

static NSIndexPath *charon_path(NSUInteger section, NSUInteger item)
{
    return [NSIndexPath indexPathForRow:(NSInteger)item inSection:(NSInteger)section];
}

NSDictionary *charon_diffable_changes(NSDiffableDataSourceSnapshot *old, NSDiffableDataSourceSnapshot *current, BOOL table)
{
    NSArray *oldSections = [old charon_sections], *newSections = [current charon_sections];
    NSMapTable *oldIndex = [NSMapTable strongToStrongObjectsMapTable], *newIndex = [NSMapTable strongToStrongObjectsMapTable];
    for (NSUInteger index = 0; index < oldSections.count; index++)
        [oldIndex setObject:@(index) forKey:oldSections[index]];
    for (NSUInteger index = 0; index < newSections.count; index++)
        [newIndex setObject:@(index) forKey:newSections[index]];
    NSMutableIndexSet *removedSections = [NSMutableIndexSet indexSet], *insertedSections = [NSMutableIndexSet indexSet];
    charon_script(oldSections, newSections, removedSections, insertedSections);
    NSMutableIndexSet *deleteSections = [NSMutableIndexSet indexSet], *insertSections = [NSMutableIndexSet indexSet];
    NSMutableArray *moveSections = [NSMutableArray array];
    for (NSUInteger index = 0; index < oldSections.count; index++)
        if (![newIndex objectForKey:oldSections[index]])
            [deleteSections addIndex:index];
    for (NSUInteger index = 0; index < newSections.count; index++) {
        NSNumber *before = [oldIndex objectForKey:newSections[index]];
        if (!before)
            [insertSections addIndex:index];
        else if ([removedSections containsIndex:before.unsignedIntegerValue] && [insertedSections containsIndex:index])
            [moveSections addObject:@[before, @(index)]];
    }
    NSMapTable *oldPaths = [NSMapTable strongToStrongObjectsMapTable], *newPaths = [NSMapTable strongToStrongObjectsMapTable];
    for (NSUInteger section = 0; section < oldSections.count; section++) {
        NSArray *items = [old charon_itemsInSectionAtIndex:section];
        for (NSUInteger item = 0; item < items.count; item++)
            [oldPaths setObject:charon_path(section, item) forKey:items[item]];
    }
    for (NSUInteger section = 0; section < newSections.count; section++) {
        NSArray *items = [current charon_itemsInSectionAtIndex:section];
        for (NSUInteger item = 0; item < items.count; item++)
            [newPaths setObject:charon_path(section, item) forKey:items[item]];
    }
    NSMutableArray *deleteItems = [NSMutableArray array], *insertItems = [NSMutableArray array], *moveItems = [NSMutableArray array];
    __block BOOL fallback = NO;
    for (NSUInteger oldSection = 0; oldSection < oldSections.count; oldSection++) {
        NSArray *oldItems = [old charon_itemsInSectionAtIndex:oldSection];
        NSNumber *counterpart = [newIndex objectForKey:oldSections[oldSection]];
        NSArray *newItems = counterpart ? [current charon_itemsInSectionAtIndex:counterpart.unsignedIntegerValue] : @[];
        NSMutableIndexSet *removed = [NSMutableIndexSet indexSet], *inserted = [NSMutableIndexSet indexSet];
        if (counterpart)
            charon_script(oldItems, newItems, removed, inserted);
        else
            [removed addIndexesInRange:NSMakeRange(0, oldItems.count)];
        [removed enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
            NSIndexPath *target = [newPaths objectForKey:oldItems[index]], *source = charon_path(oldSection, index);
            if (!counterpart) {
                if (target)
                    fallback = YES;
                return;
            }
            if (!target) {
                [deleteItems addObject:source];
                return;
            }
            if ([oldIndex objectForKey:newSections[(NSUInteger)target.section]])
                [moveItems addObject:@[source, target]];
            else {
                fallback = YES;
                [deleteItems addObject:source];
            }
        }];
    }
    for (NSUInteger newSection = 0; newSection < newSections.count; newSection++) {
        NSArray *newItems = [current charon_itemsInSectionAtIndex:newSection];
        NSNumber *counterpart = [oldIndex objectForKey:newSections[newSection]];
        if (!counterpart)
            continue;
        for (NSUInteger index = 0; index < newItems.count; index++) {
            NSIndexPath *source = [oldPaths objectForKey:newItems[index]];
            if (source && [newIndex objectForKey:oldSections[(NSUInteger)source.section]])
                continue;
            if (source)
                fallback = YES;
            [insertItems addObject:charon_path(newSection, index)];
        }
    }
    if (table && moveSections.count > 1)
        fallback = YES;
    BOOL itemChanges = deleteItems.count || insertItems.count || moveItems.count;
    if (itemChanges && (deleteSections.count || insertSections.count || moveSections.count))
        fallback = YES;
    for (NSArray *pair in moveItems) {
        NSNumber *counterpart = [newIndex objectForKey:oldSections[(NSUInteger)[pair[0] section]]];
        if (!counterpart || counterpart.unsignedIntegerValue != (NSUInteger)[pair[1] section])
            fallback = YES;
    }
    for (NSUInteger newSection = 0; newSection < newSections.count && !fallback; newSection++) {
        NSNumber *before = [oldIndex objectForKey:newSections[newSection]];
        if (!before)
            continue;
        NSInteger count = (NSInteger)[old charon_countInSectionAtIndex:before.unsignedIntegerValue];
        for (NSIndexPath *path in deleteItems)
            count -= (NSUInteger)path.section == before.unsignedIntegerValue;
        for (NSArray *pair in moveItems) {
            count -= (NSUInteger)[pair[0] section] == before.unsignedIntegerValue;
            count += (NSUInteger)[pair[1] section] == newSection;
        }
        for (NSIndexPath *path in insertItems)
            count += (NSUInteger)path.section == newSection;
        if (count != (NSInteger)[current charon_countInSectionAtIndex:newSection])
            fallback = YES;
    }
    NSMutableIndexSet *reloadSections = [NSMutableIndexSet indexSet];
    NSMutableArray *reloadItems = [NSMutableArray array];
    for (id section in [current charon_reloadedSections]) {
        NSNumber *index = [newIndex objectForKey:section];
        if (index)
            [reloadSections addIndex:index.unsignedIntegerValue];
    }
    for (id item in [current charon_reloadedItems]) {
        NSIndexPath *path = [newPaths objectForKey:item];
        if (path)
            [reloadItems addObject:path];
    }
    return @{@"deleteSections": deleteSections, @"insertSections": insertSections, @"moveSections": moveSections, @"deleteItems": deleteItems, @"insertItems": insertItems, @"moveItems": moveItems, @"reloadSections": reloadSections, @"reloadItems": reloadItems, @"fallback": @(fallback)};
}

NSString *charon_diffable_source_description(NSDiffableDataSourceSnapshot *snapshot)
{
    NSMutableArray *counts = [NSMutableArray array];
    for (NSUInteger index = 0; index < snapshot.numberOfSections; index++)
        [counts addObject:[NSString stringWithFormat:@"%lu", (unsigned long)[snapshot charon_countInSectionAtIndex:index]]];
    NSUInteger sections = (NSUInteger)snapshot.numberOfSections;
    return [NSString stringWithFormat:@"<__UIDiffableDataSource %p: sectionCounts=<_UIDataSourceSnapshotter: %p; %lu section%@ with item counts: [%@] >; sections=[%p]; identifiers=[%p]>", (__bridge void *)snapshot, (__bridge void *)counts, (unsigned long)sections, sections == 1 ? @"" : @"s", [counts componentsJoinedByString:@", "], (__bridge void *)[snapshot charon_sections], (__bridge void *)[snapshot itemIdentifiers]];
}

void charon_diffable_finish(void (^completion)(void))
{
    if (!completion)
        return;
    void (^block)(void) = [completion copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}
