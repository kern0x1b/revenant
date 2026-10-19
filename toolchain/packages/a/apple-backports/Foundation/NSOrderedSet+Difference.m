#import "CharonOrderedCollections.h"

@implementation NSOrderedSet (CharonDifference)

- (NSOrderedCollectionDifference *)charon_differenceFromOrderedSet:(NSOrderedSet *)other options:(NSOrderedCollectionDifferenceCalculationOptions)options
{
    NSInteger n = (NSInteger)other.count, m = (NSInteger)self.count, i = 0, j = 0;
    NSMutableArray *removals = [NSMutableArray array], *insertions = [NSMutableArray array];
    while (i < n && j < m) {
        id one = other[(NSUInteger)i], two = self[(NSUInteger)j];
        if (one == two || [one isEqual:two]) {
            i++;
            j++;
            continue;
        }
        NSUInteger oneFound = [self indexOfObject:one], twoFound = [other indexOfObject:two];
        NSInteger oneAt = oneFound != NSNotFound && (NSInteger)oneFound >= j ? (NSInteger)oneFound : -1;
        NSInteger twoAt = twoFound != NSNotFound && (NSInteger)twoFound >= i ? (NSInteger)twoFound : -1;
        if (oneAt < 0)
            [removals addObject:@(i++)];
        else if (twoAt < 0)
            [insertions addObject:@(j++)];
        else if (oneAt - j < twoAt - i)
            [insertions addObject:@(j++)];
        else
            [removals addObject:@(i++)];
    }
    for (; i < n; i++)
        [removals addObject:@(i)];
    for (; j < m; j++)
        [insertions addObject:@(j)];
    return [self.array charon_differenceFromArray:other.array removed:removals inserted:insertions options:options];
}

- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(id, id))block
{
    if (!other)
        [NSException raise:NSInvalidArgumentException format:@"Cannot diff nil parameter"];
    if (options & NSOrderedCollectionDifferenceCalculationInferMoves)
        [NSException raise:NSInvalidArgumentException format:@"Inferring moves is not supported when using a custom equivalence test"];
    return [self.array charon_differenceFromArray:other.array withOptions:options usingEquivalenceTest:block];
}

- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options
{
    if (!other)
        [NSException raise:NSInvalidArgumentException format:@"Cannot diff nil parameter"];
    return [self charon_differenceFromOrderedSet:other options:options];
}

- (NSOrderedSet *)orderedSetByApplyingDifference:(NSOrderedCollectionDifference *)difference
{
    NSMutableOrderedSet *result = [self mutableCopy];
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

- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other
{
    return [self differenceFromOrderedSet:other withOptions:0];
}

@end

@implementation NSMutableOrderedSet (CharonDifference)

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
