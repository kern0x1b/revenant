#import "CharonDiffable.h"

static NSString *const charon_section_file = @"NSDiffableDataSourceSectionSnapshot.m";

@implementation NSDiffableDataSourceSectionSnapshot {
@private
    NSMutableArray *_roots;
    NSMapTable *_kids;
    NSMapTable *_up;
    NSMutableSet *_expanded;
    NSArray *_flat;
    NSMapTable *_positions;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _roots = [[NSMutableArray alloc] init];
        _kids = [NSMapTable strongToStrongObjectsMapTable];
        _up = [NSMapTable strongToStrongObjectsMapTable];
        _expanded = [[NSMutableSet alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSDiffableDataSourceSectionSnapshot *copy = [[[self class] allocWithZone:zone] init];
    [copy->_roots addObjectsFromArray:_roots];
    for (id item in _kids)
        [copy->_kids setObject:[[_kids objectForKey:item] mutableCopy] forKey:item];
    for (id item in _up)
        [copy->_up setObject:[_up objectForKey:item] forKey:item];
    [copy->_expanded unionSet:_expanded];
    return copy;
}

- (void)charon_changed
{
    _flat = nil;
    _positions = nil;
}

- (NSArray *)charon_children:(id)parent
{
    return parent ? ([_kids objectForKey:parent] ?: @[]) : _roots;
}

- (void)charon_walk:(NSArray *)nodes into:(NSMutableArray *)flat
{
    for (id node in nodes) {
        [flat addObject:node];
        NSArray *children = [_kids objectForKey:node];
        if (children.count)
            [self charon_walk:children into:flat];
    }
}

- (NSArray *)charon_flat
{
    if (!_flat) {
        NSMutableArray *flat = [NSMutableArray array];
        [self charon_walk:_roots into:flat];
        _flat = flat;
        _positions = [NSMapTable strongToStrongObjectsMapTable];
        for (NSUInteger index = 0; index < flat.count; index++)
            [_positions setObject:@(index) forKey:flat[index]];
    }
    return _flat;
}

- (BOOL)charon_has:(id)item
{
    return item && [_up objectForKey:item] != nil;
}

- (NSUInteger)charon_size:(id)item
{
    NSUInteger size = 1;
    for (id child in [_kids objectForKey:item])
        size += [self charon_size:child];
    return size;
}

- (void)charon_checkUnique:(NSArray *)items
{
    NSMutableSet *seen = [NSMutableSet set];
    NSMutableOrderedSet *duplicates = [NSMutableOrderedSet orderedSet];
    for (id item in items) {
        if ([self charon_has:item] || [seen containsObject:item])
            [duplicates addObject:item];
        [seen addObject:item];
    }
    if (duplicates.count)
        charon_diffable_raise(charon_section_file, 24, [NSString stringWithFormat:@"Identifiers in a section snapshot must be unique. Duplicate item identifiers: %@", duplicates]);
}

- (void)charon_adopt:(NSArray *)items parent:(id)parent at:(NSUInteger)position
{
    NSMutableArray *siblings;
    if (parent) {
        siblings = [_kids objectForKey:parent];
        if (!siblings) {
            siblings = [[NSMutableArray alloc] init];
            [_kids setObject:siblings forKey:parent];
        }
    } else
        siblings = _roots;
    for (id item in items) {
        [siblings insertObject:item atIndex:position++];
        [_up setObject:parent ?: [NSNull null] forKey:item];
    }
    [self charon_changed];
}

- (void)appendItems:(NSArray *)items
{
    [self appendItems:items intoParentItem:nil];
}

- (void)appendItems:(NSArray *)items intoParentItem:(id)parentItem
{
    if (!items.count)
        return;
    if (parentItem && ![self charon_has:parentItem])
        charon_diffable_raise(charon_section_file, 340, [NSString stringWithFormat:@"Parent item identifier does not exist in section snapshot: %@", parentItem]);
    [self charon_checkUnique:items];
    [self charon_adopt:items parent:parentItem at:[self charon_children:parentItem].count];
}

- (void)charon_insertItems:(NSArray *)items relativeTo:(id)destination after:(BOOL)after
{
    if (!items.count)
        return;
    if (![self charon_has:destination])
        charon_diffable_raise(charon_section_file, after ? 167 : 131, [NSString stringWithFormat:@"Item identifier to insert %@ does not exist in section snapshot: %@", after ? @"after" : @"before", destination]);
    [self charon_checkUnique:items];
    id parent = [_up objectForKey:destination];
    if (parent == [NSNull null])
        parent = nil;
    [self charon_adopt:items parent:parent at:[[self charon_children:parent] indexOfObject:destination] + (after ? 1 : 0)];
}

- (void)insertItems:(NSArray *)items beforeItem:(id)beforeIdentifier
{
    [self charon_insertItems:items relativeTo:beforeIdentifier after:NO];
}

- (void)insertItems:(NSArray *)items afterItem:(id)afterIdentifier
{
    [self charon_insertItems:items relativeTo:afterIdentifier after:YES];
}

- (void)charon_remove:(id)item
{
    for (id child in [[_kids objectForKey:item] copy])
        [self charon_remove:child];
    [_kids removeObjectForKey:item];
    [_up removeObjectForKey:item];
    [_expanded removeObject:item];
}

- (void)charon_detach:(id)item
{
    id parent = [_up objectForKey:item];
    NSMutableArray *siblings = parent == [NSNull null] ? _roots : [_kids objectForKey:parent];
    [siblings removeObject:item];
    if (parent != [NSNull null] && !siblings.count)
        [_kids removeObjectForKey:parent];
    [self charon_remove:item];
    [self charon_changed];
}

- (void)deleteItems:(NSArray *)items
{
    if (!items.count)
        return;
    for (id item in items)
        if (![self charon_has:item])
            charon_diffable_raise(charon_section_file, 572, [NSString stringWithFormat:@"Failed to find index of item %@", item]);
    for (id item in items)
        if ([self charon_has:item])
            [self charon_detach:item];
}

- (void)deleteAllItems
{
    [_roots removeAllObjects];
    [_kids removeAllObjects];
    [_up removeAllObjects];
    [_expanded removeAllObjects];
    [self charon_changed];
}

- (void)expandItems:(NSArray *)items
{
    for (id item in items)
        if ([self charon_has:item])
            [_expanded addObject:item];
}

- (void)collapseItems:(NSArray *)items
{
    for (id item in items)
        [_expanded removeObject:item];
}

- (void)charon_graft:(NSDiffableDataSourceSectionSnapshot *)snapshot parent:(id)parent at:(NSUInteger)position
{
    NSArray *roots = snapshot->_roots;
    [self charon_adopt:roots parent:parent at:position];
    for (id item in [snapshot items]) {
        NSArray *children = [snapshot->_kids objectForKey:item];
        if (children.count) {
            NSMutableArray *copy = [children mutableCopy];
            [_kids setObject:copy forKey:item];
            for (id child in children)
                [_up setObject:item forKey:child];
        }
    }
    for (id item in snapshot->_expanded)
        [_expanded addObject:item];
    [self charon_changed];
}

- (void)replaceChildrenOfParentItem:(id)parentItem withSnapshot:(NSDiffableDataSourceSectionSnapshot *)snapshot
{
    charon_diffable_require(parentItem != nil, charon_section_file, 259, @"parentItem != nil");
    charon_diffable_require(snapshot != nil, charon_section_file, 260, @"snapshot != nil");
    if (![self charon_has:parentItem])
        charon_diffable_raise(charon_section_file, 266, [NSString stringWithFormat:@"Parent item identifier does not exist in section snapshot: %@", parentItem]);
    NSDiffableDataSourceSectionSnapshot *before = [self copy];
    for (id child in [[_kids objectForKey:parentItem] copy])
        [self charon_detach:child];
    @try {
        [self charon_checkUnique:snapshot.items];
    } @catch (NSException *exception) {
        _roots = before->_roots;
        _kids = before->_kids;
        _up = before->_up;
        _expanded = before->_expanded;
        [self charon_changed];
        @throw;
    }
    [self charon_graft:snapshot parent:parentItem at:0];
}

- (id)charon_insertSnapshot:(NSDiffableDataSourceSectionSnapshot *)snapshot relativeTo:(id)destination after:(BOOL)after
{
    if (!snapshot.items.count)
        return nil;
    if (![self charon_has:destination])
        charon_diffable_raise(charon_section_file, after ? 421 : 391, [NSString stringWithFormat:@"Item identifier to insert %@ does not exist in section snapshot: %@", after ? @"after" : @"before", destination]);
    [self charon_checkUnique:snapshot.items];
    NSArray *flat = [self charon_flat];
    NSUInteger index = [[_positions objectForKey:destination] unsignedIntegerValue], end = index + [self charon_size:destination];
    id result = nil;
    if ([[_kids objectForKey:destination] count])
        result = end < flat.count ? flat[end] : nil;
    else
        result = index + 1 < flat.count ? destination : nil;
    id parent = [_up objectForKey:destination];
    if (parent == [NSNull null])
        parent = nil;
    [self charon_graft:snapshot parent:parent at:[[self charon_children:parent] indexOfObject:destination] + (after ? 1 : 0)];
    return result;
}

- (void)insertSnapshot:(NSDiffableDataSourceSectionSnapshot *)snapshot beforeItem:(id)item
{
    [self charon_insertSnapshot:snapshot relativeTo:item after:NO];
}

- (id)insertSnapshot:(NSDiffableDataSourceSectionSnapshot *)snapshot afterItem:(id)item
{
    return [self charon_insertSnapshot:snapshot relativeTo:item after:YES];
}

- (BOOL)isExpanded:(id)item
{
    if (![self charon_has:item])
        charon_diffable_raise(charon_section_file, 308, [NSString stringWithFormat:@"Item identifier does not exist in section snapshot: %@", item]);
    return [_expanded containsObject:item];
}

- (BOOL)charon_visible:(id)item
{
    for (id parent = [_up objectForKey:item]; parent != [NSNull null]; parent = [_up objectForKey:parent])
        if (![_expanded containsObject:parent])
            return NO;
    return YES;
}

- (BOOL)isVisible:(id)item
{
    if (![self charon_has:item])
        charon_diffable_raise(charon_section_file, 315, [NSString stringWithFormat:@"Item identifier does not exist in section snapshot: %@", item]);
    return [self charon_visible:item];
}

- (BOOL)containsItem:(id)item
{
    return [self charon_has:item];
}

- (NSInteger)levelOfItem:(id)item
{
    if (![self charon_has:item])
        charon_diffable_raise(charon_section_file, 323, [NSString stringWithFormat:@"Item identifier does not exist in section snapshot: %@", item]);
    NSInteger level = 0;
    for (id parent = [_up objectForKey:item]; parent != [NSNull null]; parent = [_up objectForKey:parent])
        level++;
    return level;
}

- (NSInteger)indexOfItem:(id)item
{
    if (![self charon_has:item])
        return NSNotFound;
    [self charon_flat];
    return [[_positions objectForKey:item] integerValue];
}

- (NSArray *)items
{
    return [[self charon_flat] copy];
}

- (NSArray *)rootItems
{
    return [_roots copy];
}

- (NSArray *)visibleItems
{
    NSMutableArray *visible = [NSMutableArray array];
    for (id item in [self charon_flat])
        if ([self charon_visible:item])
            [visible addObject:item];
    return visible;
}

- (NSArray *)expandedItems
{
    NSMutableArray *expanded = [NSMutableArray array];
    for (id item in [self charon_flat])
        if ([_expanded containsObject:item])
            [expanded addObject:item];
    return expanded;
}

- (id)parentOfChildItem:(id)childItem
{
    if (![self charon_has:childItem])
        charon_diffable_raise(charon_section_file, 451, [NSString stringWithFormat:@"Child item identifier does not exist in section snapshot: %@", childItem]);
    id parent = [_up objectForKey:childItem];
    return parent == [NSNull null] ? nil : parent;
}

- (void)charon_copyTree:(id)item into:(NSDiffableDataSourceSectionSnapshot *)target parent:(id)parent
{
    [target charon_adopt:@[item] parent:parent at:[[target charon_children:parent] count]];
    if ([_expanded containsObject:item])
        [target->_expanded addObject:item];
    for (id child in [_kids objectForKey:item])
        [self charon_copyTree:child into:target parent:item];
}

- (NSDiffableDataSourceSectionSnapshot *)snapshotOfParentItem:(id)parentItem
{
    return [self snapshotOfParentItem:parentItem includingParentItem:NO];
}

- (NSDiffableDataSourceSectionSnapshot *)snapshotOfParentItem:(id)parentItem includingParentItem:(BOOL)includingParentItem
{
    charon_diffable_require(parentItem != nil, charon_section_file, 359, @"item != nil");
    if (![self charon_has:parentItem])
        charon_diffable_raise(charon_section_file, 361, [NSString stringWithFormat:@"Parent item identifier does not exist in section snapshot: %@", parentItem]);
    NSDiffableDataSourceSectionSnapshot *snapshot = [[[self class] alloc] init];
    if (includingParentItem)
        [self charon_copyTree:parentItem into:snapshot parent:nil];
    else
        for (id child in [_kids objectForKey:parentItem])
            [self charon_copyTree:child into:snapshot parent:nil];
    return snapshot;
}

- (void)charon_describe:(NSArray *)nodes level:(NSUInteger)level into:(NSMutableString *)text
{
    for (id node in nodes) {
        [text appendFormat:@"%*s%@%@%@\n", (int)(level * 2), "", [_expanded containsObject:node] ? @"+" : @"-", [self charon_visible:node] ? @"*" : @" ", node];
        [self charon_describe:[_kids objectForKey:node] level:level + 1 into:text];
    }
}

- (NSString *)visualDescription
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p\n", NSStringFromClass([self class]), self];
    [self charon_describe:_roots level:0 into:text];
    [text appendString:@">"];
    return text;
}

- (void)charon_chunks:(NSArray *)nodes level:(NSUInteger)level counter:(NSUInteger *)counter into:(NSMutableString *)text
{
    NSUInteger position = 0;
    while (position < nodes.count) {
        NSUInteger start = position;
        while (position + 1 < nodes.count && ![[_kids objectForKey:nodes[position]] count])
            position++;
        id last = nodes[position];
        position++;
        NSUInteger chunk = (*counter)++;
        [text appendFormat:@"%*s%@[%lu]%lu: {%lu,%lu}\n", (int)(level * 2), "", [_expanded containsObject:nodes[start]] ? @"+" : @"-", (unsigned long)level, (unsigned long)chunk, (unsigned long)[[_positions objectForKey:nodes[start]] unsignedIntegerValue], (unsigned long)(position - start)];
        [self charon_chunks:[_kids objectForKey:last] level:level + 1 counter:counter into:text];
    }
}

- (NSString *)description
{
    NSArray *flat = [self charon_flat];
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p\ncount=%lu\n", NSStringFromClass([self class]), self, (unsigned long)flat.count];
    NSUInteger counter = 0;
    [self charon_chunks:_roots level:0 counter:&counter into:text];
    [text appendString:@">"];
    return text;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSDiffableDataSourceSectionSnapshot class]])
        return NO;
    NSDiffableDataSourceSectionSnapshot *snapshot = other;
    if (![_roots isEqual:snapshot->_roots] || ![_expanded isEqual:snapshot->_expanded])
        return NO;
    for (id item in [self charon_flat])
        if (![[self charon_children:item] isEqual:[snapshot charon_children:item]])
            return NO;
    return YES;
}

@end
