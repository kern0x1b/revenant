#import "RevenantLists.h"
#import "RevenantSwipeViews.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@interface RevenantRowSeparatorView : UIView
@end

@implementation RevenantRowSeparatorView
@end

@interface RevenantVerticalSeparatorView : UIView
@end

@implementation RevenantVerticalSeparatorView
@end

@implementation UICollectionViewListCell {
@private
    NSInteger _indentationLevel;
    CGFloat _indentationWidth;
    BOOL _indentsAccessories;
    NSArray *_accessories;
    NSMutableArray *_accessoryViews;
    UILayoutGuide *_separatorGuide;
    RevenantRowSeparatorView *_separator;
    CGRect _separatorFrame;
    RevenantVerticalSeparatorView *_reorderSeparator;
    BOOL _expanded;
    void (^_expansionHandler)(void);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _indentationWidth = 10;
        _indentsAccessories = YES;
        _accessories = @[];
        _accessoryViews = [[NSMutableArray alloc] init];
        revenant_host_set_background(self, [[UIBackgroundConfiguration alloc] initRevenantWithStyle:RevenantBackgroundStyleListCell]);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _indentationWidth = 10;
        _indentsAccessories = YES;
        _accessories = @[];
        _accessoryViews = [[NSMutableArray alloc] init];
        revenant_host_set_background(self, [[UIBackgroundConfiguration alloc] initRevenantWithStyle:RevenantBackgroundStyleListCell]);
    }
    return self;
}

- (UIListContentConfiguration *)defaultContentConfiguration
{
    return [UIListContentConfiguration cellConfiguration];
}

- (BOOL)revenant_isExpanded
{
    return _expanded;
}

- (void)revenant_setExpanded:(BOOL)expanded animated:(BOOL)animated
{
    if (_expanded == expanded)
        return;
    _expanded = expanded;
    for (id view in _accessoryViews)
        if ([view respondsToSelector:@selector(revenant_setExpanded:animated:)])
            [view revenant_setExpanded:expanded animated:animated];
    revenant_request_update(self);
}

- (void)revenant_setExpansionHandler:(void (^)(void))handler
{
    _expansionHandler = [handler copy];
}

- (void)revenant_toggleExpansion
{
    if (_expansionHandler)
        _expansionHandler();
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _expansionHandler = nil;
    if (_expanded)
        [self revenant_setExpanded:NO animated:NO];
}

- (NSInteger)indentationLevel
{
    return _indentationLevel;
}

- (void)setIndentationLevel:(NSInteger)indentationLevel
{
    _indentationLevel = indentationLevel;
    [self setNeedsLayout];
}

- (CGFloat)indentationWidth
{
    return _indentationWidth;
}

- (void)setIndentationWidth:(CGFloat)indentationWidth
{
    _indentationWidth = indentationWidth;
    [self setNeedsLayout];
}

- (BOOL)indentsAccessories
{
    return _indentsAccessories;
}

- (void)setIndentsAccessories:(BOOL)indentsAccessories
{
    _indentsAccessories = indentsAccessories;
    [self setNeedsLayout];
}

- (NSArray<UICellAccessory *> *)accessories
{
    return _accessories;
}

- (void)setAccessories:(NSArray<UICellAccessory *> *)accessories
{
    NSMutableArray *duplicates = [NSMutableArray array];
    for (UICellAccessory *accessory in accessories) {
        if ([accessory isKindOfClass:[UICellAccessoryCustomView class]])
            continue;
        for (UICellAccessory *other in accessories)
            if (other != accessory && [other isMemberOfClass:[accessory class]]) {
                [duplicates addObject:accessory];
                break;
            }
    }
    if (duplicates.count)
        [NSException raise:NSInternalInconsistencyException format:@"Accessories array contains more than one system accessory of the same type. Duplicate accessories: %@", [duplicates componentsJoinedByString:@" "]];
    for (UIView *view in _accessoryViews)
        [view removeFromSuperview];
    [_accessoryViews removeAllObjects];
    _accessories = [accessories copy] ?: @[];
    for (UICellAccessory *accessory in _accessories) {
        UIView *view = [accessory revenant_makeView];
        [_accessoryViews addObject:view ?: (id)[NSNull null]];
        if (view)
            [self addSubview:view];
        if (_expanded && [view respondsToSelector:@selector(revenant_setExpanded:animated:)])
            [(id)view revenant_setExpanded:YES animated:NO];
    }
    [self setNeedsLayout];
}

- (UILayoutGuide *)separatorLayoutGuide
{
    if (!_separatorGuide) {
        _separatorGuide = [[UILayoutGuide alloc] init];
        _separatorGuide.identifier = @"UICollectionViewListCellSeparatorLayoutGuide";
        [self addLayoutGuide:_separatorGuide];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
    return _separatorGuide;
}

- (BOOL)revenant_visible:(UICellAccessory *)accessory editing:(BOOL)editing
{
    if (accessory.hidden)
        return NO;
    switch (accessory.displayedState) {
    case UICellAccessoryDisplayedWhenEditing:
        return editing;
    case UICellAccessoryDisplayedWhenNotEditing:
        return !editing;
    default:
        return YES;
    }
}

- (NSArray *)revenant_ordered:(NSArray *)group
{
    NSMutableArray *plain = [NSMutableArray array], *custom = [NSMutableArray array];
    for (UICellAccessory *accessory in group) {
        UICellAccessoryCustomView *view = (UICellAccessoryCustomView *)accessory;
        BOOL placed = [accessory isKindOfClass:[UICellAccessoryCustomView class]] && ![view revenant_hasDefaultPosition];
        [(placed ? custom : plain) addObject:accessory];
    }
    [plain sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(UICellAccessory *a, UICellAccessory *b) {
        return [a revenant_order] < [b revenant_order] ? NSOrderedAscending : [a revenant_order] > [b revenant_order] ? NSOrderedDescending : NSOrderedSame;
    }];
    for (UICellAccessoryCustomView *accessory in custom) {
        NSMutableArray *others = [NSMutableArray array];
        for (UICellAccessory *other in plain)
            if (![other isKindOfClass:[UICellAccessoryCustomView class]])
                [others addObject:other];
        NSUInteger index = MIN(accessory.position(others), others.count);
        NSUInteger target = index < others.count ? [plain indexOfObjectIdenticalTo:others[index]] : plain.count;
        [plain insertObject:accessory atIndex:target];
    }
    return plain;
}

- (BOOL)revenant_inList
{
    return [self revenant_layoutListConfiguration] != nil;
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    if (self.superview) {
        revenant_request_update(self);
        [self setNeedsLayout];
        UICollectionView *view = revenant_owning_collection_view(self);
        if (view)
            revenant_install_list_swipe(view);
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat scale = revenant_screen_scale();
    BOOL editing = [revenant_owning_collection_view(self) revenant_editing];
    UIEdgeInsets margins = [self respondsToSelector:@selector(layoutMargins)] ? self.layoutMargins : UIEdgeInsetsMake(0, 8, 0, 8);
    if ([self revenant_inList])
        margins = UIEdgeInsetsMake(0, 16, 0, 16);
    NSMutableArray *leading = [NSMutableArray array], *trailing = [NSMutableArray array];
    for (NSUInteger index = 0; index < _accessories.count; index++) {
        UICellAccessory *accessory = _accessories[index];
        UIView *view = _accessoryViews[index];
        BOOL shown = [self revenant_visible:accessory editing:editing] && [view isKindOfClass:[UIView class]];
        if ([view isKindOfClass:[UIView class]])
            view.hidden = !shown;
        if (shown)
            [([accessory revenant_isLeading] ? leading : trailing) addObject:accessory];
    }
    CGFloat indent = _indentationLevel * _indentationWidth;
    CGFloat cursor = margins.left + (_indentsAccessories ? indent : 0), contentStart = indent;
    NSArray *lead = [self revenant_ordered:leading], *trail = [self revenant_ordered:trailing];
    for (UICellAccessory *accessory in lead) {
        UIView *view = _accessoryViews[[_accessories indexOfObjectIdenticalTo:accessory]];
        CGFloat width = [accessory revenant_width];
        CGRect frame = view.frame;
        frame.origin.x = cursor + (width - frame.size.width) / 2;
        frame.origin.y = revenant_pixel_round((bounds.size.height - frame.size.height) / 2, scale);
        view.frame = frame;
        contentStart = cursor + width;
        cursor += width + 16;
    }
    CGFloat edge = bounds.size.width - margins.right, contentEnd = bounds.size.width;
    BOOL separated = NO;
    for (UICellAccessory *accessory in [trail reverseObjectEnumerator]) {
        UIView *view = _accessoryViews[[_accessories indexOfObjectIdenticalTo:accessory]];
        CGFloat width = [accessory revenant_width];
        CGRect frame = view.frame;
        frame.origin.x = edge - width + (width - frame.size.width) / 2;
        frame.origin.y = revenant_pixel_round((bounds.size.height - frame.size.height) / 2, scale);
        view.frame = frame;
        contentEnd = edge - width;
        BOOL divided = [accessory isKindOfClass:[UICellAccessoryReorder class]] && [(UICellAccessoryReorder *)accessory showsVerticalSeparator] && accessory != trail.firstObject;
        if (divided) {
            if (!_reorderSeparator) {
                _reorderSeparator = [[RevenantVerticalSeparatorView alloc] init];
                _reorderSeparator.userInteractionEnabled = NO;
                [self addSubview:_reorderSeparator];
            }
            _reorderSeparator.backgroundColor = revenant_semantic_color(RevenantSemanticColorSeparator);
            _reorderSeparator.frame = CGRectMake(contentEnd - 9, 0, 1, bounds.size.height);
            separated = YES;
        }
        edge = contentEnd - (divided ? 17 : 8);
    }
    if (!separated) {
        [_reorderSeparator removeFromSuperview];
        _reorderSeparator = nil;
    }
    self.contentView.frame = CGRectMake(contentStart, 0, MAX(contentEnd - contentStart, 0), bounds.size.height);
    UIView *content = self.contentView.subviews.firstObject;
    if ([content isKindOfClass:[UIListContentView class]])
        content.frame = self.contentView.bounds;
    CGFloat textLeading = [content isKindOfClass:[UIListContentView class]] ? contentStart + [(UIListContentView *)content revenant_textLeading] : margins.left + indent;
    _separatorFrame = CGRectMake(textLeading, bounds.size.height - 1 / scale, MAX(bounds.size.width - margins.right - textLeading, 0), 1 / scale);
    UICollectionLayoutListConfiguration *configuration = [self revenant_layoutListConfiguration];
    if (configuration && [configuration revenant_showsSeparators]) {
        if (!_separator) {
            _separator = [[RevenantRowSeparatorView alloc] init];
            _separator.userInteractionEnabled = NO;
            [self addSubview:_separator];
        }
        _separator.backgroundColor = revenant_semantic_color(RevenantSemanticColorSeparator);
        _separator.frame = _separatorFrame;
    } else {
        [_separator removeFromSuperview];
        _separator = nil;
    }
    [_separatorGuide revenant_pinFrame:_separatorFrame inView:self];
}

@end
