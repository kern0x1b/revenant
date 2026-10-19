#import "CharonOrderedCollections.h"

@implementation NSArray (CharonDifference)

- (NSOrderedCollectionDifference *)charon_differenceFromArray:(NSArray *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(id, id))block
{
    if (!other)
        [NSException raise:NSInvalidArgumentException format:@"Cannot diff nil parameter"];
    if (!block)
        [NSException raise:NSInvalidArgumentException format:@"Equivalence test is nil"];
    NSArray *old = other, *current = self;
    NSInteger n = (NSInteger)old.count, m = (NSInteger)current.count, limit = n + m;
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
            while (x < n && y < m && block(old[x], current[y])) {
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
    NSMutableArray *removals = [NSMutableArray array], *insertions = [NSMutableArray array];
    NSInteger x = n, y = m;
    for (NSInteger d = found; d > 0; d--) {
        NSInteger *before = trace[d], k = x - y;
        BOOL down = k == -d || (k != d && before[(k - 1 + d - 1) / 2] < before[(k + 1 + d - 1) / 2]);
        NSInteger previousK = down ? k + 1 : k - 1, previousX = before[(previousK + d - 1) / 2], previousY = previousX - previousK;
        if (down)
            [insertions addObject:@(previousY)];
        else
            [removals addObject:@(previousX)];
        x = previousX;
        y = previousY;
    }
    for (NSInteger d = 0; d <= found; d++)
        free(trace[d]);
    free(trace);
    free(row);
    return [self charon_differenceFromArray:old removed:[[removals reverseObjectEnumerator] allObjects] inserted:[[insertions reverseObjectEnumerator] allObjects] options:options];
}

- (NSOrderedCollectionDifference *)charon_differenceFromArray:(NSArray *)old removed:(NSArray *)removals inserted:(NSArray *)insertions options:(NSOrderedCollectionDifferenceCalculationOptions)options
{
    NSArray *current = self;
    NSMutableArray *removalChanges = [NSMutableArray arrayWithCapacity:removals.count], *insertionChanges = [NSMutableArray arrayWithCapacity:insertions.count];
    NSMapTable *removed = nil, *inserted = nil;
    if (options & NSOrderedCollectionDifferenceCalculationInferMoves) {
        removed = [NSMapTable strongToStrongObjectsMapTable];
        inserted = [NSMapTable strongToStrongObjectsMapTable];
        for (NSNumber *index in removals)
            [removed setObject:@([[removed objectForKey:old[index.unsignedIntegerValue]] unsignedIntegerValue] + 1) forKey:old[index.unsignedIntegerValue]];
        for (NSNumber *index in insertions)
            [inserted setObject:@([[inserted objectForKey:current[index.unsignedIntegerValue]] unsignedIntegerValue] + 1) forKey:current[index.unsignedIntegerValue]];
    }
    NSMapTable *removedAt = [NSMapTable strongToStrongObjectsMapTable], *insertedAt = [NSMapTable strongToStrongObjectsMapTable];
    if (removed) {
        for (NSNumber *index in removals)
            [removedAt setObject:index forKey:old[index.unsignedIntegerValue]];
        for (NSNumber *index in insertions)
            [insertedAt setObject:index forKey:current[index.unsignedIntegerValue]];
    }
    for (NSNumber *number in removals) {
        NSUInteger index = number.unsignedIntegerValue, link = NSNotFound;
        id object = old[index];
        if (removed && [[removed objectForKey:object] unsignedIntegerValue] == 1 && [[inserted objectForKey:object] unsignedIntegerValue] == 1)
            link = [[insertedAt objectForKey:object] unsignedIntegerValue];
        [removalChanges addObject:[NSOrderedCollectionChange changeWithObject:(options & NSOrderedCollectionDifferenceCalculationOmitRemovedObjects) ? nil : object type:NSCollectionChangeRemove index:index associatedIndex:link]];
    }
    for (NSNumber *number in insertions) {
        NSUInteger index = number.unsignedIntegerValue, link = NSNotFound;
        id object = current[index];
        if (removed && [[removed objectForKey:object] unsignedIntegerValue] == 1 && [[inserted objectForKey:object] unsignedIntegerValue] == 1)
            link = [[removedAt objectForKey:object] unsignedIntegerValue];
        [insertionChanges addObject:[NSOrderedCollectionChange changeWithObject:(options & NSOrderedCollectionDifferenceCalculationOmitInsertedObjects) ? nil : object type:NSCollectionChangeInsert index:index associatedIndex:link]];
    }
    return [[NSOrderedCollectionDifference alloc] charon_initWithInsertions:insertionChanges removals:removalChanges];
}

- (NSOrderedCollectionDifference *)differenceFromArray:(NSArray *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(id, id))block
{
    if (!other)
        [NSException raise:NSInvalidArgumentException format:@"Cannot diff nil parameter"];
    if (options & NSOrderedCollectionDifferenceCalculationInferMoves)
        [NSException raise:NSInvalidArgumentException format:@"Inferring moves is not supported when using a custom equivalence test"];
    return [self charon_differenceFromArray:other withOptions:options usingEquivalenceTest:block];
}

- (NSOrderedCollectionDifference *)differenceFromArray:(NSArray *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options
{
    if (!other)
        [NSException raise:NSInvalidArgumentException format:@"Cannot diff nil parameter"];
    return [self charon_differenceFromArray:other withOptions:options usingEquivalenceTest:^BOOL(id one, id two) {
        return one == two || [one isEqual:two];
    }];
}

- (NSOrderedCollectionDifference *)differenceFromArray:(NSArray *)other
{
    return [self differenceFromArray:other withOptions:0];
}

- (NSArray *)arrayByApplyingDifference:(NSOrderedCollectionDifference *)difference
{
    NSMutableArray *result = [self mutableCopy];
    for (NSOrderedCollectionChange *change in difference) {
        NSUInteger index = change.index;
        if (change.changeType == NSCollectionChangeRemove) {
            if (index >= result.count)
                return nil;
            [result removeObjectAtIndex:index];
        } else {
            id object = change.object;
            if (!object || index > result.count)
                return nil;
            [result insertObject:object atIndex:index];
        }
    }
    return [result copy];
}

@end

@implementation NSMutableArray (CharonDifference)

- (void)applyDifference:(NSOrderedCollectionDifference *)difference
{
    for (NSOrderedCollectionChange *change in difference) {
        if (change.changeType == NSCollectionChangeRemove)
            [self removeObjectAtIndex:change.index];
        else
            [self insertObject:change.object atIndex:change.index];
    }
}

@end
