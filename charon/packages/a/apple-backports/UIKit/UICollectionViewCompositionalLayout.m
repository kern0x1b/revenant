#import "CharonCompositionalLayout.h"
#import <objc/runtime.h>

@interface UICollectionViewCompositionalLayout (CharonSectionNoting)
- (void)charon_beginNotingSections;
- (void)charon_noteSection:(NSCollectionLayoutSection *)section;
@end

#pragma clang diagnostic ignored "-Wincomplete-implementation"

static const NSInteger CharonBoundaryIndexMax = NSIntegerMax;
static const NSInteger CharonPinnedZIndex = 1000000000;

@interface CharonCollectionLayoutContainer : NSObject <NSCollectionLayoutContainer> {
@private
    CGSize _contentSize;
    NSDirectionalEdgeInsets _insets;
}
- (instancetype)initWithContentSize:(CGSize)size insets:(NSDirectionalEdgeInsets)insets;
@end

@implementation CharonCollectionLayoutContainer

- (instancetype)initWithContentSize:(CGSize)size insets:(NSDirectionalEdgeInsets)insets
{
    if ((self = [super init])) {
        _contentSize = size;
        _insets = insets;
    }
    return self;
}

- (CGSize)contentSize
{
    return _contentSize;
}

- (CGSize)effectiveContentSize
{
    return CGSizeMake(_contentSize.width - _insets.leading - _insets.trailing, _contentSize.height - _insets.top - _insets.bottom);
}

- (NSDirectionalEdgeInsets)contentInsets
{
    return _insets;
}

- (NSDirectionalEdgeInsets)effectiveContentInsets
{
    return _insets;
}

@end

@interface CharonCollectionLayoutEnvironment : NSObject <NSCollectionLayoutEnvironment> {
@private
    id<NSCollectionLayoutContainer> _container;
    UITraitCollection *_traitCollection;
}
- (instancetype)initWithContainer:(id<NSCollectionLayoutContainer>)container traitCollection:(UITraitCollection *)traitCollection;
@end

@implementation CharonCollectionLayoutEnvironment

- (instancetype)initWithContainer:(id<NSCollectionLayoutContainer>)container traitCollection:(UITraitCollection *)traitCollection
{
    if ((self = [super init])) {
        _container = container;
        _traitCollection = traitCollection;
    }
    return self;
}

- (id<NSCollectionLayoutContainer>)container
{
    return _container;
}

- (UITraitCollection *)traitCollection
{
    return _traitCollection;
}

@end

@implementation UICollectionViewCompositionalLayoutConfiguration {
@private
    UICollectionViewScrollDirection _scrollDirection;
    CGFloat _interSectionSpacing;
    NSArray *_boundarySupplementaryItems;
    NSInteger _contentInsetsReference;
}

@dynamic contentInsetsReference;

- (instancetype)init
{
    if ((self = [super init])) {
        _boundarySupplementaryItems = @[];
        _contentInsetsReference = 2;
    }
    return self;
}

- (UICollectionViewScrollDirection)scrollDirection
{
    return _scrollDirection;
}

- (void)setScrollDirection:(UICollectionViewScrollDirection)scrollDirection
{
    _scrollDirection = scrollDirection;
}

- (CGFloat)interSectionSpacing
{
    return _interSectionSpacing;
}

- (void)setInterSectionSpacing:(CGFloat)interSectionSpacing
{
    _interSectionSpacing = interSectionSpacing;
}

- (NSArray<NSCollectionLayoutBoundarySupplementaryItem *> *)boundarySupplementaryItems
{
    return _boundarySupplementaryItems;
}

- (void)setBoundarySupplementaryItems:(NSArray<NSCollectionLayoutBoundarySupplementaryItem *> *)boundarySupplementaryItems
{
    _boundarySupplementaryItems = [boundarySupplementaryItems copy];
}

- (NSInteger)charon_contentInsetsReference
{
    return _contentInsetsReference;
}

- (void)charon_setContentInsetsReference:(NSInteger)reference
{
    _contentInsetsReference = reference;
}

- (id)copyWithZone:(NSZone *)zone
{
    UICollectionViewCompositionalLayoutConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy->_scrollDirection = _scrollDirection;
    copy->_interSectionSpacing = _interSectionSpacing;
    copy->_boundarySupplementaryItems = [_boundarySupplementaryItems copy];
    copy->_contentInsetsReference = _contentInsetsReference;
    return copy;
}

@end

#pragma mark - Solving

@implementation CharonSolvedElement
@end

@implementation CharonSolvedSection
@end

@interface CharonSlot : NSObject {
@public
    NSCollectionLayoutItem *item;
    CGRect slot;
    CGFloat edge;
}
@end

@implementation CharonSlot
@end

@interface CharonLeaf : NSObject {
@public
    CGRect frame;
    NSInteger zIndex;
    NSMutableArray *supplementaries;
    CGPoint slotEdge;
    CGRect owner;
    BOOL estimatedWidth;
    BOOL estimatedHeight;
}
@end

@implementation CharonLeaf
@end

@interface CharonSolver : NSObject {
@public
    CGFloat scale;
    CGSize container;
    BOOL vertical;
    UITraitCollection *traits;
    NSMutableDictionary *counters;
    NSMutableDictionary *customCache;
    NSMutableDictionary *patterns;
    NSInteger sectionIndex;
    NSMutableArray *groupSupplementaries;
    BOOL dry;
    BOOL unfit;
    NSDictionary *measured;
}
@end

@implementation CharonSolver

- (CGFloat)floorPixels:(CGFloat)value
{
    return floor(value * scale + 0.001) / scale;
}

- (CGFloat)roundPixels:(CGFloat)value
{
    return floor(value * scale + 0.5) / scale;
}

- (CGFloat)resolve:(NSCollectionLayoutDimension *)dimension width:(CGFloat)baseWidth height:(CGFloat)baseHeight
{
    if (dimension.isFractionalWidth)
        return [self floorPixels:dimension.dimension * baseWidth];
    if (dimension.isFractionalHeight)
        return [self floorPixels:dimension.dimension * baseHeight];
    return dimension.dimension;
}

static CGFloat charon_spacing_min(NSCollectionLayoutSpacing *spacing)
{
    return spacing ? spacing.spacing : 0;
}

static CGFloat charon_edge_min(NSCollectionLayoutEdgeSpacing *edges, NSInteger edge)
{
    NSCollectionLayoutSpacing *spacing = edge == 0 ? edges.leading : edge == 1 ? edges.top : edge == 2 ? edges.trailing : edges.bottom;
    return charon_spacing_min(spacing);
}

static BOOL charon_edge_flexible(NSCollectionLayoutEdgeSpacing *edges, NSInteger edge)
{
    NSCollectionLayoutSpacing *spacing = edge == 0 ? edges.leading : edge == 1 ? edges.top : edge == 2 ? edges.trailing : edges.bottom;
    return spacing.isFlexibleSpacing;
}

- (void)placeRun:(CGFloat)available count:(NSUInteger)count sizes:(const CGFloat *)sizes leadMin:(const CGFloat *)leadMin trailMin:(const CGFloat *)trailMin
        leadFlex:(const BOOL *)leadFlex trailFlex:(const BOOL *)trailFlex between:(CGFloat)between betweenFlexible:(BOOL)betweenFlexible positions:(CGFloat *)positions
{
    CGFloat fixed = 0;
    NSUInteger flexible = 0;
    for (NSUInteger index = 0; index < count; index++) {
        fixed += sizes[index] + leadMin[index] + trailMin[index];
        flexible += (leadFlex[index] ? 1 : 0) + (trailFlex[index] ? 1 : 0);
        if (index + 1 < count) {
            fixed += between;
            flexible += betweenFlexible ? 1 : 0;
        }
    }
    CGFloat share = flexible > 0 ? (available - fixed) / flexible : 0;
    CGFloat cursor = 0;
    for (NSUInteger index = 0; index < count; index++) {
        cursor += leadMin[index] + (leadFlex[index] ? share : 0);
        positions[index] = cursor;
        cursor += sizes[index] + trailMin[index] + (trailFlex[index] ? share : 0);
        if (index + 1 < count)
            cursor += between + (betweenFlexible ? share : 0);
    }
}

- (NSArray *)patternForGroup:(NSCollectionLayoutGroup *)group inner:(CGSize)inner
{
    NSString *key = [NSString stringWithFormat:@"%p/%g/%g", group, (double)inner.width, (double)inner.height];
    id cached = patterns[key];
    if (cached)
        return cached == [NSNull null] ? nil : cached;
    NSArray *made = [self computePatternForGroup:group inner:inner];
    patterns[key] = made ?: (id)[NSNull null];
    return made;
}

- (NSArray *)computePatternForGroup:(NSCollectionLayoutGroup *)group inner:(CGSize)inner
{
    BOOL horizontal = group.charon_direction == CharonGroupDirectionHorizontal;
    NSArray *subitems = group.subitems;
    NSUInteger cycle = subitems.count;
    if (cycle == 0)
        return nil;
    NSInteger fixedCount = group.charon_repeatCount;
    CGFloat between = charon_spacing_min(group.interItemSpacing);
    BOOL betweenFlexible = group.interItemSpacing.isFlexibleSpacing;
    CGFloat main = horizontal ? inner.width : inner.height;
    CGFloat cross = horizontal ? inner.height : inner.width;
    NSCollectionLayoutDimension *(^mainDimension)(NSCollectionLayoutItem *) = ^NSCollectionLayoutDimension *(NSCollectionLayoutItem *item) {
        return horizontal ? item.layoutSize.widthDimension : item.layoutSize.heightDimension;
    };
    BOOL widthFactorCross = NO;
    for (NSCollectionLayoutItem *item in subitems) {
        NSCollectionLayoutDimension *cross = horizontal ? item.layoutSize.heightDimension : item.layoutSize.widthDimension;
        if (horizontal ? cross.isFractionalWidth : cross.isFractionalHeight)
            widthFactorCross = YES;
    }
    NSUInteger limit = fixedCount > 0 ? (NSUInteger)fixedCount : 512;
    CGFloat (^extent)(NSCollectionLayoutItem *, CGFloat) = ^CGFloat(NSCollectionLayoutItem *item, CGFloat base) {
        return [self resolve:mainDimension(item) width:horizontal ? base : inner.width height:horizontal ? inner.height : base]
             + charon_edge_min(item.edgeSpacing, horizontal ? 0 : 1) + charon_edge_min(item.edgeSpacing, horizontal ? 2 : 3);
    };
    NSUInteger chosen = 0;
    CGFloat base = main;
    BOOL mainEstimated = horizontal ? group.layoutSize.widthDimension.isEstimated : group.layoutSize.heightDimension.isEstimated;
    if (fixedCount == 0 && mainEstimated) {
        chosen = cycle;
        base = MAX(0, main - (chosen - 1) * between);
    } else if (fixedCount > 0) {
        chosen = (NSUInteger)fixedCount;
        base = MAX(0, main - (chosen - 1) * between);
    } else if (!widthFactorCross) {
        for (NSUInteger count = 1; count <= limit; count++) {
            CGFloat candidate = MAX(0, main - (count - 1) * between), total = (count - 1) * between;
            for (NSUInteger index = 0; index < count; index++)
                total += extent(subitems[index % cycle], candidate);
            if (total <= main + 0.001) {
                chosen = count;
            } else {
                if (count == 1)
                    return nil;
                break;
            }
        }
        base = MAX(0, main - (chosen - 1) * between);
    } else {
        NSUInteger capacity = 0;
        CGFloat total = 0;
        while (capacity < limit) {
            CGFloat size = extent(subitems[capacity % cycle], main);
            if (capacity > 0 && total + size > main + 0.001)
                break;
            total += size;
            capacity++;
        }
        base = MAX(0, main - (capacity - 1) * between);
        CGFloat used = 0;
        while (chosen < limit) {
            CGFloat need = extent(subitems[chosen % cycle], base) + (chosen > 0 ? between : 0);
            if (used + need > main + 0.001) {
                if (chosen == 0)
                    return nil;
                break;
            }
            used += need;
            chosen++;
        }
    }
    NSUInteger count = chosen;
    CGFloat *sizes = calloc(count, sizeof(CGFloat)), *crossSizes = calloc(count, sizeof(CGFloat));
    CGFloat *leadMin = calloc(count, sizeof(CGFloat)), *trailMin = calloc(count, sizeof(CGFloat)), *positions = calloc(count, sizeof(CGFloat));
    BOOL *leadFlex = calloc(count, sizeof(BOOL)), *trailFlex = calloc(count, sizeof(BOOL));
    for (NSUInteger index = 0; index < count; index++) {
        NSCollectionLayoutItem *item = subitems[index % cycle];
        NSCollectionLayoutDimension *mainDimension = horizontal ? item.layoutSize.widthDimension : item.layoutSize.heightDimension;
        NSCollectionLayoutDimension *crossDimension = horizontal ? item.layoutSize.heightDimension : item.layoutSize.widthDimension;
        sizes[index] = [self resolve:mainDimension width:horizontal ? base : inner.width height:horizontal ? inner.height : base];
        crossSizes[index] = [self resolve:crossDimension width:horizontal ? base : inner.width height:horizontal ? inner.height : base];
        leadMin[index] = charon_edge_min(item.edgeSpacing, horizontal ? 0 : 1);
        trailMin[index] = charon_edge_min(item.edgeSpacing, horizontal ? 2 : 3);
        leadFlex[index] = charon_edge_flexible(item.edgeSpacing, horizontal ? 0 : 1);
        trailFlex[index] = charon_edge_flexible(item.edgeSpacing, horizontal ? 2 : 3);
    }
    [self placeRun:main count:count sizes:sizes leadMin:leadMin trailMin:trailMin leadFlex:leadFlex trailFlex:trailFlex between:between betweenFlexible:betweenFlexible positions:positions];
    NSMutableArray *slots = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) {
        NSCollectionLayoutItem *item = subitems[index % cycle];
        CGFloat one = crossSizes[index];
        CGFloat crossLead = charon_edge_min(item.edgeSpacing, horizontal ? 1 : 0), crossTrail = charon_edge_min(item.edgeSpacing, horizontal ? 3 : 2);
        BOOL crossLeadFlex = charon_edge_flexible(item.edgeSpacing, horizontal ? 1 : 0), crossTrailFlex = charon_edge_flexible(item.edgeSpacing, horizontal ? 3 : 2);
        CGFloat crossPosition = 0;
        [self placeRun:cross count:1 sizes:&one leadMin:&crossLead trailMin:&crossTrail leadFlex:&crossLeadFlex trailFlex:&crossTrailFlex between:0 betweenFlexible:NO positions:&crossPosition];
        CharonSlot *slot = [[CharonSlot alloc] init];
        slot->item = item;
        CGFloat mainPosition = [self roundPixels:positions[index]];
        crossPosition = [self roundPixels:crossPosition];
        slot->slot = horizontal ? CGRectMake(mainPosition, crossPosition, sizes[index], crossSizes[index]) : CGRectMake(crossPosition, mainPosition, crossSizes[index], sizes[index]);
        slot->edge = positions[index] + sizes[index] + trailMin[index];
        [slots addObject:slot];
    }
    free(sizes);
    free(crossSizes);
    free(leadMin);
    free(trailMin);
    free(positions);
    free(leadFlex);
    free(trailFlex);
    return slots;
}

- (NSArray *)measuredSlots:(NSArray *)slots group:(NSCollectionLayoutGroup *)group horizontal:(BOOL)horizontal first:(NSInteger)first found:(BOOL *)found
{
    for (CharonSlot *slot in slots) {
        if ([slot->item isKindOfClass:[NSCollectionLayoutGroup class]])
            return slots;
    }
    BOOL counted = group.charon_repeatCount > 0;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:slots.count];
    CGFloat shift = 0;
    for (NSUInteger index = 0; index < slots.count; index++) {
        CharonSlot *slot = slots[index];
        CharonSlot *copy = [[CharonSlot alloc] init];
        copy->item = slot->item;
        copy->slot = slot->slot;
        copy->edge = slot->edge;
        NSValue *value = measured[[NSString stringWithFormat:@"%ld/%ld", (long)sectionIndex, (long)(first + (NSInteger)index)]];
        if (horizontal)
            copy->slot.origin.x += shift;
        else
            copy->slot.origin.y += shift;
        if (value) {
            CGSize size = value.CGSizeValue;
            BOOL width = slot->item.layoutSize.widthDimension.isEstimated && !(horizontal && counted);
            BOOL height = slot->item.layoutSize.heightDimension.isEstimated && !(!horizontal && counted);
            if (width) {
                copy->slot.size.width = size.width;
                if (horizontal)
                    shift += size.width - slot->slot.size.width;
            }
            if (height) {
                copy->slot.size.height = size.height;
                if (!horizontal)
                    shift += size.height - slot->slot.size.height;
            }
            *found = *found || width || height;
        }
        [result addObject:copy];
    }
    return result;
}

- (NSString *)counterKey:(NSString *)kind
{
    return [NSString stringWithFormat:@"%ld/%@", (long)sectionIndex, kind];
}

- (CGRect)supplementaryFrame:(NSCollectionLayoutSupplementaryItem *)supplementary relativeTo:(CGRect)frame base:(CGSize)base
{
    NSCollectionLayoutSize *layoutSize = supplementary.layoutSize;
    if (layoutSize.widthDimension.isEstimated || layoutSize.heightDimension.isEstimated)
        charon_layout_say_once(@"estimated-supplementary", @"UICollectionViewCompositionalLayout: a supplementary item of an item or of a group is laid out at its estimate; only the boundary items of a section or the layout are measured.");
    CGFloat width = [self resolve:layoutSize.widthDimension width:base.width height:base.height];
    CGFloat height = [self resolve:layoutSize.heightDimension width:base.width height:base.height];
    NSCollectionLayoutAnchor *containerAnchor = supplementary.containerAnchor, *itemAnchor = supplementary.itemAnchor ?: supplementary.containerAnchor;
    CGPoint containerPoint = containerAnchor ? [containerAnchor charon_anchorPoint] : CGPointMake(0.5, 0.5);
    CGPoint point = CGPointMake(CGRectGetMinX(frame) + containerPoint.x * frame.size.width, CGRectGetMinY(frame) + containerPoint.y * frame.size.height);
    if (containerAnchor) {
        CGPoint offset = containerAnchor.offset;
        point.x += containerAnchor.isAbsoluteOffset ? offset.x : offset.x * width;
        point.y += containerAnchor.isAbsoluteOffset ? offset.y : offset.y * height;
    }
    CGPoint itemPoint = itemAnchor ? [itemAnchor charon_anchorPoint] : CGPointMake(0.5, 0.5);
    CGPoint origin = CGPointMake(point.x - itemPoint.x * width, point.y - itemPoint.y * height);
    if (supplementary.itemAnchor) {
        CGPoint offset = supplementary.itemAnchor.offset;
        origin.x += supplementary.itemAnchor.isAbsoluteOffset ? offset.x : offset.x * width;
        origin.y += supplementary.itemAnchor.isAbsoluteOffset ? offset.y : offset.y * height;
    }
    return CGRectMake(origin.x, origin.y, width, height);
}

- (void)addSupplementaries:(NSArray *)supplementaries anchoredTo:(CGRect)frame base:(CGSize)base into:(NSMutableArray *)out
{
    for (NSCollectionLayoutSupplementaryItem *supplementary in supplementaries) {
        if (![supplementary isKindOfClass:[NSCollectionLayoutSupplementaryItem class]])
            continue;
        CharonSolvedElement *element = [[CharonSolvedElement alloc] init];
        element->category = 1;
        element->kind = supplementary.elementKind;
        element->frame = [self supplementaryFrame:supplementary relativeTo:frame base:base];
        element->zIndex = supplementary.zIndex;
        NSString *key = [self counterKey:supplementary.elementKind ?: @""];
        NSInteger next = [counters[key] integerValue];
        counters[key] = @(next + 1);
        element->indexPath = [NSIndexPath indexPathForItem:next inSection:sectionIndex];
        [out addObject:element];
    }
}

- (CGSize)layoutGroup:(NSCollectionLayoutGroup *)group origin:(CGPoint)origin outer:(CGSize)outer container:(CGSize)containerSize remaining:(NSInteger *)remaining
                items:(NSMutableArray *)items partial:(BOOL *)partial top:(BOOL)top
{
    NSUInteger firstLeaf = items.count;
    NSDirectionalEdgeInsets insets = group.contentInsets;
    CGSize inner = CGSizeMake(MAX(0, outer.width - insets.leading - insets.trailing), MAX(0, outer.height - insets.top - insets.bottom));
    CGPoint innerOrigin = CGPointMake(origin.x + insets.leading, origin.y + insets.top);
    CharonGroupDirection direction = group.charon_direction;
    CGSize actual = outer;
    if (direction == CharonGroupDirectionCustom) {
        NSArray *customItems = [self customItemsForGroup:group outer:outer];
        NSInteger placed = 0;
        for (NSCollectionLayoutGroupCustomItem *custom in customItems) {
            if (*remaining <= 0)
                break;
            CharonLeaf *leaf = [[CharonLeaf alloc] init];
            leaf->frame = CGRectOffset(custom.frame, origin.x, origin.y);
            leaf->slotEdge = CGPointMake(CGRectGetMaxX(leaf->frame), CGRectGetMaxY(leaf->frame));
            leaf->zIndex = custom.zIndex;
            leaf->supplementaries = [NSMutableArray array];
            [items addObject:leaf];
            (*remaining)--;
            placed++;
        }
        if (partial && placed < (NSInteger)customItems.count)
            *partial = YES;
    } else {
        BOOL horizontal = direction == CharonGroupDirectionHorizontal;
        NSArray *slots = [self patternForGroup:group inner:inner];
        if (!slots) {
            unfit = unfit || top;
            return actual;
        }
        BOOL sized = NO;
        BOOL mainEstimatedGroup = horizontal ? group.layoutSize.widthDimension.isEstimated : group.layoutSize.heightDimension.isEstimated;
        if (measured.count > 0 && !dry)
            slots = [self measuredSlots:slots group:group horizontal:horizontal first:(NSInteger)items.count found:&sized];
        CGFloat crossExtent = 0;
        for (CharonSlot *slot in slots)
            crossExtent = MAX(crossExtent, horizontal ? CGRectGetMaxY(slot->slot) : CGRectGetMaxX(slot->slot));
        BOOL crossEstimated = horizontal ? group.layoutSize.heightDimension.isEstimated : group.layoutSize.widthDimension.isEstimated;
        if (crossEstimated) {
            if (horizontal)
                actual.height = crossExtent + insets.top + insets.bottom;
            else
                actual.width = crossExtent + insets.leading + insets.trailing;
        }
        BOOL ran = NO;
        for (CharonSlot *slot in slots) {
            if (*remaining <= 0) {
                ran = YES;
                break;
            }
            NSCollectionLayoutItem *item = slot->item;
            CGRect frame = CGRectOffset(slot->slot, innerOrigin.x, innerOrigin.y);
            if ([item isKindOfClass:[NSCollectionLayoutGroup class]]) {
                BOOL childPartial = NO;
                [self layoutGroup:(NSCollectionLayoutGroup *)item origin:frame.origin outer:frame.size container:inner remaining:remaining items:items partial:&childPartial top:NO];
                if (childPartial)
                    ran = YES;
            } else {
                NSDirectionalEdgeInsets itemInsets = item.contentInsets;
                BOOL estimatedWidth = item.layoutSize.widthDimension.isEstimated, estimatedHeight = item.layoutSize.heightDimension.isEstimated;
                if (estimatedWidth)
                    itemInsets.leading = itemInsets.trailing = 0;
                if (estimatedHeight)
                    itemInsets.top = itemInsets.bottom = 0;
                CGRect body = CGRectMake(frame.origin.x + itemInsets.leading, frame.origin.y + itemInsets.top, fabs(frame.size.width - itemInsets.leading - itemInsets.trailing),
                                         fabs(frame.size.height - itemInsets.top - itemInsets.bottom));
                CharonLeaf *leaf = [[CharonLeaf alloc] init];
                leaf->frame = body;
                leaf->estimatedWidth = estimatedWidth;
                leaf->estimatedHeight = estimatedHeight;
                leaf->slotEdge = CGPointMake(CGRectGetMaxX(body) + charon_edge_min(item.edgeSpacing, 2), CGRectGetMaxY(body) + charon_edge_min(item.edgeSpacing, 3));
                leaf->supplementaries = [NSMutableArray array];
                [items addObject:leaf];
                if (!dry) {
                    for (NSCollectionLayoutSupplementaryItem *supplementary in item.supplementaryItems)
                        [leaf->supplementaries addObject:supplementary];
                }
                (*remaining)--;
            }
        }
        if (mainEstimatedGroup) {
            CGFloat used = 0;
            for (NSUInteger index = firstLeaf; index < items.count; index++) {
                CharonLeaf *leaf = items[index];
                used = MAX(used, horizontal ? leaf->slotEdge.x - innerOrigin.x : leaf->slotEdge.y - innerOrigin.y);
            }
            if (horizontal)
                actual.width = used + insets.leading + insets.trailing;
            else
                actual.height = used + insets.top + insets.bottom;
        }
        if (partial)
            *partial = ran;
        if (ran && top && !mainEstimatedGroup) {
            CGPoint used = CGPointZero, pattern = CGPointZero;
            for (NSUInteger index = firstLeaf; index < items.count; index++) {
                CharonLeaf *leaf = items[index];
                used = CGPointMake(MAX(used.x, leaf->slotEdge.x), MAX(used.y, leaf->slotEdge.y));
            }
            NSMutableArray *scratch = [NSMutableArray array];
            NSInteger unlimited = NSIntegerMax;
            BOOL ignored = NO;
            BOOL saved = dry;
            dry = YES;
            [self layoutGroup:group origin:origin outer:outer container:containerSize remaining:&unlimited items:scratch partial:&ignored top:NO];
            dry = saved;
            for (CharonLeaf *leaf in scratch)
                pattern = CGPointMake(MAX(pattern.x, leaf->slotEdge.x), MAX(pattern.y, leaf->slotEdge.y));
            if (vertical) {
                CGFloat innerUsed = used.y - innerOrigin.y, innerPattern = pattern.y - innerOrigin.y;
                actual.height = innerUsed + (inner.height - innerPattern);
            } else {
                CGFloat innerUsed = used.x - innerOrigin.x, innerPattern = pattern.x - innerOrigin.x;
                actual.width = innerUsed + (inner.width - innerPattern);
            }
        }
    }
    if (!dry) {
        CGRect groupFrame = CGRectMake(origin.x, origin.y, actual.width, actual.height);
        [self addSupplementaries:group.supplementaryItems anchoredTo:groupFrame base:containerSize into:groupSupplementaries];
    }
    return actual;
}

- (NSArray *)customItemsForGroup:(NSCollectionLayoutGroup *)group outer:(CGSize)outer
{
    NSString *key = [NSString stringWithFormat:@"%p", group];
    NSArray *cached = customCache[key];
    if (cached)
        return cached;
    NSDirectionalEdgeInsets insets = group.contentInsets;
    CGSize resolved = [self groupSizeFor:group container:container];
    BOOL estimated = group.layoutSize.widthDimension.isEstimated || group.layoutSize.heightDimension.isEstimated;
    NSDirectionalEdgeInsets shown = estimated ? NSDirectionalEdgeInsetsZero : insets;
    CharonCollectionLayoutContainer *box = [[CharonCollectionLayoutContainer alloc] initWithContentSize:resolved insets:shown];
    CharonCollectionLayoutEnvironment *environment = [[CharonCollectionLayoutEnvironment alloc] initWithContainer:box traitCollection:traits];
    NSCollectionLayoutGroupCustomItemProvider provider = group.charon_itemProvider;
    NSArray *items = provider ? provider(environment) : @[];
    customCache[key] = items ?: @[];
    return customCache[key];
}

- (CGSize)groupSizeFor:(NSCollectionLayoutGroup *)group container:(CGSize)size
{
    NSCollectionLayoutSize *layoutSize = group.layoutSize;
    return CGSizeMake([self resolve:layoutSize.widthDimension width:size.width height:size.height], [self resolve:layoutSize.heightDimension width:size.width height:size.height]);
}


#pragma mark Sections

static void charon_collect_kinds(NSCollectionLayoutItem *item, NSMutableArray *kinds)
{
    for (NSCollectionLayoutSupplementaryItem *supplementary in item.supplementaryItems) {
        if ([supplementary isKindOfClass:[NSCollectionLayoutSupplementaryItem class]] && supplementary.elementKind)
            [kinds addObject:supplementary.elementKind];
    }
    if ([item isKindOfClass:[NSCollectionLayoutGroup class]]) {
        for (NSCollectionLayoutItem *subitem in ((NSCollectionLayoutGroup *)item).subitems)
            charon_collect_kinds(subitem, kinds);
    }
}

static void charon_check_unique_kinds(NSCollectionLayoutSection *section)
{
    NSMutableArray *kinds = [NSMutableArray array];
    for (NSCollectionLayoutBoundarySupplementaryItem *boundary in section.boundarySupplementaryItems) {
        if ([boundary isKindOfClass:[NSCollectionLayoutSupplementaryItem class]] && boundary.elementKind)
            [kinds addObject:boundary.elementKind];
    }
    charon_collect_kinds(section.charon_group, kinds);
    NSMutableArray *seen = [NSMutableArray array], *duplicates = [NSMutableArray array];
    for (NSString *kind in kinds) {
        if ([seen containsObject:kind]) {
            if (![duplicates containsObject:kind])
                [duplicates addObject:kind];
        } else {
            [seen addObject:kind];
        }
    }
    if (duplicates.count > 0)
        [NSException raise:NSInternalInconsistencyException format:@"Error: Every supplementary must have a unique elementKind: duplicates detected: %@", duplicates];
}

typedef struct {
    int horizontal;
    int vertical;
} CharonAlignmentParts;

static CharonAlignmentParts charon_alignment_parts(NSRectAlignment alignment)
{
    switch ((NSInteger)alignment) {
    case 1: return (CharonAlignmentParts){0, -1};
    case 2: return (CharonAlignmentParts){-1, -1};
    case 3: return (CharonAlignmentParts){-1, 0};
    case 4: return (CharonAlignmentParts){-1, 1};
    case 5: return (CharonAlignmentParts){0, 1};
    case 6: return (CharonAlignmentParts){1, 1};
    case 7: return (CharonAlignmentParts){1, 0};
    case 8: return (CharonAlignmentParts){1, -1};
    }
    return (CharonAlignmentParts){2, 2};
}

- (void)placeBoundary:(NSArray *)boundaries in:(CGRect *)regionPointer follow:(BOOL)follow insets:(NSDirectionalEdgeInsets)insets effective:(CGSize)effective
              indexPath:(NSIndexPath *)fixedIndexPath sectionIndex:(NSInteger)section into:(NSMutableArray *)elements extents:(CGFloat *)extents
{
    CGRect region = *regionPointer;
    NSMutableArray *usable = [NSMutableArray array];
    NSMutableArray *sizes = [NSMutableArray array];
    for (NSCollectionLayoutBoundarySupplementaryItem *boundary in boundaries) {
        if (![boundary isKindOfClass:[NSCollectionLayoutBoundarySupplementaryItem class]])
            continue;
        CGFloat baseWidth = vertical ? (follow ? effective.width : container.width) : container.width;
        CGFloat baseHeight = vertical ? container.height : (follow ? effective.height : container.height);
        NSCollectionLayoutSize *layoutSize = boundary.layoutSize;
        CGSize size = CGSizeMake([self resolve:layoutSize.widthDimension width:baseWidth height:baseHeight], [self resolve:layoutSize.heightDimension width:baseWidth height:baseHeight]);
        CharonAlignmentParts parts = charon_alignment_parts(boundary.alignment);
        NSIndexPath *boundaryPath = fixedIndexPath ?: [NSIndexPath indexPathForItem:0 inSection:section];
        NSValue *known = measured[[NSString stringWithFormat:@"b/%@/%ld/%ld", boundary.elementKind, (long)boundaryPath.section, (long)boundaryPath.item]];
        if (known) {
            if (layoutSize.widthDimension.isEstimated)
                size.width = known.CGSizeValue.width;
            if (layoutSize.heightDimension.isEstimated)
                size.height = known.CGSizeValue.height;
        }
        if (parts.horizontal == 2)
            size = CGSizeZero;
        if (boundary.extendsBoundary && vertical && parts.horizontal != 2 && parts.vertical == 0)
            region.size.height = MAX(region.size.height, size.height);
        if (boundary.extendsBoundary && !vertical && parts.horizontal != 2 && parts.horizontal == 0)
            region.size.width = MAX(region.size.width, size.width);
        [usable addObject:boundary];
        [sizes addObject:[NSValue valueWithCGSize:size]];
    }
    CGFloat extendStart = 0, extendEnd = 0;
    NSMutableArray *placed = [NSMutableArray array];
    for (NSUInteger index = 0; index < usable.count; index++) {
        NSCollectionLayoutBoundarySupplementaryItem *boundary = usable[index];
        CGSize size = [sizes[index] CGSizeValue];
        CGFloat width = size.width, height = size.height;
        CharonAlignmentParts parts = charon_alignment_parts(boundary.alignment);
        CGPoint offset = boundary.offset;
        CGRect frame = CGRectMake(0, 0, 0, 0);
        BOOL extends = boundary.extendsBoundary;
        if (parts.horizontal != 2) {
            frame.size = size;
            if (vertical) {
                CGFloat left = follow ? insets.leading : 0, right = follow ? container.width - insets.trailing : container.width;
                frame.origin.x = (parts.horizontal < 0 ? left : parts.horizontal > 0 ? right - width : (follow ? insets.leading + (effective.width - width) / 2 : (container.width - width) / 2)) + offset.x;
                if (parts.vertical < 0)
                    frame.origin.y = (extends ? CGRectGetMinY(region) - height : CGRectGetMinY(region)) + offset.y;
                else if (parts.vertical > 0)
                    frame.origin.y = (extends ? CGRectGetMaxY(region) : CGRectGetMaxY(region) - height) + offset.y;
                else
                    frame.origin.y = CGRectGetMinY(region) + (region.size.height - height) / 2 + offset.y;
                if (extends && parts.vertical != 0) {
                    extendStart = MAX(extendStart, CGRectGetMinY(region) - frame.origin.y);
                    extendEnd = MAX(extendEnd, CGRectGetMaxY(frame) - CGRectGetMaxY(region));
                }
            } else {
                CGFloat top = follow ? insets.top : 0, bottom = follow ? container.height - insets.bottom : container.height;
                frame.origin.y = (parts.vertical < 0 ? top : parts.vertical > 0 ? bottom - height : (follow ? insets.top + (effective.height - height) / 2 : (container.height - height) / 2)) + offset.y;
                if (parts.horizontal < 0)
                    frame.origin.x = (extends ? CGRectGetMinX(region) - width : CGRectGetMinX(region)) + offset.x;
                else if (parts.horizontal > 0)
                    frame.origin.x = (extends ? CGRectGetMaxX(region) : CGRectGetMaxX(region) - width) + offset.x;
                else
                    frame.origin.x = CGRectGetMinX(region) + (region.size.width - width) / 2 + offset.x;
                if (extends && parts.horizontal != 0) {
                    extendStart = MAX(extendStart, CGRectGetMinX(region) - frame.origin.x);
                    extendEnd = MAX(extendEnd, CGRectGetMaxX(frame) - CGRectGetMaxX(region));
                }
            }
        }
        CharonSolvedElement *element = [[CharonSolvedElement alloc] init];
        element->category = 1;
        element->kind = boundary.elementKind;
        element->frame = frame;
        element->zIndex = boundary.zIndex;
        element->alignment = boundary.alignment;
        element->pinned = boundary.pinToVisibleBounds && (vertical ? parts.vertical != 0 && parts.vertical != 2 : parts.horizontal != 0 && parts.horizontal != 2);
        element->indexPath = fixedIndexPath ?: [NSIndexPath indexPathForItem:0 inSection:section];
        if (parts.horizontal != 2) {
            element->estimatedWidth = boundary.layoutSize.widthDimension.isEstimated;
            element->estimatedHeight = boundary.layoutSize.heightDimension.isEstimated;
        }
        [placed addObject:element];
    }
    for (CharonSolvedElement *element in placed) {
        CharonAlignmentParts parts = charon_alignment_parts(element->alignment);
        if (!element->pinned)
            continue;
        BOOL leading = vertical ? parts.vertical < 0 : parts.horizontal < 0;
        CGFloat size = vertical ? element->frame.size.height : element->frame.size.width;
        CGFloat start = vertical ? CGRectGetMinY(region) : CGRectGetMinX(region), end = vertical ? CGRectGetMaxY(region) : CGRectGetMaxX(region);
        element->pinLow = leading ? start - extendStart : start;
        element->pinHigh = (leading ? end : end + extendEnd) - size;
    }
    [elements addObjectsFromArray:placed];
    *regionPointer = region;
    extents[0] = extendStart;
    extents[1] = extendEnd;
}

- (CharonSolvedSection *)solveSection:(NSCollectionLayoutSection *)definition index:(NSInteger)section itemCount:(NSInteger)itemCount
{
    if (!definition || !definition.charon_group)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid section definition. Please specify a valid section definition when content is to be rendered for a section. This is a client error."];
    charon_check_unique_kinds(definition);
    BOOL restoreVertical = vertical;
    BOOL orthogonal = definition.orthogonalScrollingBehavior != UICollectionLayoutSectionOrthogonalScrollingBehaviorNone && vertical;
    if (definition.orthogonalScrollingBehavior != UICollectionLayoutSectionOrthogonalScrollingBehaviorNone && !vertical)
        charon_layout_say_once(@"orthogonal", @"UICollectionViewCompositionalLayout: a section that scrolls across a layout that scrolls sideways is laid out as an ordinary section.");
    NSArray *boundaries = definition.boundarySupplementaryItems;
    if (itemCount == 0 && boundaries.count == 0)
        return nil;
    sectionIndex = section;
    if (orthogonal)
        vertical = NO;
    NSDirectionalEdgeInsets insets = definition.contentInsets;
    CGSize effective = CGSizeMake(container.width - insets.leading - insets.trailing, container.height - insets.top - insets.bottom);
    CGSize groupContainer = vertical ? CGSizeMake(effective.width, container.height) : CGSizeMake(container.width, effective.height);
    NSCollectionLayoutGroup *group = definition.charon_group;
    NSMutableArray *itemLeaves = [NSMutableArray array];
    unfit = NO;
    groupSupplementaries = [NSMutableArray array];
    customCache = [NSMutableDictionary dictionary];
    patterns = [NSMutableDictionary dictionary];
    counters = [NSMutableDictionary dictionary];
    CGFloat mainStart = vertical ? insets.top : insets.leading;
    CGFloat cursor = mainStart;
    NSInteger remaining = itemCount, groups = 0;
    CGFloat widest = 0;
    NSMutableArray *leads = [NSMutableArray array], *widths = [NSMutableArray array];
    CGFloat between = definition.interGroupSpacing;
    NSCollectionLayoutEdgeSpacing *edges = group.edgeSpacing;
    while (remaining > 0) {
        CGSize outer = [self groupSizeFor:group container:groupContainer];
        CGFloat one = vertical ? outer.width : outer.height;
        CGFloat crossLead = charon_edge_min(edges, vertical ? 0 : 1), crossTrail = charon_edge_min(edges, vertical ? 2 : 3);
        BOOL crossLeadFlex = charon_edge_flexible(edges, vertical ? 0 : 1), crossTrailFlex = charon_edge_flexible(edges, vertical ? 2 : 3);
        CGFloat crossPosition = 0;
        [self placeRun:vertical ? effective.width : effective.height count:1 sizes:&one leadMin:&crossLead trailMin:&crossTrail leadFlex:&crossLeadFlex trailFlex:&crossTrailFlex between:0
              betweenFlexible:NO positions:&crossPosition];
        CGFloat mainLead = charon_edge_min(edges, vertical ? 1 : 0), mainTrail = charon_edge_min(edges, vertical ? 3 : 2);
        CGPoint origin = vertical ? CGPointMake(insets.leading + [self roundPixels:crossPosition], cursor + mainLead) : CGPointMake(cursor + mainLead, insets.top + [self roundPixels:crossPosition]);
        NSInteger before = remaining;
        BOOL partial = NO;
        NSUInteger firstLeaf = itemLeaves.count;
        NSUInteger firstSupplement = groupSupplementaries.count;
        CGSize actual = [self layoutGroup:group origin:origin outer:outer container:groupContainer remaining:&remaining items:itemLeaves partial:&partial top:YES];
        if (unfit) {
            charon_layout_say_once(@"unfit", @"UICollectionViewCompositionalLayout: a subitem is larger than the group that holds it along the group's own axis, so the section has no items.");
            itemLeaves = [NSMutableArray array];
            groupSupplementaries = [NSMutableArray array];
            remaining = 0;
            groups = 0;
            break;
        }
        if (remaining == before)
            break;
        CGRect groupFrame = CGRectMake(origin.x, origin.y, actual.width, actual.height);
        widest = MAX(widest, vertical ? actual.width : actual.height);
        [leads addObject:@(origin.x - insets.leading)];
        [widths addObject:@(actual.width)];
        for (NSUInteger index = firstLeaf; index < itemLeaves.count; index++)
            ((CharonLeaf *)itemLeaves[index])->owner = groupFrame;
        for (NSUInteger index = firstSupplement; index < groupSupplementaries.count; index++) {
            CharonSolvedElement *supplement = groupSupplementaries[index];
            supplement->hasOwner = YES;
            supplement->owner = groupFrame;
        }
        CGFloat mainSize = vertical ? actual.height : actual.width;
        cursor += mainLead + mainSize + mainTrail + between;
        groups++;
    }
    if (groups == 0 && boundaries.count == 0) {
        vertical = restoreVertical;
        return nil;
    }
    CGFloat contentWidth = groups > 0 ? cursor - between - insets.leading : 0;
    CGFloat rowHeight = widest;
    if (orthogonal) {
        vertical = restoreVertical;
        widest = 0;
        cursor = insets.top + rowHeight + between;
        mainStart = insets.top;
    }
    CGFloat groupsEnd = groups > 0 ? cursor - between : mainStart;
    CGFloat mainSize = groupsEnd + (vertical ? insets.bottom : insets.trailing);
    CGRect region = vertical ? CGRectMake(0, 0, container.width, mainSize) : CGRectMake(0, 0, mainSize, container.height);
    NSMutableArray *elements = [NSMutableArray array];
    CGFloat extents[2] = {0, 0};
    [self placeBoundary:boundaries in:&region follow:definition.supplementariesFollowContentInsets insets:insets effective:effective indexPath:nil sectionIndex:section into:elements extents:extents];
    mainSize = vertical ? region.size.height : region.size.width;
    CGFloat shiftX = vertical ? 0 : extents[0], shiftY = vertical ? extents[0] : 0;
    CGFloat total = MAX(0, extents[0] + mainSize + extents[1]);
    CharonSolvedSection *solved = [[CharonSolvedSection alloc] init];
    solved->section = section;
    solved->crossSize = widest;
    if (orthogonal) {
        solved->orthogonal = YES;
        solved->viewport = CGRectMake(insets.leading, extents[0] + insets.top, effective.width, rowHeight);
        solved->contentWidth = contentWidth;
        solved->groupLeads = leads;
        solved->groupWidths = widths;
        solved->behavior = definition.orthogonalScrollingBehavior;
        solved->handler = [definition.visibleItemsInvalidationHandler copy];
    }
    solved->extent = vertical ? CGRectMake(0, 0, container.width, total) : CGRectMake(0, 0, total, container.height);
    BOOL raised = definition.decorationItems.count > 0;
    NSInteger index = 0;
    NSMutableArray *ordered = [NSMutableArray array];
    for (CharonLeaf *leaf in itemLeaves) {
        CharonSolvedElement *element = [[CharonSolvedElement alloc] init];
        element->category = 0;
        element->frame = CGRectOffset(leaf->frame, shiftX, shiftY);
        element->zIndex = raised ? MAX(1, leaf->zIndex) : leaf->zIndex;
        element->indexPath = [NSIndexPath indexPathForItem:index inSection:section];
        element->hasOwner = YES;
        element->owner = CGRectOffset(leaf->owner, shiftX, shiftY);
        element->scrolls = orthogonal;
        element->estimatedWidth = leaf->estimatedWidth;
        element->estimatedHeight = leaf->estimatedHeight;
        [ordered addObject:element];
        NSMutableArray *found = [NSMutableArray array];
        [self addSupplementaries:leaf->supplementaries anchoredTo:leaf->frame base:leaf->frame.size into:found];
        for (CharonSolvedElement *supplementary in found) {
            supplementary->frame = CGRectOffset(supplementary->frame, shiftX, shiftY);
            supplementary->hasOwner = YES;
            supplementary->owner = element->owner;
            supplementary->scrolls = orthogonal;
            [ordered addObject:supplementary];
        }
        index++;
    }
    for (CharonSolvedElement *supplementary in groupSupplementaries) {
        supplementary->frame = CGRectOffset(supplementary->frame, shiftX, shiftY);
        supplementary->owner = CGRectOffset(supplementary->owner, shiftX, shiftY);
        supplementary->scrolls = orthogonal;
        [ordered addObject:supplementary];
    }
    for (CharonSolvedElement *boundary in elements) {
        boundary->frame = CGRectOffset(boundary->frame, shiftX, shiftY);
        boundary->pinLow += extents[0];
        boundary->pinHigh += extents[0];
        [ordered addObject:boundary];
    }
    NSInteger decorationIndex = 0;
    for (NSCollectionLayoutDecorationItem *decoration in definition.decorationItems) {
        if (![decoration isKindOfClass:[NSCollectionLayoutDecorationItem class]])
            continue;
        NSDirectionalEdgeInsets shown = decoration.contentInsets;
        CharonSolvedElement *element = [[CharonSolvedElement alloc] init];
        element->category = 2;
        element->kind = decoration.elementKind;
        element->frame = CGRectMake(solved->extent.origin.x + shown.leading, solved->extent.origin.y + shown.top, solved->extent.size.width - shown.leading - shown.trailing,
                                    solved->extent.size.height - shown.top - shown.bottom);
        element->zIndex = decoration.zIndex;
        element->indexPath = [NSIndexPath indexPathForItem:decorationIndex++ inSection:section];
        [ordered addObject:element];
    }
    solved->elements = ordered;
    return solved;
}

@end

#pragma mark - The layout

static BOOL charon_touches(CGRect a, CGRect b)
{
    return CGRectGetMinX(a) <= CGRectGetMaxX(b) && CGRectGetMinX(b) <= CGRectGetMaxX(a) && CGRectGetMinY(a) <= CGRectGetMaxY(b) && CGRectGetMinY(b) <= CGRectGetMaxY(a);
}

static BOOL charon_within_owner(CGRect frame, CGRect owner, CGRect clipped)
{
    CGRect shown = CGRectIntersection(frame, owner);
    if (frame.size.width > 0 && frame.size.height > 0)
        return shown.size.width > 0 && shown.size.height > 0 && CGRectIntersectsRect(shown, clipped);
    return charon_touches(shown, owner) && CGRectIntersectsRect(frame, clipped);
}

static BOOL charon_spans(CGRect frame, CGRect rect)
{
    return (CGRectGetMinY(frame) < CGRectGetMinY(rect) && CGRectGetMaxY(frame) > CGRectGetMaxY(rect))
        || (CGRectGetMinX(frame) < CGRectGetMinX(rect) && CGRectGetMaxX(frame) > CGRectGetMaxX(rect));
}

// A workaround for iOS 6's private UICollectionViewData, not a repair, and a crutch on record
// (coordination/crutches.md, "compositional layout answers an element spanning the bounds twice
// on iOS 6"). That object asks the layout which elements a rectangle shows (the bounds cut to the
// content, which is also the rectangle the layout is asked about) and files each answer under the
// pages of its frame's four corners that lie inside that rectangle. An element whose frame reaches
// past both ends of the rectangle has no corner inside it, is filed under no page and never gets a
// view, although the layout returned it; a plain UICollectionViewLayout subclass loses it the same
// way, and that is not repaired here. The object keeps the last attributes it was given for an index
// path and answers with those. That order is undocumented and only measured, so a layout that gives
// a second attributes of the same element first, its frame cut to the rectangle, has the element
// filed and shown at the frame the layout later gave it, and its own public answer names the element
// twice. There is no other public way: the layout can hand the object only its attributes and its
// content size, and the true frames and the true size are what the user sees; PSTCollectionView
// replaces the collection view and is no seam under UICollectionView. Measured on an iPad 2
// (6.1.3), along y and along x, and done for iOS 6 only: no device of 6.0 or 7 to 10 has told
// whether that object loses the element or keeps the last attributes there, so this is not
// widened (facts/UIKit/UICollectionViewCompositionalLayout.md).
static BOOL charon_files_by_pages(void)
{
    return NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1;
}

@implementation UICollectionViewCompositionalLayout {
@private
    NSCollectionLayoutSection *_section;
    UICollectionViewCompositionalLayoutSectionProvider _provider;
    UICollectionViewCompositionalLayoutConfiguration *_configuration;
    NSMutableArray *_solvedSections;
    NSMutableArray *_boundaryElements;
    NSMutableDictionary *_lookup;
    CGSize _contentSize;
    CGFloat _scale;
    BOOL _vertical;
    BOOL _solved;
    BOOL _keepSolution;
    BOOL _boundsOnlyChange;
    BOOL _hasPinned;
    CharonOrthogonalController *_orthogonal;
    NSMutableDictionary *_measured;
    NSMutableDictionary *_measuredAgainst;
    NSMutableDictionary *_pending;
    NSMutableArray *_preferredContexts;
    BOOL _measuring;
    BOOL _applyingPreferred;
    NSUInteger _settleRounds;
}

- (instancetype)initCharonWithSection:(NSCollectionLayoutSection *)section provider:(UICollectionViewCompositionalLayoutSectionProvider)provider
                       configuration:(UICollectionViewCompositionalLayoutConfiguration *)configuration
{
    if ((self = [super init])) {
        _section = [section copy];
        _provider = [provider copy];
        _configuration = [configuration copy] ?: [[UICollectionViewCompositionalLayoutConfiguration alloc] init];
    }
    return self;
}

- (instancetype)initWithSection:(NSCollectionLayoutSection *)section
{
    return [self initCharonWithSection:section provider:nil configuration:nil];
}

- (instancetype)initWithSection:(NSCollectionLayoutSection *)section configuration:(UICollectionViewCompositionalLayoutConfiguration *)configuration
{
    return [self initCharonWithSection:section provider:nil configuration:configuration];
}

- (instancetype)initWithSectionProvider:(UICollectionViewCompositionalLayoutSectionProvider)sectionProvider
{
    return [self initCharonWithSection:nil provider:sectionProvider configuration:nil];
}

- (instancetype)initWithSectionProvider:(UICollectionViewCompositionalLayoutSectionProvider)sectionProvider configuration:(UICollectionViewCompositionalLayoutConfiguration *)configuration
{
    return [self initCharonWithSection:nil provider:sectionProvider configuration:configuration];
}

- (UICollectionViewCompositionalLayoutConfiguration *)configuration
{
    return _configuration;
}

- (void)setConfiguration:(UICollectionViewCompositionalLayoutConfiguration *)configuration
{
    _configuration = [configuration copy] ?: [[UICollectionViewCompositionalLayoutConfiguration alloc] init];
    [self invalidateLayout];
}

- (void)invalidateLayout
{
    // _settleRounds is reset here, not in -prepareLayout: this is the plain invalidation path -
    // a reload, a bounds change, a configuration change - something other than the settle pass's
    // own -invalidateLayoutWithContext:. The settle pass forces _solved = NO too (see below), which
    // makes the next -prepareLayout take the same "real solve" branch this one does; resetting the
    // round counter there as well would mean every settle round's own invalidation resets the
    // counter that is supposed to be counting settle rounds, so the cap would never be reached no
    // matter how many rounds ran.
    if (!_boundsOnlyChange && !_measuring) {
        _measured = [NSMutableDictionary dictionary];
        _measuredAgainst = [NSMutableDictionary dictionary];
    }
    if (_boundsOnlyChange && _solved) {
        _keepSolution = YES;
    } else {
        _solved = NO;
        _keepSolution = NO;
    }
    _boundsOnlyChange = NO;
    _settleRounds = 0;
    [super invalidateLayout];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    CGRect old = self.collectionView.bounds;
    if (!CGSizeEqualToSize(old.size, newBounds.size))
        return YES;
    if (_hasPinned && !CGPointEqualToPoint(old.origin, newBounds.origin)) {
        _boundsOnlyChange = YES;
        return YES;
    }
    return NO;
}

- (CGFloat)screenScale
{
    UIScreen *screen = self.collectionView.window.screen ?: [UIScreen mainScreen];
    return screen.scale > 0 ? screen.scale : 1;
}

- (void)prepareLayout
{
    [super prepareLayout];
    UICollectionView *view = self.collectionView;
    if (_keepSolution && _solved) {
        _keepSolution = NO;
        return;
    }
    _keepSolution = NO;
    _solved = NO;
    _solvedSections = [NSMutableArray array];
    _boundaryElements = [NSMutableArray array];
    _lookup = [NSMutableDictionary dictionary];
    _hasPinned = NO;
    _contentSize = CGSizeZero;
    if (!view)
        return;
    [self charon_solveView:view];
}

- (void)charon_solveView:(UICollectionView *)view
{
    CharonSolver *solver = [[CharonSolver alloc] init];
    solver->measured = _measured;
    solver->scale = _scale = [self screenScale];
    solver->container = view.bounds.size;
    solver->vertical = _vertical = _configuration.scrollDirection == UICollectionViewScrollDirectionVertical;
    solver->traits = [view respondsToSelector:@selector(traitCollection)] ? view.traitCollection : nil;
    CharonCollectionLayoutContainer *box = [[CharonCollectionLayoutContainer alloc] initWithContentSize:view.bounds.size insets:NSDirectionalEdgeInsetsZero];
    CharonCollectionLayoutEnvironment *environment = [[CharonCollectionLayoutEnvironment alloc] initWithContainer:box traitCollection:solver->traits];
    NSInteger sections = view.numberOfSections;
    [self charon_beginNotingSections];
    CGFloat spacing = _configuration.interSectionSpacing;
    CGFloat cursor = 0;
    CGSize whole = view.bounds.size;
    for (NSInteger section = 0; section < sections; section++) {
        NSCollectionLayoutSection *definition = _section ?: (_provider ? _provider(section, environment) : nil);
        [self charon_noteSection:definition];
        NSInteger count = [view numberOfItemsInSection:section];
        NSInteger reference = definition ? definition.charon_contentInsetsReference : 0;
        CGFloat before = 0, after = 0;
        [self referenceInsets:reference == 0 ? _configuration.charon_contentInsetsReference : reference lead:&before trail:&after];
        solver->container = _vertical ? CGSizeMake(whole.width - before - after, whole.height) : CGSizeMake(whole.width, whole.height - before - after);
        CharonSolvedSection *solved = (definition || count > 0) ? [solver solveSection:definition index:section itemCount:count] : nil;
        CGFloat extent = 0;
        if (solved) {
            [self shiftCross:solved by:before];
            extent = _vertical ? solved->extent.size.height : solved->extent.size.width;
            [self shiftSolved:solved by:cursor];
            [_solvedSections addObject:solved];
        }
        cursor += extent + (section + 1 < sections ? spacing : 0);
    }
    CGFloat total = cursor;
    CGRect region = _vertical ? CGRectMake(0, 0, view.bounds.size.width, total) : CGRectMake(0, 0, total, view.bounds.size.height);
    CGFloat extents[2] = {0, 0};
    NSMutableArray *outer = [NSMutableArray array];
    solver->sectionIndex = 0;
    solver->container = whole;
    [solver placeBoundary:_configuration.boundarySupplementaryItems in:&region follow:NO insets:NSDirectionalEdgeInsetsZero effective:view.bounds.size
                indexPath:[NSIndexPath indexPathForItem:CharonBoundaryIndexMax inSection:0] sectionIndex:0 into:outer extents:extents];
    total = _vertical ? region.size.height : region.size.width;
    CGFloat shift = extents[0];
    if (shift > 0) {
        for (CharonSolvedSection *solved in _solvedSections)
            [self shiftSolved:solved by:shift];
    }
    total += extents[0] + extents[1];
    for (CharonSolvedElement *element in outer) {
        element->frame = _vertical ? CGRectOffset(element->frame, 0, shift) : CGRectOffset(element->frame, shift, 0);
        element->pinLow += shift;
        element->pinHigh += shift;
        [_boundaryElements addObject:element];
    }
    for (CharonSolvedSection *solved in _solvedSections) {
        for (CharonSolvedElement *element in solved->elements) {
            element->frame = [self settled:element];
            _hasPinned = _hasPinned || element->pinned;
            [self record:element];
        }
    }
    for (CharonSolvedElement *element in _boundaryElements) {
        element->frame = [self settled:element];
        _hasPinned = _hasPinned || element->pinned;
        [self record:element];
    }
    CGFloat cross = _vertical ? view.bounds.size.width : view.bounds.size.height;
    for (CharonSolvedSection *solved in _solvedSections)
        cross = MAX(cross, solved->crossSize);
    _contentSize = _vertical ? CGSizeMake([self roundedPixels:cross], [self roundedPixels:total]) : CGSizeMake([self roundedPixels:total], [self roundedPixels:cross]);
    _solved = YES;
    BOOL any = NO;
    for (CharonSolvedSection *solved in _solvedSections)
        any = any || solved->orthogonal;
    if (any && !_orthogonal)
        _orthogonal = [[CharonOrthogonalController alloc] initWithLayout:self];
    [_orthogonal updateSections:_solvedSections view:view environment:environment];
}

- (void)charon_note:(CharonSolvedElement *)element attributes:(UICollectionViewLayoutAttributes *)attributes
{
    if (_measuring || element->category == 2 || !(element->estimatedWidth || element->estimatedHeight))
        return;
    BOOL cell = element->category == 0;
    NSString *key = [NSString stringWithFormat:@"%d/%@/%ld/%ld", cell ? 0 : 1, cell ? @"" : element->kind, (long)element->indexPath.section, (long)element->indexPath.item];
    if (!_pending) {
        // A settle round that never converges would otherwise keep rescheduling itself forever,
        // each round competing with whatever else is queued on the main thread for a turn; this
        // caps it at a round count no legitimate self-sizing pass has been seen to need, rather
        // than trusting every future layout (in particular an orthogonal-scrolling one, the
        // configuration this bound exists for) to always settle.
        if (_settleRounds >= 12) {
            charon_layout_say_once(@"compositional-settle-rounds", @"NSCollectionLayoutSection: self-sizing did not settle within 12 rounds; keeping the last estimate instead of measuring further");
            return;
        }
        _settleRounds++;
        _pending = [NSMutableDictionary dictionary];
        charon_layout_perform(self, ^(UICollectionViewLayout *layout) {
            [(UICollectionViewCompositionalLayout *)layout charon_settleLater];
        });
    }
    _pending[key] = @{@"path" : element->indexPath, @"kind" : cell ? @"" : element->kind, @"cell" : @(cell), @"frame" : [NSValue valueWithCGRect:attributes.frame]};
}

- (UICollectionReusableView *)charon_shownSupplementaryOfKind:(NSString *)kind frame:(CGRect)frame
{
    UICollectionReusableView *best = nil;
    CGFloat distance = CGFLOAT_MAX;
    for (UIView *sub in self.collectionView.subviews) {
        if (![sub isKindOfClass:[UICollectionReusableView class]] || [sub isKindOfClass:[UICollectionViewCell class]])
            continue;
        CGFloat d = fabs(sub.frame.origin.x - frame.origin.x) + fabs(sub.frame.origin.y - frame.origin.y) + fabs(sub.frame.size.width - frame.size.width) + fabs(sub.frame.size.height - frame.size.height);
        if (d < distance) {
            distance = d;
            best = (UICollectionReusableView *)sub;
        }
    }
    return distance < 0.5 ? best : nil;
}

- (void)charon_settleLater
{
    if (self.collectionView && _pending.count > 0)
        [self charon_settleMeasurements];
}

- (BOOL)charon_settleMeasurements
{
    NSArray *entries = [_pending.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSComparisonResult order = [@([b[@"cell"] boolValue]) compare:@([a[@"cell"] boolValue])];
        return order != NSOrderedSame ? order : [a[@"path"] compare:b[@"path"]];
    }];
    _pending = nil;
    if (entries.count == 0 || !_solved)
        return NO;
    UICollectionView *view = self.collectionView;
    BOOL changed = NO;
    NSUInteger position = 0;
    for (NSDictionary *entry in entries) {
        position++;
        NSIndexPath *path = entry[@"path"];
        BOOL cell = [entry[@"cell"] boolValue];
        NSString *kind = cell ? nil : entry[@"kind"];
        UICollectionReusableView *shown = cell ? [view cellForItemAtIndexPath:path] : [self charon_shownSupplementaryOfKind:kind frame:[entry[@"frame"] CGRectValue]];
        CharonSolvedElement *element = _lookup[[self keyForCategory:cell ? 0 : 1 kind:kind indexPath:path]];
        if (!shown || !shown.superview || !element)
            continue;
        CGRect frame = element->scrolls ? [_orthogonal shiftedFrame:element->frame section:path.section] : element->frame;
        if (!CGRectIntersectsRect(frame, view.bounds))
            continue;
        if ([self charon_measureView:shown element:element kind:kind]) {
            changed = YES;
            if (position < entries.count)
                [self charon_solveView:view];
        }
    }
    NSArray *contexts = _preferredContexts;
    _preferredContexts = nil;
    if (changed) {
        _measuring = YES;
        _applyingPreferred = YES;
        for (UICollectionViewLayoutInvalidationContext *context in contexts)
            [self invalidateLayoutWithContext:context];
        _applyingPreferred = NO;
        _measuring = NO;
    }
    return changed;
}

- (BOOL)charon_measureView:(UICollectionReusableView *)view element:(CharonSolvedElement *)element kind:(NSString *)kind
{
    if (_measuring || !_solved || !(element->estimatedWidth || element->estimatedHeight))
        return NO;
    if (!_measured) {
        _measured = [NSMutableDictionary dictionary];
        _measuredAgainst = [NSMutableDictionary dictionary];
    }
    NSString *key = kind ? [NSString stringWithFormat:@"b/%@/%ld/%ld", kind, (long)element->indexPath.section, (long)element->indexPath.item]
                         : [NSString stringWithFormat:@"%ld/%ld", (long)element->indexPath.section, (long)element->indexPath.item];
    CGFloat fixed = element->estimatedWidth ? (element->estimatedHeight ? 0 : element->frame.size.height) : element->frame.size.width;
    NSNumber *against = _measuredAgainst[key];
    if (against && fabs(against.doubleValue - fixed) < 0.01)
        return NO;
    UICollectionViewLayoutAttributes *original = kind ? [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:kind withIndexPath:element->indexPath]
                                                       : [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:element->indexPath];
    original.frame = element->frame;
    _measuring = YES;
    UICollectionViewLayoutAttributes *preferred = charon_preferred_attributes(view, original, element->estimatedWidth, element->estimatedHeight, _scale);
    _measuring = NO;
    _measuredAgainst[key] = @(fixed);
    if (![self shouldInvalidateLayoutForPreferredLayoutAttributes:preferred withOriginalAttributes:original]) {
        _measured[key] = [NSValue valueWithCGSize:element->frame.size];
        return NO;
    }
    _measured[key] = [NSValue valueWithCGSize:preferred.frame.size];
    if (!_preferredContexts)
        _preferredContexts = [NSMutableArray array];
    [_preferredContexts addObject:[self invalidationContextForPreferredLayoutAttributes:preferred withOriginalAttributes:original]];
    return YES;
}

- (NSUInteger)charon_estimatedAxesForAttributes:(UICollectionViewLayoutAttributes *)attributes
{
    NSString *kind = attributes.representedElementCategory == UICollectionElementCategoryCell ? nil : attributes.representedElementKind;
    CharonSolvedElement *element = _lookup[[self keyForCategory:kind ? 1 : 0 kind:kind indexPath:attributes.indexPath]];
    if (!element)
        return 0;
    return (element->estimatedWidth ? 1u : 0u) | (element->estimatedHeight ? 2u : 0u);
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes
{
    CGSize preferred = preferredAttributes.frame.size, original = originalAttributes.frame.size;
    return fabs(preferred.width - original.width) > 0.01 || fabs(preferred.height - original.height) > 0.01;
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context
{
    if (_applyingPreferred) {
        _solved = NO;
        _keepSolution = NO;
    }
    [super invalidateLayoutWithContext:context];
}

- (void)charon_offsetsDidChange
{
    _boundsOnlyChange = YES;
    [self invalidateLayout];
}

- (void)charon_scrollSection:(NSInteger)section toOffset:(CGFloat)offset settle:(BOOL)settle
{
    [_orthogonal scrollSection:section toOffset:offset settle:settle];
}

- (CGFloat)charon_offsetOfSection:(NSInteger)section
{
    return [_orthogonal offsetOfSection:section];
}

- (void)dealloc
{
    [_orthogonal detach];
}

- (void)referenceInsets:(NSInteger)reference lead:(CGFloat *)lead trail:(CGFloat *)trail
{
    UICollectionView *view = self.collectionView;
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (reference == 2 && [view respondsToSelector:@selector(safeAreaInsets)])
        insets = view.safeAreaInsets;
    else if (reference == 3 || reference == 4)
        insets = view.layoutMargins;
    *lead = _vertical ? insets.left : insets.top;
    *trail = _vertical ? insets.right : insets.bottom;
}

- (void)shiftCross:(CharonSolvedSection *)solved by:(CGFloat)shift
{
    if (shift == 0)
        return;
    CGFloat dx = _vertical ? shift : 0, dy = _vertical ? 0 : shift;
    solved->viewport = CGRectOffset(solved->viewport, dx, dy);
    for (CharonSolvedElement *element in solved->elements) {
        element->frame = CGRectOffset(element->frame, dx, dy);
        element->owner = CGRectOffset(element->owner, dx, dy);
    }
}

- (CGFloat)roundedPixels:(CGFloat)value
{
    return floor(value * _scale + 0.5) / _scale;
}

- (CGRect)settled:(CharonSolvedElement *)element
{
    CGRect frame = element->frame;
    CGRect rounded = CGRectMake([self roundedPixels:frame.origin.x], [self roundedPixels:frame.origin.y], frame.size.width, frame.size.height);
    if (element->category == 2) {
        rounded.size.width = [self roundedPixels:frame.size.width];
        rounded.size.height = [self roundedPixels:frame.size.height];
    }
    return rounded;
}

- (void)shiftSolved:(CharonSolvedSection *)solved by:(CGFloat)shift
{
    CGFloat dx = _vertical ? 0 : shift, dy = _vertical ? shift : 0;
    solved->extent = CGRectOffset(solved->extent, dx, dy);
    solved->viewport = CGRectOffset(solved->viewport, dx, dy);
    for (CharonSolvedElement *element in solved->elements) {
        element->frame = CGRectOffset(element->frame, dx, dy);
        element->owner = CGRectOffset(element->owner, dx, dy);
        element->pinLow += _vertical ? dy : dx;
        element->pinHigh += _vertical ? dy : dx;
    }
}

- (NSString *)keyForCategory:(NSInteger)category kind:(NSString *)kind indexPath:(NSIndexPath *)indexPath
{
    return [NSString stringWithFormat:@"%ld/%@/%ld/%ld", (long)category, kind ?: @"", (long)indexPath.section, (long)indexPath.item];
}

- (void)record:(CharonSolvedElement *)element
{
    _lookup[[self keyForCategory:element->category kind:element->kind indexPath:element->indexPath]] = element;
}

- (CGSize)collectionViewContentSize
{
    return _contentSize;
}

- (UICollectionViewLayoutAttributes *)attributesForElement:(CharonSolvedElement *)element
{
    UICollectionViewLayoutAttributes *attributes;
    if (element->category == 0)
        attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:element->indexPath];
    else if (element->category == 1)
        attributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:element->kind withIndexPath:element->indexPath];
    else
        attributes = [UICollectionViewLayoutAttributes layoutAttributesForDecorationViewOfKind:element->kind withIndexPath:element->indexPath];
    CGRect frame = element->frame;
    NSInteger z = element->zIndex;
    if (element->pinned) {
        UICollectionView *view = self.collectionView;
        CGRect bounds = view.bounds;
        UIEdgeInsets inset = [view respondsToSelector:@selector(adjustedContentInset)] ? view.adjustedContentInset : view.contentInset;
        CharonAlignmentParts parts = charon_alignment_parts(element->alignment);
        CGFloat low = element->pinLow, high = MAX(low, element->pinHigh);
        if (_vertical) {
            CGFloat wanted = parts.vertical < 0 ? CGRectGetMinY(bounds) + inset.top : CGRectGetMaxY(bounds) - inset.bottom - frame.size.height;
            frame.origin.y = MIN(MAX(wanted, low), high);
        } else {
            CGFloat wanted = parts.horizontal < 0 ? CGRectGetMinX(bounds) + inset.left : CGRectGetMaxX(bounds) - inset.right - frame.size.width;
            frame.origin.x = MIN(MAX(wanted, low), high);
        }
        if (CGRectIntersectsRect(frame, bounds))
            z += CharonPinnedZIndex;
    }
    attributes.frame = frame;
    attributes.zIndex = z;
    if (element->scrolls)
        [_orthogonal applyToAttributes:attributes element:element];
    return attributes;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
    CGRect clipped = CGRectIntersection(rect, CGRectMake(0, 0, _contentSize.width, _contentSize.height));
    if (CGRectIsNull(clipped))
        return @[];
    BOOL flat = clipped.size.width <= 0 || clipped.size.height <= 0;
    NSMutableArray *found = [NSMutableArray array];
    for (CharonSolvedSection *solved in _solvedSections) {
        if (solved->extent.size.width <= 0 || solved->extent.size.height <= 0 || !charon_touches(solved->extent, clipped))
            continue;
        for (CharonSolvedElement *element in solved->elements) {
            if (element->category == 2) {
                [found addObject:[self attributesForElement:element]];
                continue;
            }
            CGRect ownerNow = element->owner, frameNow = element->frame;
            if (element->scrolls) {
                NSInteger own = element->indexPath.section;
                frameNow = [_orthogonal shiftedFrame:frameNow section:own];
                ownerNow = [_orthogonal shiftedFrame:ownerNow section:own];
                if (![_orthogonal viewportShows:frameNow section:own])
                    continue;
            }
            if (flat || (element->hasOwner && (ownerNow.size.width <= 0 || ownerNow.size.height <= 0 || !CGRectIntersectsRect(ownerNow, clipped))))
                continue;
            if (element->pinned || CGRectIntersectsRect(frameNow, clipped)) {
                UICollectionViewLayoutAttributes *attributes = [self attributesForElement:element];
                if (!element->scrolls && !CGRectIntersectsRect(attributes.frame, clipped))
                    continue;
                if (element->category == 0 && element->hasOwner && !element->scrolls && !charon_within_owner(attributes.frame, element->owner, clipped))
                    continue;
                if (element->category == 0 && charon_files_by_pages() && charon_spans(attributes.frame, clipped)) {
                    UICollectionViewLayoutAttributes *pilot = [attributes copy];
                    pilot.frame = CGRectIntersection(attributes.frame, clipped);
                    [found addObject:pilot];
                }
                [found addObject:attributes];
                [self charon_note:element attributes:attributes];
            }
        }
    }
    if (flat)
        return found;
    for (CharonSolvedElement *element in _boundaryElements) {
        UICollectionViewLayoutAttributes *attributes = [self attributesForElement:element];
        if (CGRectIntersectsRect(attributes.frame, clipped)) {
            [found addObject:attributes];
            [self charon_note:element attributes:attributes];
        }
    }
    return found;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CharonSolvedElement *element = _lookup[[self keyForCategory:0 kind:nil indexPath:indexPath]];
    return element ? [self attributesForElement:element] : nil;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    CharonSolvedElement *element = _lookup[[self keyForCategory:1 kind:elementKind indexPath:indexPath]];
    return element ? [self attributesForElement:element] : nil;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    CharonSolvedElement *element = _lookup[[self keyForCategory:2 kind:elementKind indexPath:indexPath]];
    return element ? [self attributesForElement:element] : nil;
}

@end
