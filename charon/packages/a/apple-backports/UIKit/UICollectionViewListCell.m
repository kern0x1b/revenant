#import "CharonLists.h"
#import "CharonSwipeViews.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@interface CharonRowSeparatorView : UIView
@end

@implementation CharonRowSeparatorView
@end

@interface CharonVerticalSeparatorView : UIView
@end

@implementation CharonVerticalSeparatorView
@end

@implementation UICollectionViewListCell {
@private
    NSInteger _indentationLevel;
    CGFloat _indentationWidth;
    BOOL _indentsAccessories;
    NSArray *_accessories;
    NSMutableArray *_accessoryViews;
    UILayoutGuide *_separatorGuide;
    CharonRowSeparatorView *_separator;
    CGRect _separatorFrame;
    CharonVerticalSeparatorView *_reorderSeparator;
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
        charon_host_set_background(self, [[UIBackgroundConfiguration alloc] initCharonWithStyle:CharonBackgroundStyleListCell]);
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
        charon_host_set_background(self, [[UIBackgroundConfiguration alloc] initCharonWithStyle:CharonBackgroundStyleListCell]);
    }
    return self;
}

- (UIListContentConfiguration *)defaultContentConfiguration
{
    return [UIListContentConfiguration cellConfiguration];
}

- (BOOL)charon_isExpanded
{
    return _expanded;
}

- (void)charon_setExpanded:(BOOL)expanded animated:(BOOL)animated
{
    if (_expanded == expanded)
        return;
    _expanded = expanded;
    for (id view in _accessoryViews)
        if ([view respondsToSelector:@selector(charon_setExpanded:animated:)])
            [view charon_setExpanded:expanded animated:animated];
    charon_request_update(self);
}

- (void)charon_setExpansionHandler:(void (^)(void))handler
{
    _expansionHandler = [handler copy];
}

- (void)charon_toggleExpansion
{
    if (_expansionHandler)
        _expansionHandler();
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _expansionHandler = nil;
    if (_expanded)
        [self charon_setExpanded:NO animated:NO];
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
        UIView *view = [accessory charon_makeView];
        [_accessoryViews addObject:view ?: (id)[NSNull null]];
        if (view)
            [self addSubview:view];
        if (_expanded && [view respondsToSelector:@selector(charon_setExpanded:animated:)])
            [(id)view charon_setExpanded:YES animated:NO];
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

- (BOOL)charon_visible:(UICellAccessory *)accessory editing:(BOOL)editing
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

- (NSArray *)charon_ordered:(NSArray *)group
{
    NSMutableArray *plain = [NSMutableArray array], *custom = [NSMutableArray array];
    for (UICellAccessory *accessory in group) {
        UICellAccessoryCustomView *view = (UICellAccessoryCustomView *)accessory;
        BOOL placed = [accessory isKindOfClass:[UICellAccessoryCustomView class]] && ![view charon_hasDefaultPosition];
        [(placed ? custom : plain) addObject:accessory];
    }
    [plain sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(UICellAccessory *a, UICellAccessory *b) {
        return [a charon_order] < [b charon_order] ? NSOrderedAscending : [a charon_order] > [b charon_order] ? NSOrderedDescending : NSOrderedSame;
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

- (BOOL)charon_inList
{
    return [self charon_layoutListConfiguration] != nil;
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    if (self.superview) {
        charon_request_update(self);
        [self setNeedsLayout];
        UICollectionView *view = charon_owning_collection_view(self);
        if (view)
            charon_install_list_swipe(view);
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat scale = charon_screen_scale();
    BOOL editing = [charon_owning_collection_view(self) charon_editing];
    UIEdgeInsets margins = [self respondsToSelector:@selector(layoutMargins)] ? self.layoutMargins : UIEdgeInsetsMake(0, 8, 0, 8);
    if ([self charon_inList])
        margins = UIEdgeInsetsMake(0, 16, 0, 16);
    NSMutableArray *leading = [NSMutableArray array], *trailing = [NSMutableArray array];
    for (NSUInteger index = 0; index < _accessories.count; index++) {
        UICellAccessory *accessory = _accessories[index];
        UIView *view = _accessoryViews[index];
        BOOL shown = [self charon_visible:accessory editing:editing] && [view isKindOfClass:[UIView class]];
        if ([view isKindOfClass:[UIView class]])
            view.hidden = !shown;
        if (shown)
            [([accessory charon_isLeading] ? leading : trailing) addObject:accessory];
    }
    CGFloat indent = _indentationLevel * _indentationWidth;
    CGFloat cursor = margins.left + (_indentsAccessories ? indent : 0), contentStart = indent;
    NSArray *lead = [self charon_ordered:leading], *trail = [self charon_ordered:trailing];
    for (UICellAccessory *accessory in lead) {
        UIView *view = _accessoryViews[[_accessories indexOfObjectIdenticalTo:accessory]];
        CGFloat width = [accessory charon_width];
        CGRect frame = view.frame;
        frame.origin.x = cursor + (width - frame.size.width) / 2;
        frame.origin.y = charon_pixel_round((bounds.size.height - frame.size.height) / 2, scale);
        view.frame = frame;
        contentStart = cursor + width;
        cursor += width + 16;
    }
    CGFloat edge = bounds.size.width - margins.right, contentEnd = bounds.size.width;
    BOOL separated = NO;
    for (UICellAccessory *accessory in [trail reverseObjectEnumerator]) {
        UIView *view = _accessoryViews[[_accessories indexOfObjectIdenticalTo:accessory]];
        CGFloat width = [accessory charon_width];
        CGRect frame = view.frame;
        frame.origin.x = edge - width + (width - frame.size.width) / 2;
        frame.origin.y = charon_pixel_round((bounds.size.height - frame.size.height) / 2, scale);
        view.frame = frame;
        contentEnd = edge - width;
        BOOL divided = [accessory isKindOfClass:[UICellAccessoryReorder class]] && [(UICellAccessoryReorder *)accessory showsVerticalSeparator] && accessory != trail.firstObject;
        if (divided) {
            if (!_reorderSeparator) {
                _reorderSeparator = [[CharonVerticalSeparatorView alloc] init];
                _reorderSeparator.userInteractionEnabled = NO;
                [self addSubview:_reorderSeparator];
            }
            _reorderSeparator.backgroundColor = charon_semantic_color(CharonSemanticColorSeparator);
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
    CGFloat textLeading = [content isKindOfClass:[UIListContentView class]] ? contentStart + [(UIListContentView *)content charon_textLeading] : margins.left + indent;
    _separatorFrame = CGRectMake(textLeading, bounds.size.height - 1 / scale, MAX(bounds.size.width - margins.right - textLeading, 0), 1 / scale);
    UICollectionLayoutListConfiguration *configuration = [self charon_layoutListConfiguration];
    if (configuration && [configuration charon_showsSeparators]) {
        if (!_separator) {
            _separator = [[CharonRowSeparatorView alloc] init];
            _separator.userInteractionEnabled = NO;
            [self addSubview:_separator];
        }
        _separator.backgroundColor = charon_semantic_color(CharonSemanticColorSeparator);
        _separator.frame = _separatorFrame;
    } else {
        [_separator removeFromSuperview];
        _separator = nil;
    }
    [_separatorGuide charon_pinFrame:_separatorFrame inView:self];
}

@end
