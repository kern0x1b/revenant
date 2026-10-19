#import "RevenantCompositionalLayout.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

static BOOL revenant_same(id a, id b)
{
    return a == b || (a && b && [a isEqual:b]);
}

static NSString *revenant_insets_text(NSDirectionalEdgeInsets insets)
{
    return [NSString stringWithFormat:@"{%g,%g,%g,%g}", (double)insets.top, (double)insets.leading, (double)insets.bottom, (double)insets.trailing];
}

static NSCollectionLayoutEdgeSpacing *revenant_zero_edge_spacing(void)
{
    NSCollectionLayoutSpacing *(^zero)(void) = ^NSCollectionLayoutSpacing *(void) { return [NSCollectionLayoutSpacing fixedSpacing:0]; };
    return [NSCollectionLayoutEdgeSpacing spacingForLeading:zero() top:zero() trailing:zero() bottom:zero()];
}

@implementation NSCollectionLayoutItem {
@private
    NSCollectionLayoutSize *_layoutSize;
    NSDirectionalEdgeInsets _contentInsets;
    NSCollectionLayoutEdgeSpacing *_edgeSpacing;
    NSArray *_supplementaryItems;
    NSString *_identifier;
}

- (instancetype)initRevenantWithSize:(NSCollectionLayoutSize *)size supplementaryItems:(NSArray *)supplementaryItems
{
    if ((self = [super init])) {
        _layoutSize = size;
        _edgeSpacing = revenant_zero_edge_spacing();
        _supplementaryItems = supplementaryItems ? [supplementaryItems copy] : @[];
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
{
    return [[self alloc] initRevenantWithSize:layoutSize supplementaryItems:nil];
}

+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize supplementaryItems:(NSArray<NSCollectionLayoutSupplementaryItem *> *)supplementaryItems
{
    return [[self alloc] initRevenantWithSize:layoutSize supplementaryItems:supplementaryItems];
}

- (NSDirectionalEdgeInsets)contentInsets
{
    return _contentInsets;
}

- (void)setContentInsets:(NSDirectionalEdgeInsets)contentInsets
{
    _contentInsets = contentInsets;
}

- (NSCollectionLayoutEdgeSpacing *)edgeSpacing
{
    return _edgeSpacing;
}

- (void)setEdgeSpacing:(NSCollectionLayoutEdgeSpacing *)edgeSpacing
{
    _edgeSpacing = [edgeSpacing copy];
}

- (NSCollectionLayoutSize *)layoutSize
{
    return _layoutSize;
}

- (NSArray<NSCollectionLayoutSupplementaryItem *> *)supplementaryItems
{
    return _supplementaryItems;
}

- (void)revenant_setSupplementaryItems:(NSArray *)items
{
    _supplementaryItems = [items copy];
}

- (instancetype)revenant_copyWithSize:(NSCollectionLayoutSize *)size
{
    NSCollectionLayoutItem *copy = [self copy];
    copy->_layoutSize = size;
    return copy;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutItem *copy = [[[self class] allocWithZone:zone] init];
    copy->_layoutSize = [_layoutSize copy];
    copy->_contentInsets = _contentInsets;
    copy->_edgeSpacing = [_edgeSpacing copy];
    copy->_supplementaryItems = [_supplementaryItems copy];
    copy->_identifier = _identifier;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (!object || [object class] != [self class])
        return NO;
    NSCollectionLayoutItem *other = object;
    return revenant_same(other->_layoutSize, _layoutSize) && NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(other->_contentInsets, _contentInsets)
        && revenant_same(other->_edgeSpacing, _edgeSpacing) && revenant_same(other->_supplementaryItems, _supplementaryItems);
}

- (NSUInteger)hash
{
    return [_layoutSize hash] * 31 ^ [_edgeSpacing hash] ^ (NSUInteger)(_contentInsets.top + _contentInsets.leading * 3 + _contentInsets.bottom * 5 + _contentInsets.trailing * 7);
}

- (NSString *)revenant_bodyDescription
{
    return [NSString stringWithFormat:@"<%@ %p; name=(null); size=%@;\n\t edgeSpacing=%@;\n\t identfier=%@;\n\t contentInsets=%@>", [self class], self, _layoutSize ?: (id)@"(null)",
                                      _edgeSpacing ?: (id)@"(null)", _identifier ?: @"(null)", revenant_insets_text(_contentInsets)];
}

- (NSString *)description
{
    return [self revenant_bodyDescription];
}

@end

@implementation NSCollectionLayoutSupplementaryItem {
@private
    NSInteger _zIndex;
    NSString *_elementKind;
    NSCollectionLayoutAnchor *_containerAnchor;
    NSCollectionLayoutAnchor *_itemAnchor;
}

- (instancetype)initRevenantWithSize:(NSCollectionLayoutSize *)size elementKind:(NSString *)elementKind containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor
                        itemAnchor:(NSCollectionLayoutAnchor *)itemAnchor
{
    if ((self = [self initRevenantWithSize:size supplementaryItems:nil])) {
        _zIndex = 1;
        _elementKind = [elementKind copy];
        _containerAnchor = containerAnchor;
        _itemAnchor = itemAnchor;
    }
    return self;
}

+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize elementKind:(NSString *)elementKind containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor
{
    return [[self alloc] initRevenantWithSize:layoutSize elementKind:elementKind containerAnchor:containerAnchor itemAnchor:nil];
}

+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize elementKind:(NSString *)elementKind containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor
                                     itemAnchor:(NSCollectionLayoutAnchor *)itemAnchor
{
    return [[self alloc] initRevenantWithSize:layoutSize elementKind:elementKind containerAnchor:containerAnchor itemAnchor:itemAnchor];
}

- (NSInteger)zIndex
{
    return _zIndex;
}

- (void)setZIndex:(NSInteger)zIndex
{
    _zIndex = zIndex;
}

- (NSString *)elementKind
{
    return _elementKind;
}

- (NSCollectionLayoutAnchor *)containerAnchor
{
    return _containerAnchor;
}

- (NSCollectionLayoutAnchor *)itemAnchor
{
    return _itemAnchor;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutSupplementaryItem *copy = [super copyWithZone:zone];
    copy->_zIndex = _zIndex;
    copy->_elementKind = [_elementKind copy];
    copy->_containerAnchor = _containerAnchor;
    copy->_itemAnchor = _itemAnchor;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (![super isEqual:object])
        return NO;
    if (object == self)
        return YES;
    NSCollectionLayoutSupplementaryItem *other = object;
    return other->_zIndex == _zIndex && revenant_same(other->_elementKind, _elementKind) && revenant_same(other->_containerAnchor, _containerAnchor) && revenant_same(other->_itemAnchor, _itemAnchor);
}

- (NSUInteger)hash
{
    return [super hash] ^ [_elementKind hash] * 13 ^ (NSUInteger)_zIndex;
}

@end

@implementation NSCollectionLayoutBoundarySupplementaryItem {
@private
    BOOL _extendsBoundary;
    BOOL _pinToVisibleBounds;
    NSRectAlignment _alignment;
    CGPoint _offset;
}

- (instancetype)initRevenantWithSize:(NSCollectionLayoutSize *)size elementKind:(NSString *)elementKind alignment:(NSRectAlignment)alignment offset:(CGPoint)offset
{
    if ((self = [super initRevenantWithSize:size elementKind:elementKind containerAnchor:nil itemAnchor:nil])) {
        _extendsBoundary = YES;
        _alignment = alignment;
        _offset = offset;
    }
    return self;
}

+ (instancetype)boundarySupplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize elementKind:(NSString *)elementKind alignment:(NSRectAlignment)alignment
{
    return [[self alloc] initRevenantWithSize:layoutSize elementKind:elementKind alignment:alignment offset:CGPointZero];
}

+ (instancetype)boundarySupplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize elementKind:(NSString *)elementKind alignment:(NSRectAlignment)alignment
                                         absoluteOffset:(CGPoint)absoluteOffset
{
    return [[self alloc] initRevenantWithSize:layoutSize elementKind:elementKind alignment:alignment offset:absoluteOffset];
}

- (BOOL)extendsBoundary
{
    return _extendsBoundary;
}

- (void)setExtendsBoundary:(BOOL)extendsBoundary
{
    _extendsBoundary = extendsBoundary;
}

- (BOOL)pinToVisibleBounds
{
    return _pinToVisibleBounds;
}

- (void)setPinToVisibleBounds:(BOOL)pinToVisibleBounds
{
    _pinToVisibleBounds = pinToVisibleBounds;
}

- (NSRectAlignment)alignment
{
    return _alignment;
}

- (CGPoint)offset
{
    return _offset;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutBoundarySupplementaryItem *copy = [super copyWithZone:zone];
    copy->_extendsBoundary = _extendsBoundary;
    copy->_pinToVisibleBounds = _pinToVisibleBounds;
    copy->_alignment = _alignment;
    copy->_offset = _offset;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (![super isEqual:object])
        return NO;
    if (object == self)
        return YES;
    NSCollectionLayoutBoundarySupplementaryItem *other = object;
    return other->_extendsBoundary == _extendsBoundary && other->_pinToVisibleBounds == _pinToVisibleBounds && other->_alignment == _alignment && CGPointEqualToPoint(other->_offset, _offset);
}

@end

@implementation NSCollectionLayoutDecorationItem {
@private
    NSInteger _zIndex;
    NSString *_elementKind;
}

- (instancetype)initRevenantWithElementKind:(NSString *)elementKind
{
    NSCollectionLayoutDimension *(^whole)(BOOL) = ^NSCollectionLayoutDimension *(BOOL width) {
        return width ? [NSCollectionLayoutDimension fractionalWidthDimension:1] : [NSCollectionLayoutDimension fractionalHeightDimension:1];
    };
    if ((self = [self initRevenantWithSize:[NSCollectionLayoutSize sizeWithWidthDimension:whole(YES) heightDimension:whole(NO)] supplementaryItems:nil])) {
        self.edgeSpacing = nil;
        _elementKind = [elementKind copy];
    }
    return self;
}

+ (instancetype)backgroundDecorationItemWithElementKind:(NSString *)elementKind
{
    return [[self alloc] initRevenantWithElementKind:elementKind];
}

- (NSInteger)zIndex
{
    return _zIndex;
}

- (void)setZIndex:(NSInteger)zIndex
{
    _zIndex = zIndex;
}

- (NSString *)elementKind
{
    return _elementKind;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutDecorationItem *copy = [super copyWithZone:zone];
    copy->_zIndex = _zIndex;
    copy->_elementKind = [_elementKind copy];
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (![super isEqual:object])
        return NO;
    if (object == self)
        return YES;
    NSCollectionLayoutDecorationItem *other = object;
    return other->_zIndex == _zIndex && revenant_same(other->_elementKind, _elementKind);
}

@end

@implementation NSCollectionLayoutGroup {
@private
    RevenantGroupDirection _direction;
    NSArray *_subitems;
    NSCollectionLayoutSpacing *_interItemSpacing;
    NSInteger _repeatCount;
    NSCollectionLayoutGroupCustomItemProvider _provider;
}

- (instancetype)initRevenantWithSize:(NSCollectionLayoutSize *)size direction:(RevenantGroupDirection)direction subitems:(NSArray *)subitems count:(NSInteger)count
                          provider:(NSCollectionLayoutGroupCustomItemProvider)provider
{
    if ((self = [super initRevenantWithSize:size supplementaryItems:nil])) {
        _direction = direction;
        _subitems = subitems ? [[NSArray alloc] initWithArray:subitems copyItems:YES] : @[];
        _interItemSpacing = [NSCollectionLayoutSpacing fixedSpacing:0];
        _repeatCount = count;
        _provider = [provider copy];
    }
    return self;
}

+ (instancetype)groupWithSize:(NSCollectionLayoutSize *)size direction:(RevenantGroupDirection)direction subitems:(NSArray *)subitems
{
    if (!size)
        [NSException raise:NSInternalInconsistencyException format:@"A size is required."];
    if (subitems.count == 0)
        [NSException raise:NSInternalInconsistencyException format:@"At least 1 subitem is required for a group"];
    return [[self alloc] initRevenantWithSize:size direction:direction subitems:subitems count:0 provider:nil];
}

+ (instancetype)repeatingGroupWithSize:(NSCollectionLayoutSize *)size direction:(RevenantGroupDirection)direction subitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    BOOL horizontal = direction == RevenantGroupDirectionHorizontal;
    if (!size)
        [NSException raise:NSInternalInconsistencyException format:@"A size is required."];
    if (count < 1)
        [NSException raise:NSInternalInconsistencyException format:@"A repeating %@ group should specify a count >= 1", horizontal ? @"horizontal" : @"vertical"];
    NSArray *held = @[subitem];
    NSCollectionLayoutSize *itemSize = subitem.layoutSize;
    NSCollectionLayoutDimension *share = horizontal ? [NSCollectionLayoutDimension fractionalWidthDimension:1.0 / count] : [NSCollectionLayoutDimension fractionalHeightDimension:1.0 / count];
    NSCollectionLayoutSize *resized = horizontal ? [NSCollectionLayoutSize sizeWithWidthDimension:share heightDimension:itemSize.heightDimension]
                                                 : [NSCollectionLayoutSize sizeWithWidthDimension:itemSize.widthDimension heightDimension:share];
    NSCollectionLayoutItem *only = [held.firstObject revenant_copyWithSize:resized];
    return [[self alloc] initRevenantWithSize:size direction:direction subitems:@[only] count:count provider:nil];
}

+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitems:(NSArray<NSCollectionLayoutItem *> *)subitems
{
    return [self groupWithSize:layoutSize direction:RevenantGroupDirectionHorizontal subitems:subitems];
}

+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitems:(NSArray<NSCollectionLayoutItem *> *)subitems
{
    return [self groupWithSize:layoutSize direction:RevenantGroupDirectionVertical subitems:subitems];
}

+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    return [self repeatingGroupWithSize:layoutSize direction:RevenantGroupDirectionHorizontal subitem:subitem count:count];
}

+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count
{
    return [self repeatingGroupWithSize:layoutSize direction:RevenantGroupDirectionVertical subitem:subitem count:count];
}

+ (instancetype)customGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize itemProvider:(NSCollectionLayoutGroupCustomItemProvider)itemProvider
{
    if (!layoutSize)
        [NSException raise:NSInternalInconsistencyException format:@"A size is required."];
    if (!itemProvider)
        [NSException raise:NSInternalInconsistencyException format:@"At least 1 subitem is required for a group"];
    return [[self alloc] initRevenantWithSize:layoutSize direction:RevenantGroupDirectionCustom subitems:nil count:0 provider:itemProvider];
}

- (NSArray<NSCollectionLayoutSupplementaryItem *> *)supplementaryItems
{
    return [super supplementaryItems];
}

- (void)setSupplementaryItems:(NSArray<NSCollectionLayoutSupplementaryItem *> *)supplementaryItems
{
    [self revenant_setSupplementaryItems:supplementaryItems];
}

- (NSCollectionLayoutSpacing *)interItemSpacing
{
    return _interItemSpacing;
}

- (void)setInterItemSpacing:(NSCollectionLayoutSpacing *)interItemSpacing
{
    _interItemSpacing = [interItemSpacing copy];
}

- (NSArray<NSCollectionLayoutItem *> *)subitems
{
    return _subitems;
}

- (RevenantGroupDirection)revenant_direction
{
    return _direction;
}

- (NSInteger)revenant_repeatCount
{
    return _repeatCount;
}

- (NSCollectionLayoutGroupCustomItemProvider)revenant_itemProvider
{
    return _provider;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutGroup *copy = [super copyWithZone:zone];
    copy->_direction = _direction;
    copy->_subitems = [[NSArray alloc] initWithArray:_subitems copyItems:YES];
    copy->_interItemSpacing = [_interItemSpacing copy];
    copy->_repeatCount = _repeatCount;
    copy->_provider = [_provider copy];
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (![super isEqual:object])
        return NO;
    if (object == self)
        return YES;
    NSCollectionLayoutGroup *other = object;
    return other->_direction == _direction && [other->_subitems isEqual:_subitems] && revenant_same(other->_interItemSpacing, _interItemSpacing) && other->_repeatCount == _repeatCount;
}

- (NSUInteger)hash
{
    return [super hash] ^ [_subitems hash] * 17 ^ (NSUInteger)_direction;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithString:[self revenant_bodyDescription]];
    [text appendString:@"\n\t group: subitems="];
    for (NSCollectionLayoutItem *subitem in _subitems)
        [text appendFormat:@"\n\t\t %@", [[subitem description] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    [text appendFormat:@"\n\t interItemSpacing=%@;\n\t layoutDirection=.%@>", _interItemSpacing ?: (id)@"(null)", _direction == RevenantGroupDirectionHorizontal ? @"horizontal" : @"vertical"];
    return text;
}

@end

static NSString *revenant_orthogonal_text(NSInteger behavior)
{
    switch (behavior) {
    case 0:
        return @"None";
    case 1:
        return @"Continuous";
    case 2:
        return @"Continuous Group Leading Boundary";
    case 3:
        return @"Paging";
    case 4:
        return @"Group Paging";
    case 5:
        return @"Group Paging Centered";
    }
    return [NSString stringWithFormat:@"(unknown value: %ld)", (long)behavior];
}

@implementation NSCollectionLayoutSection {
@private
    NSCollectionLayoutGroup *_group;
    NSDirectionalEdgeInsets _contentInsets;
    CGFloat _interGroupSpacing;
    UICollectionLayoutSectionOrthogonalScrollingBehavior _orthogonalScrollingBehavior;
    NSArray *_boundarySupplementaryItems;
    NSCollectionLayoutSectionVisibleItemsInvalidationHandler _handler;
    NSArray *_decorationItems;
    BOOL _supplementariesFollowContentInsets;
    NSInteger _contentInsetsReference;
    NSInteger _supplementaryContentInsetsReference;
}

@dynamic contentInsetsReference;

+ (instancetype)sectionWithGroup:(NSCollectionLayoutGroup *)group
{
    if (!group)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: group"];
    NSCollectionLayoutSection *section = [[self alloc] init];
    section->_group = [group copy];
    section->_boundarySupplementaryItems = @[];
    section->_decorationItems = @[];
    section->_supplementariesFollowContentInsets = YES;
    return section;
}

- (NSCollectionLayoutGroup *)revenant_group
{
    return _group;
}

- (NSInteger)revenant_contentInsetsReference
{
    return _contentInsetsReference;
}

- (void)revenant_setContentInsetsReference:(NSInteger)reference
{
    _contentInsetsReference = reference;
}

- (NSInteger)revenant_supplementaryContentInsetsReference
{
    return _supplementaryContentInsetsReference;
}

- (NSDirectionalEdgeInsets)contentInsets
{
    return _contentInsets;
}

- (void)setContentInsets:(NSDirectionalEdgeInsets)contentInsets
{
    _contentInsets = contentInsets;
}

- (CGFloat)interGroupSpacing
{
    return _interGroupSpacing;
}

- (void)setInterGroupSpacing:(CGFloat)interGroupSpacing
{
    _interGroupSpacing = interGroupSpacing;
}

- (UICollectionLayoutSectionOrthogonalScrollingBehavior)orthogonalScrollingBehavior
{
    return _orthogonalScrollingBehavior;
}

- (void)setOrthogonalScrollingBehavior:(UICollectionLayoutSectionOrthogonalScrollingBehavior)orthogonalScrollingBehavior
{
    _orthogonalScrollingBehavior = orthogonalScrollingBehavior;
}

- (NSArray<NSCollectionLayoutBoundarySupplementaryItem *> *)boundarySupplementaryItems
{
    return _boundarySupplementaryItems;
}

- (void)setBoundarySupplementaryItems:(NSArray<NSCollectionLayoutBoundarySupplementaryItem *> *)boundarySupplementaryItems
{
    _boundarySupplementaryItems = [boundarySupplementaryItems copy];
}

- (NSCollectionLayoutSectionVisibleItemsInvalidationHandler)visibleItemsInvalidationHandler
{
    return _handler;
}

- (void)setVisibleItemsInvalidationHandler:(NSCollectionLayoutSectionVisibleItemsInvalidationHandler)visibleItemsInvalidationHandler
{
    _handler = [visibleItemsInvalidationHandler copy];
}

- (NSArray<NSCollectionLayoutDecorationItem *> *)decorationItems
{
    return _decorationItems;
}

- (void)setDecorationItems:(NSArray<NSCollectionLayoutDecorationItem *> *)decorationItems
{
    _decorationItems = decorationItems ? [decorationItems copy] : @[];
}

- (BOOL)supplementariesFollowContentInsets
{
    return _supplementariesFollowContentInsets;
}

- (void)setSupplementariesFollowContentInsets:(BOOL)supplementariesFollowContentInsets
{
    if (supplementariesFollowContentInsets && _supplementaryContentInsetsReference != UIContentInsetsReferenceAutomatic)
        [NSException raise:NSInternalInconsistencyException format:@"Mixing supplementariesFollowContentInsets and supplementaryContentInsetsReference is not supported. Please use supplementaryContentInsetsReference and the contentInsets property on the boundary supplementary item to get the desired behavior."];
    _supplementariesFollowContentInsets = supplementariesFollowContentInsets;
}

- (UIContentInsetsReference)supplementaryContentInsetsReference
{
    return (UIContentInsetsReference)_supplementaryContentInsetsReference;
}

- (void)setSupplementaryContentInsetsReference:(UIContentInsetsReference)supplementaryContentInsetsReference
{
    _supplementaryContentInsetsReference = supplementaryContentInsetsReference;
    _supplementariesFollowContentInsets = NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutSection *copy = [[[self class] allocWithZone:zone] init];
    copy->_group = [_group copy];
    copy->_contentInsets = _contentInsets;
    copy->_interGroupSpacing = _interGroupSpacing;
    copy->_orthogonalScrollingBehavior = _orthogonalScrollingBehavior;
    copy->_boundarySupplementaryItems = [_boundarySupplementaryItems copy];
    copy->_handler = [_handler copy];
    copy->_decorationItems = _decorationItems ? [[NSArray alloc] initWithArray:_decorationItems copyItems:YES] : nil;
    copy->_supplementariesFollowContentInsets = _supplementariesFollowContentInsets;
    copy->_contentInsetsReference = _contentInsetsReference;
    copy->_supplementaryContentInsetsReference = _supplementaryContentInsetsReference;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (!object || [object class] != [self class])
        return NO;
    NSCollectionLayoutSection *other = object;
    return revenant_same(other->_group, _group) && NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(other->_contentInsets, _contentInsets) && other->_interGroupSpacing == _interGroupSpacing
        && other->_orthogonalScrollingBehavior == _orthogonalScrollingBehavior && revenant_same(other->_boundarySupplementaryItems, _boundarySupplementaryItems)
        && revenant_same(other->_decorationItems, _decorationItems) && other->_supplementariesFollowContentInsets == _supplementariesFollowContentInsets
        && other->_supplementaryContentInsetsReference == _supplementaryContentInsetsReference;
}

- (NSUInteger)hash
{
    return [_group hash] * 31 ^ (NSUInteger)(_interGroupSpacing * 13) ^ (NSUInteger)_orthogonalScrollingBehavior;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<NSCollectionLayoutSection: %p; group = <%@: %p>", self, _group ? NSStringFromClass([_group class]) : @"(null)", _group];
    if (!NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(_contentInsets, NSDirectionalEdgeInsetsZero))
        [text appendFormat:@"; contentInsets = %@", NSStringFromDirectionalEdgeInsets(_contentInsets)];
    if (!_supplementariesFollowContentInsets)
        [text appendString:@"; supplementariesFollowContentInsets = NO"];
    if (_interGroupSpacing != 0)
        [text appendFormat:@"; interGroupSpacing = %g", (double)_interGroupSpacing];
    if (_orthogonalScrollingBehavior != 0)
        [text appendFormat:@"; orthogonalScrollingBehavior = %@", revenant_orthogonal_text(_orthogonalScrollingBehavior)];
    if (_boundarySupplementaryItems.count > 0)
        [text appendFormat:@"; boundarySupplementaryItems = <%p>", _boundarySupplementaryItems];
    if (_decorationItems.count > 0)
        [text appendFormat:@"; decorationItems = <%p>", _decorationItems];
    [text appendString:@">"];
    return text;
}

@end
