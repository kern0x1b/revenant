#import "CharonOrderedCollections.h"

static NSComparisonResult charon_compare_changes(NSOrderedCollectionChange *one, NSOrderedCollectionChange *two, void *context)
{
    NSUInteger a = one.index, b = two.index;
    return a < b ? NSOrderedAscending : (a > b ? NSOrderedDescending : NSOrderedSame);
}

static void charon_raise_duplicate(NSString *reason, NSUInteger index)
{
    [[NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:@{@"index": @(index)}] raise];
}

@implementation NSOrderedCollectionDifference {
@private
    NSArray *_insertions;
    NSArray *_removals;
    NSArray *_ordered;
}

- (instancetype)init
{
    return [self initWithChanges:@[]];
}

- (instancetype)initWithChanges:(NSArray *)changes
{
    BOOL insertObjects = NO, removeObjects = NO;
    for (NSOrderedCollectionChange *change in changes) {
        NSCollectionChangeType type = change.changeType;
        if (!change.object)
            continue;
        if (type == NSCollectionChangeInsert)
            insertObjects = YES;
        else
            removeObjects = YES;
    }
    return [self initWithInsertIndexes:[NSIndexSet indexSet] insertedObjects:insertObjects ? @[] : nil removeIndexes:[NSIndexSet indexSet] removedObjects:removeObjects ? @[] : nil additionalChanges:changes ?: @[]];
}

- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(NSArray *)insertedObjects removeIndexes:(NSIndexSet *)removes removedObjects:(NSArray *)removedObjects
{
    return [self initWithInsertIndexes:inserts insertedObjects:insertedObjects removeIndexes:removes removedObjects:removedObjects additionalChanges:@[]];
}

- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(NSArray *)insertedObjects removeIndexes:(NSIndexSet *)removes removedObjects:(NSArray *)removedObjects additionalChanges:(NSArray *)changes
{
    if (insertedObjects && insertedObjects.count != inserts.count)
        [NSException raise:NSInvalidArgumentException format:@"Count of inserted objects does not match count of inserted indexes"];
    if (removedObjects && removedObjects.count != removes.count)
        [NSException raise:NSInvalidArgumentException format:@"Count of removed objects does not match count of removed indexes"];
    NSMutableIndexSet *insertSeen = inserts ? [inserts mutableCopy] : [NSMutableIndexSet indexSet];
    NSMutableIndexSet *removeSeen = removes ? [removes mutableCopy] : [NSMutableIndexSet indexSet];
    NSMutableArray *insertions = [NSMutableArray array], *removals = [NSMutableArray array];
    NSMutableDictionary *insertLinks = [NSMutableDictionary dictionary], *removeLinks = [NSMutableDictionary dictionary];
    NSMutableArray *insertOrder = [NSMutableArray array];
    NSUInteger position = 0;
    for (NSUInteger index = inserts.firstIndex; inserts && index != NSNotFound; index = [inserts indexGreaterThanIndex:index])
        [insertions addObject:[NSOrderedCollectionChange changeWithObject:insertedObjects ? insertedObjects[position++] : nil type:NSCollectionChangeInsert index:index]];
    position = 0;
    for (NSUInteger index = removes.firstIndex; removes && index != NSNotFound; index = [removes indexGreaterThanIndex:index])
        [removals addObject:[NSOrderedCollectionChange changeWithObject:removedObjects ? removedObjects[position++] : nil type:NSCollectionChangeRemove index:index]];
    for (NSOrderedCollectionChange *change in changes) {
        NSUInteger index = change.index, link = change.associatedIndex;
        if (change.changeType == NSCollectionChangeInsert) {
            if ([insertSeen containsIndex:index])
                charon_raise_duplicate(@"Remove index duplicated between index set and additional changes parameters", index);
            if (insertedObjects && !change.object)
                [NSException raise:NSInvalidArgumentException format:@"Inserted objects array provided, but additional change omitted object"];
            if (!insertedObjects && change.object)
                [NSException raise:NSInvalidArgumentException format:@"No inserted objects array provided, but additional changes included objects"];
            [insertSeen addIndex:index];
            [insertions addObject:change];
            if (link != NSNotFound) {
                insertLinks[@(index)] = @(link);
                [insertOrder addObject:@(index)];
            }
        } else {
            if ([removeSeen containsIndex:index])
                charon_raise_duplicate(@"Insert index duplicated between index set and additional changes parameters", index);
            if (removedObjects && !change.object)
                [NSException raise:NSInvalidArgumentException format:@"Removed objects array provided, but additional change omitted object"];
            if (!removedObjects && change.object)
                [NSException raise:NSInvalidArgumentException format:@"No removed objects array provided, but additional change included object"];
            [removeSeen addIndex:index];
            [removals addObject:change];
            if (link != NSNotFound)
                removeLinks[@(index)] = @(link);
        }
    }
    for (NSNumber *removal in removeLinks)
        if (![insertLinks[removeLinks[removal]] isEqual:removal])
            [NSException raise:NSInvalidArgumentException format:@"Inconsistent associations for moves"];
    NSMutableSet *paired = [NSMutableSet set];
    for (NSNumber *insertion in insertOrder) {
        NSNumber *target = removeLinks[insertLinks[insertion]];
        if (!target)
            [NSException raise:NSInvalidArgumentException format:@"Inconsistent associations for moves"];
        if ([target isEqual:insertion]) {
            [paired addObject:insertion];
            continue;
        }
        if ([paired containsObject:target])
            [NSException raise:NSInvalidArgumentException format:@"Inconsistent associations for moves"];
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"Unbalanced number of remove and insert changes with associations." userInfo:@{@"NSAssertFile": @"NSOrderedCollectionDifference.m", @"NSAssertLine": @38}] raise];
    }
    [insertions sortUsingFunction:charon_compare_changes context:NULL];
    [removals sortUsingFunction:charon_compare_changes context:NULL];
    if ((self = [super init]))
        [self charon_setInsertions:insertions removals:removals];
    return self;
}

- (instancetype)charon_initWithInsertions:(NSArray *)insertions removals:(NSArray *)removals
{
    if ((self = [self initWithInsertIndexes:[NSIndexSet indexSet] insertedObjects:nil removeIndexes:[NSIndexSet indexSet] removedObjects:nil]))
        [self charon_setInsertions:insertions removals:removals];
    return self;
}

- (void)charon_setInsertions:(NSArray *)insertions removals:(NSArray *)removals
{
    _insertions = [insertions copy];
    _removals = [removals copy];
    NSMutableArray *ordered = [NSMutableArray arrayWithCapacity:removals.count + insertions.count];
    for (NSUInteger index = removals.count; index > 0; index--)
        [ordered addObject:removals[index - 1]];
    [ordered addObjectsFromArray:insertions];
    _ordered = ordered;
}

- (NSArray *)insertions
{
    return _insertions;
}

- (NSArray *)removals
{
    return _removals;
}

- (BOOL)hasChanges
{
    return _insertions.count || _removals.count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)length
{
    return [_ordered countByEnumeratingWithState:state objects:buffer count:length];
}

- (NSOrderedCollectionDifference<id> *)differenceByTransformingChangesWithBlock:(NSOrderedCollectionChange<id> *(NS_NOESCAPE ^)(NSOrderedCollectionChange<id> *))block
{
    NSMutableArray *changes = [NSMutableArray arrayWithCapacity:_ordered.count];
    for (NSOrderedCollectionChange *change in _ordered)
        [changes addObject:block(change)];
    return [[[self class] alloc] initWithChanges:changes];
}

- (instancetype)inverseDifference
{
    NSMutableArray *insertions = [NSMutableArray arrayWithCapacity:_removals.count], *removals = [NSMutableArray arrayWithCapacity:_insertions.count];
    for (NSOrderedCollectionChange *change in _removals)
        [insertions addObject:[NSOrderedCollectionChange changeWithObject:change.object type:NSCollectionChangeInsert index:change.index associatedIndex:change.associatedIndex]];
    for (NSOrderedCollectionChange *change in _insertions)
        [removals addObject:[NSOrderedCollectionChange changeWithObject:change.object type:NSCollectionChangeRemove index:change.index associatedIndex:change.associatedIndex]];
    return [[[self class] alloc] charon_initWithInsertions:insertions removals:removals];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSOrderedCollectionDifference class]])
        return NO;
    NSOrderedCollectionDifference *difference = other;
    return [_insertions isEqual:difference.insertions] && [_removals isEqual:difference.removals];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    for (NSOrderedCollectionChange *change in _ordered)
        hash = hash * 31 + change.hash;
    return hash;
}

- (NSString *)description
{
    NSUInteger insertions = _insertions.count, removals = _removals.count;
    return [NSString stringWithFormat:@"<%@: %p>(%lu insertion%@, %lu removal%@)", NSStringFromClass([self class]), self, (unsigned long)insertions, insertions == 1 ? @"" : @"s", (unsigned long)removals, removals == 1 ? @"" : @"s"];
}

- (NSString *)charon_listing
{
    NSMutableString *text = [NSMutableString string];
    if (!_ordered.count)
        return @"()";
    [text appendString:@"(\n"];
    for (NSOrderedCollectionChange *change in _ordered)
        [text appendFormat:@"\t%@\n", change.debugDescription];
    [text appendString:@")"];
    return text;
}

- (NSString *)debugDescription
{
    BOOL plain = _ordered.count > 0;
    for (NSOrderedCollectionChange *change in _ordered)
        if (![change.object isKindOfClass:[NSString class]]) {
            plain = NO;
            break;
        }
    if (!plain)
        return [NSString stringWithFormat:@"%@ %@", self.description, [self charon_listing]];
    NSMutableString *text = [NSMutableString string], *lines = [NSMutableString string];
    NSUInteger removalIndex = 0, insertionIndex = 0, removalsBefore = 0, insertionsBefore = 0;
    BOOL open = NO, hasInsertion = NO, lastWasRemoval = NO;
    NSInteger oldStart = 0, oldEnd = 0, newStart = 0, newEnd = 0;
    while (removalIndex < _removals.count || insertionIndex < _insertions.count) {
        NSInteger removalLine = 0, insertionLine = 0, oldNext = 0;
        BOOL removal;
        if (removalIndex < _removals.count) {
            removalLine = (NSInteger)[_removals[removalIndex] index] + 1;
            if (insertionIndex < _insertions.count) {
                insertionLine = (NSInteger)[_insertions[insertionIndex] index] + 1;
                oldNext = insertionLine - (NSInteger)insertionsBefore + (NSInteger)removalsBefore;
                removal = removalLine <= oldNext;
            } else
                removal = YES;
        } else {
            insertionLine = (NSInteger)[_insertions[insertionIndex] index] + 1;
            oldNext = insertionLine - (NSInteger)insertionsBefore + (NSInteger)removalsBefore;
            removal = NO;
        }
        BOOL joins = open && (removal ? removalLine <= oldEnd + 1 : insertionLine <= newEnd + 1);
        if (open && !joins) {
            [text appendFormat:@"%@c%@\n%@", oldStart == oldEnd ? [NSString stringWithFormat:@"%ld", (long)oldStart] : [NSString stringWithFormat:@"%ld,%ld", (long)oldStart, (long)oldEnd], hasInsertion ? (newStart == newEnd ? [NSString stringWithFormat:@"%ld", (long)newStart] : [NSString stringWithFormat:@"%ld,%ld", (long)newStart, (long)newEnd]) : [NSString stringWithFormat:@"%ld", (long)newStart], lines];
            [lines setString:@""];
            open = NO;
            lastWasRemoval = NO;
        }
        if (removal) {
            NSInteger newNext = removalLine - (NSInteger)removalsBefore + (NSInteger)insertionsBefore;
            if (!open) {
                open = YES;
                hasInsertion = NO;
                oldStart = oldEnd = removalLine;
                newStart = newNext;
                newEnd = newNext - 1;
            } else
                oldEnd = removalLine;
            [lines appendFormat:@"< %@\n", [_removals[removalIndex] object]];
            lastWasRemoval = YES;
            removalIndex++;
            removalsBefore++;
        } else {
            if (!open) {
                open = YES;
                hasInsertion = YES;
                newStart = newEnd = insertionLine;
                oldStart = oldEnd = oldNext;
            } else {
                if (!hasInsertion)
                    newStart = insertionLine;
                hasInsertion = YES;
                newEnd = insertionLine;
            }
            if (lastWasRemoval)
                [lines appendString:@"---\n"];
            [lines appendFormat:@"> %@\n", [_insertions[insertionIndex] object]];
            lastWasRemoval = NO;
            insertionIndex++;
            insertionsBefore++;
        }
    }
    if (open)
        [text appendFormat:@"%@c%@\n%@", oldStart == oldEnd ? [NSString stringWithFormat:@"%ld", (long)oldStart] : [NSString stringWithFormat:@"%ld,%ld", (long)oldStart, (long)oldEnd], hasInsertion ? (newStart == newEnd ? [NSString stringWithFormat:@"%ld", (long)newStart] : [NSString stringWithFormat:@"%ld,%ld", (long)newStart, (long)newEnd]) : [NSString stringWithFormat:@"%ld", (long)newStart], lines];
    return text;
}

@end
