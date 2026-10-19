#import "CharonDiffable.h"

static NSString *const charon_update_file = @"_UIDiffableDataSourceUpdate.m";
static NSString *const charon_snapshot_file = @"__UIDiffableDataSourceSnapshot.m";
static NSString *const charon_state_file = @"_UIDiffableDataSourceState.m";

static NSString *charon_joined(NSArray *identifiers)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (id identifier in identifiers)
        [parts addObject:[NSString stringWithFormat:@"%@", identifier]];
    return [parts componentsJoinedByString:@","];
}

static void charon_check_unique(NSArray *identifiers, NSString *kind)
{
    NSMutableSet *seen = [NSMutableSet set];
    NSMutableOrderedSet *duplicates = [NSMutableOrderedSet orderedSet];
    for (id identifier in identifiers) {
        if ([seen containsObject:identifier])
            [duplicates addObject:identifier];
        [seen addObject:identifier];
    }
    if (duplicates.count)
        charon_diffable_raise(charon_update_file, 81, [NSString stringWithFormat:@"Fatal: supplied %@ identifiers are not unique. Duplicate identifiers: %@", kind, duplicates]);
}

static void charon_raise_in_list(id destination, NSArray *identifiers, NSString *action, NSInteger line, NSString *format)
{
    NSString *update = [NSString stringWithFormat:@"<_UIDiffableDataSourceUpdate %p - action: %@; destinationIdentifier:%@; destIsSection: 0; identifiers: [%@]>", (__bridge void *)identifiers, action, destination, charon_joined(identifiers)];
    charon_diffable_raise(charon_update_file, line, [NSString stringWithFormat:format, destination, update]);
}

@implementation NSDiffableDataSourceSnapshot {
@private
    NSMutableOrderedSet *_sections;
    NSMutableArray *_items;
    NSMapTable *_owners;
    NSMutableOrderedSet *_reloadedItems;
    NSMutableOrderedSet *_reloadedSections;
    NSString *_generation;
}

@dynamic reloadedSectionIdentifiers, reloadedItemIdentifiers, reconfiguredItemIdentifiers;

- (instancetype)init
{
    if ((self = [super init])) {
        _sections = [[NSMutableOrderedSet alloc] init];
        _items = [[NSMutableArray alloc] init];
        _owners = [NSMapTable strongToStrongObjectsMapTable];
        _reloadedItems = [[NSMutableOrderedSet alloc] init];
        _reloadedSections = [[NSMutableOrderedSet alloc] init];
        _generation = [NSUUID UUID].UUIDString;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSDiffableDataSourceSnapshot *copy = [[[self class] allocWithZone:zone] init];
    [copy->_sections unionOrderedSet:_sections];
    for (NSOrderedSet *items in _items)
        [copy->_items addObject:[items mutableCopy]];
    for (id item in _owners)
        [copy->_owners setObject:[_owners objectForKey:item] forKey:item];
    [copy->_reloadedItems unionOrderedSet:_reloadedItems];
    [copy->_reloadedSections unionOrderedSet:_reloadedSections];
    copy->_generation = _generation;
    return copy;
}

- (NSInteger)numberOfItems
{
    return (NSInteger)_owners.count;
}

- (NSInteger)numberOfSections
{
    return (NSInteger)_sections.count;
}

- (NSArray *)sectionIdentifiers
{
    return [_sections array];
}

- (NSArray *)itemIdentifiers
{
    NSMutableArray *all = [NSMutableArray arrayWithCapacity:_owners.count];
    for (NSOrderedSet *items in _items)
        [all addObjectsFromArray:[items array]];
    return all;
}

- (NSUInteger)charon_indexOfSection:(id)identifier
{
    return identifier ? [_sections indexOfObject:identifier] : NSNotFound;
}

- (NSInteger)numberOfItemsInSection:(id)sectionIdentifier
{
    NSUInteger index = [self charon_indexOfSection:sectionIdentifier];
    if (index == NSNotFound)
        charon_diffable_raise(charon_state_file, 273, @"Section identifier was not found. You can verify the section exists by calling the indexOfSectionIdentifier API (which has O(1) performance)");
    return (NSInteger)[_items[index] count];
}

- (NSArray *)itemIdentifiersInSectionWithIdentifier:(id)sectionIdentifier
{
    charon_diffable_require(sectionIdentifier != nil, charon_state_file, 278, @"sectionIdentifier");
    NSUInteger index = [self charon_indexOfSection:sectionIdentifier];
    if (index == NSNotFound)
        charon_diffable_raise(charon_state_file, 286, @"Section identifier was not found. You can verify the section exists by calling the indexOfSectionIdentifier API (which has O(1) performance)");
    return [_items[index] array];
}

- (id)sectionIdentifierForSectionContainingItemIdentifier:(id)itemIdentifier
{
    charon_diffable_require(itemIdentifier != nil, charon_state_file, 297, @"identifier");
    return [_owners objectForKey:itemIdentifier];
}

- (NSInteger)indexOfItemIdentifier:(id)itemIdentifier
{
    id owner = itemIdentifier ? [_owners objectForKey:itemIdentifier] : nil;
    if (!owner)
        return NSNotFound;
    NSUInteger section = [_sections indexOfObject:owner], before = 0;
    for (NSUInteger index = 0; index < section; index++)
        before += [_items[index] count];
    return (NSInteger)(before + [_items[section] indexOfObject:itemIdentifier]);
}

- (NSInteger)indexOfSectionIdentifier:(id)sectionIdentifier
{
    return (NSInteger)[self charon_indexOfSection:sectionIdentifier];
}

- (void)charon_removeItem:(id)item
{
    id owner = [_owners objectForKey:item];
    if (!owner)
        return;
    [_items[[_sections indexOfObject:owner]] removeObject:item];
    [_owners removeObjectForKey:item];
}

- (void)charon_insertItems:(NSArray *)identifiers intoSectionAtIndex:(NSUInteger)section atIndex:(NSUInteger)position
{
    for (id item in identifiers)
        [self charon_removeItem:item];
    NSMutableOrderedSet *items = _items[section];
    position = MIN(position, items.count);
    for (id item in identifiers) {
        [items insertObject:item atIndex:position++];
        [_owners setObject:_sections[section] forKey:item];
    }
}

- (void)appendItemsWithIdentifiers:(NSArray *)identifiers
{
    if (!_sections.count)
        charon_diffable_raise(charon_snapshot_file, 169, @"There are currently no sections in the data source. Please add a section first.");
    [self appendItemsWithIdentifiers:identifiers intoSectionWithIdentifier:_sections.lastObject];
}

- (void)appendItemsWithIdentifiers:(NSArray *)identifiers intoSectionWithIdentifier:(id)sectionIdentifier
{
    if (!_sections.count)
        charon_diffable_raise(charon_snapshot_file, 169, @"There are currently no sections in the data source. Please add a section first.");
    charon_diffable_require(identifiers != nil, charon_update_file, 124, @"itemIdentifiers");
    charon_check_unique(identifiers, @"item");
    NSUInteger section = sectionIdentifier ? [self charon_indexOfSection:sectionIdentifier] : _sections.count - 1;
    charon_diffable_require(section != NSNotFound, charon_update_file, 298, @"section != NSNotFound");
    [self charon_insertItems:identifiers intoSectionAtIndex:section atIndex:NSUIntegerMax];
}

- (void)charon_insertItems:(NSArray *)identifiers relativeTo:(id)destination after:(BOOL)after
{
    charon_diffable_require(identifiers != nil, charon_snapshot_file, after ? 182 : 175, @"identifiers");
    charon_diffable_require(destination != nil, charon_snapshot_file, after ? 183 : 176, @"destinationIdentifier");
    charon_check_unique(identifiers, @"item");
    if ([identifiers containsObject:destination])
        charon_raise_in_list(destination, identifiers, @"INS", 169, @"Invalid update: destination for insertion operation [%@] is in the insertion identifier list for update: %@.");
    id owner = [_owners objectForKey:destination];
    charon_diffable_require(owner != nil, charon_update_file, 298, @"section != NSNotFound");
    NSUInteger section = [_sections indexOfObject:owner], target = 0;
    NSMutableOrderedSet *remaining = [_items[section] mutableCopy];
    [remaining removeObjectsInArray:identifiers];
    target = [remaining indexOfObject:destination] + (after ? 1 : 0);
    [self charon_insertItems:identifiers intoSectionAtIndex:section atIndex:target];
}

- (void)insertItemsWithIdentifiers:(NSArray *)identifiers beforeItemWithIdentifier:(id)itemIdentifier
{
    [self charon_insertItems:identifiers relativeTo:itemIdentifier after:NO];
}

- (void)insertItemsWithIdentifiers:(NSArray *)identifiers afterItemWithIdentifier:(id)itemIdentifier
{
    [self charon_insertItems:identifiers relativeTo:itemIdentifier after:YES];
}

- (void)deleteItemsWithIdentifiers:(NSArray *)identifiers
{
    charon_check_unique(identifiers, @"item");
    for (id item in identifiers)
        [self charon_removeItem:item];
}

- (void)deleteAllItems
{
    [_sections removeAllObjects];
    [_items removeAllObjects];
    [_owners removeAllObjects];
    _generation = [NSUUID UUID].UUIDString;
}

- (void)charon_moveItem:(id)item relativeTo:(id)destination after:(BOOL)after
{
    NSArray *pair = @[item];
    charon_diffable_require(destination != nil, charon_update_file, 529, @"toIdentifier");
    if ([item isEqual:destination])
        charon_raise_in_list(destination, pair, @"MOV", 176, @"Invalid update: destination for item move is the same as the source [%@] for update: %@.");
    id owner = [_owners objectForKey:item];
    charon_diffable_require(owner != nil, charon_update_file, 614, @"fromIndex != NSNotFound");
    id target = [_owners objectForKey:destination];
    charon_diffable_require(target != nil, charon_update_file, 615, @"toIndex != NSNotFound");
    [self charon_insertItems:pair relativeTo:destination after:after];
}

- (void)moveItemWithIdentifier:(id)fromIdentifier beforeItemWithIdentifier:(id)toIdentifier
{
    [self charon_moveItem:fromIdentifier relativeTo:toIdentifier after:NO];
}

- (void)moveItemWithIdentifier:(id)fromIdentifier afterItemWithIdentifier:(id)toIdentifier
{
    [self charon_moveItem:fromIdentifier relativeTo:toIdentifier after:YES];
}

- (void)reloadItemsWithIdentifiers:(NSArray *)identifiers
{
    if (!identifiers)
        return;
    charon_check_unique(identifiers, @"item");
    for (id item in identifiers)
        if (![_owners objectForKey:item])
            charon_diffable_raise(charon_snapshot_file, 377, [NSString stringWithFormat:@"Attempted to reload item identifier that does not exist in the snapshot: %@", item]);
    [_reloadedItems addObjectsFromArray:identifiers];
}

- (void)charon_addSections:(NSArray *)identifiers atIndex:(NSUInteger)position
{
    NSMutableArray *existing = [NSMutableArray array];
    for (id identifier in identifiers)
        if ([_sections containsObject:identifier])
            [existing addObject:identifier];
    if (existing.count)
        charon_diffable_raise(@"_UIDiffableDataSourceHelpers.m", 99, [NSString stringWithFormat:@"Diffable data source detected an attempt to insert or append %lu section identifier%@ that already exist%@ in the snapshot. Identifiers in a snapshot must be unique. Section identifier%@ that already exist%@: %@", (unsigned long)existing.count, existing.count == 1 ? @"" : @"s", existing.count == 1 ? @"s" : @"", existing.count == 1 ? @"" : @"s", existing.count == 1 ? @"s" : @"", existing.count == 1 ? existing[0] : (id)existing]);
    for (id identifier in identifiers) {
        [_sections insertObject:identifier atIndex:position++];
        [_items insertObject:[[NSMutableOrderedSet alloc] init] atIndex:position - 1];
    }
    if (identifiers.count)
        _generation = [NSUUID UUID].UUIDString;
}

- (void)appendSectionsWithIdentifiers:(NSArray *)sectionIdentifiers
{
    charon_diffable_require(sectionIdentifiers != nil, charon_update_file, 129, @"sectionIdentifiers");
    charon_check_unique(sectionIdentifiers, @"section");
    [self charon_addSections:sectionIdentifiers atIndex:_sections.count];
}

- (void)charon_insertSections:(NSArray *)identifiers relativeTo:(id)destination after:(BOOL)after
{
    charon_diffable_require(identifiers != nil, charon_update_file, 119, @"sectionIdentifiers");
    charon_check_unique(identifiers, @"section");
    if (destination && [identifiers containsObject:destination])
        charon_raise_in_list(destination, identifiers, @"INS", 165, @"Invalid update: destination for section operation [%@] is in the inserted section list for update: %@");
    NSUInteger position = _sections.count;
    if (destination) {
        NSUInteger found = [self charon_indexOfSection:destination];
        charon_diffable_require(found != NSNotFound, charon_update_file, 206, @"insertIndex != NSNotFound");
        position = found + (after ? 1 : 0);
    }
    [self charon_addSections:identifiers atIndex:position];
}

- (void)insertSectionsWithIdentifiers:(NSArray *)sectionIdentifiers beforeSectionWithIdentifier:(id)toSectionIdentifier
{
    [self charon_insertSections:sectionIdentifiers relativeTo:toSectionIdentifier after:NO];
}

- (void)insertSectionsWithIdentifiers:(NSArray *)sectionIdentifiers afterSectionWithIdentifier:(id)toSectionIdentifier
{
    [self charon_insertSections:sectionIdentifiers relativeTo:toSectionIdentifier after:YES];
}

- (void)deleteSectionsWithIdentifiers:(NSArray *)sectionIdentifiers
{
    charon_diffable_require(sectionIdentifiers != nil, charon_update_file, 114, @"sectionIdentifiers");
    charon_check_unique(sectionIdentifiers, @"section");
    BOOL changed = NO;
    for (id identifier in sectionIdentifiers) {
        NSUInteger index = [self charon_indexOfSection:identifier];
        if (index == NSNotFound)
            continue;
        for (id item in [_items[index] array])
            [_owners removeObjectForKey:item];
        [_sections removeObjectAtIndex:index];
        [_items removeObjectAtIndex:index];
        changed = YES;
    }
    if (changed)
        _generation = [NSUUID UUID].UUIDString;
}

- (void)charon_moveSection:(id)section relativeTo:(id)destination after:(BOOL)after
{
    charon_diffable_require(section != nil, charon_snapshot_file, after ? 248 : 241, @"fromSectionIdentifier");
    charon_diffable_require(destination != nil, charon_snapshot_file, after ? 249 : 242, @"toSectionIdentifier");
    if ([section isEqual:destination])
        charon_raise_in_list(destination, @[section], @"MOV", 174, @"Invalid update: destination for section move is the same as the source [%@] for update: %@.");
    NSUInteger from = [self charon_indexOfSection:section];
    charon_diffable_require(from != NSNotFound, charon_update_file, 560, @"fromSection != NSNotFound");
    NSUInteger to = [self charon_indexOfSection:destination];
    charon_diffable_require(to != NSNotFound, charon_update_file, 561, @"toSection != NSNotFound");
    NSMutableOrderedSet *items = _items[from];
    [_sections removeObjectAtIndex:from];
    [_items removeObjectAtIndex:from];
    to = [self charon_indexOfSection:destination] + (after ? 1 : 0);
    [_sections insertObject:section atIndex:to];
    [_items insertObject:items atIndex:to];
    _generation = [NSUUID UUID].UUIDString;
}

- (void)moveSectionWithIdentifier:(id)fromSectionIdentifier beforeSectionWithIdentifier:(id)toSectionIdentifier
{
    [self charon_moveSection:fromSectionIdentifier relativeTo:toSectionIdentifier after:NO];
}

- (void)moveSectionWithIdentifier:(id)fromSectionIdentifier afterSectionWithIdentifier:(id)toSectionIdentifier
{
    [self charon_moveSection:fromSectionIdentifier relativeTo:toSectionIdentifier after:YES];
}

- (void)reloadSectionsWithIdentifiers:(NSArray *)sectionIdentifiers
{
    charon_diffable_require(sectionIdentifiers != nil, charon_snapshot_file, 255, @"sectionIdentifiers");
    charon_check_unique(sectionIdentifiers, @"section");
    for (id identifier in sectionIdentifiers)
        if ([self charon_indexOfSection:identifier] == NSNotFound)
            charon_diffable_raise(charon_snapshot_file, 374, [NSString stringWithFormat:@"Attempted to reload section identifier that does not exist in the snapshot: %@", identifier]);
    [_reloadedSections addObjectsFromArray:sectionIdentifiers];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSDiffableDataSourceSnapshot class]])
        return NO;
    NSDiffableDataSourceSnapshot *snapshot = other;
    if (![_sections isEqual:snapshot->_sections] || _items.count != snapshot->_items.count)
        return NO;
    for (NSUInteger index = 0; index < _items.count; index++)
        if (![[_items[index] array] isEqual:[snapshot->_items[index] array]])
            return NO;
    return YES;
}

- (NSString *)description
{
    NSMutableArray *counts = [NSMutableArray array];
    for (NSOrderedSet *items in _items)
        [counts addObject:[NSString stringWithFormat:@"%lu", (unsigned long)items.count]];
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@ %p: numberOfSections:%ld numberOfItems:%ld; generation=%@; sectionCounts=<_UIDataSourceSnapshotter: %p; %lu section%@ with item counts: [%@] >", NSStringFromClass([self class]), self, (long)self.numberOfSections, (long)self.numberOfItems, _generation, _sections, (unsigned long)_sections.count, _sections.count == 1 ? @"" : @"s", [counts componentsJoinedByString:@", "]];
    for (NSUInteger index = 0; index < _sections.count; index++) {
        NSMutableArray *names = [NSMutableArray array];
        for (id item in [_items[index] array])
            [names addObject:[NSString stringWithFormat:@"%@", item]];
        [text appendFormat:@"\n[%@: {%@}]", _sections[index], [names componentsJoinedByString:@" "]];
    }
    [text appendString:@">"];
    return text;
}

- (NSArray *)charon_sections
{
    return [_sections array];
}

- (NSUInteger)charon_countInSectionAtIndex:(NSUInteger)index
{
    return [_items[index] count];
}

- (NSArray *)charon_itemsInSectionAtIndex:(NSUInteger)index
{
    return [_items[index] array];
}

- (NSArray *)charon_reloadedItems
{
    return [_reloadedItems array];
}

- (NSArray *)charon_reloadedSections
{
    return [_reloadedSections array];
}

- (NSDiffableDataSourceSnapshot *)charon_copyWithoutReloads
{
    NSDiffableDataSourceSnapshot *copy = [self copy];
    [copy->_reloadedItems removeAllObjects];
    [copy->_reloadedSections removeAllObjects];
    return copy;
}

- (NSIndexPath *)charon_indexPathForItem:(id)item
{
    id owner = item ? [_owners objectForKey:item] : nil;
    if (!owner)
        return nil;
    NSUInteger section = [_sections indexOfObject:owner];
    return [NSIndexPath indexPathForItem:(NSInteger)[_items[section] indexOfObject:item] inSection:(NSInteger)section];
}

- (id)charon_itemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath)
        return nil;
    NSInteger section = indexPath.section, item = indexPath.item;
    if (section < 0 || (NSUInteger)section >= _items.count || item < 0 || (NSUInteger)item >= [_items[(NSUInteger)section] count])
        return nil;
    return _items[(NSUInteger)section][(NSUInteger)item];
}

- (void)charon_replaceItems:(NSArray *)items inSectionAtIndex:(NSUInteger)index
{
    for (id item in [_items[index] array])
        [_owners removeObjectForKey:item];
    NSMutableOrderedSet *replacement = [[NSMutableOrderedSet alloc] init];
    for (id item in items) {
        [self charon_removeItem:item];
        [replacement addObject:item];
        [_owners setObject:_sections[index] forKey:item];
    }
    _items[index] = replacement;
}

@end
