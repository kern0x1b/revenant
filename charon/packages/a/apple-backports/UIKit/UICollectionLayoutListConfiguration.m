#import "CharonLists.h"
#import "CharonCompositionalLayout.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation UICollectionLayoutListConfiguration {
@private
    UICollectionLayoutListAppearance _appearance;
    BOOL _showsSeparators;
    UIColor *_backgroundColor;
    UICollectionLayoutListSwipeActionsConfigurationProvider _leadingSwipeActionsConfigurationProvider;
    UICollectionLayoutListSwipeActionsConfigurationProvider _trailingSwipeActionsConfigurationProvider;
    UICollectionLayoutListHeaderMode _headerMode;
    UICollectionLayoutListFooterMode _footerMode;
    UIListSeparatorConfiguration *_separatorConfiguration;
    UICollectionLayoutListItemSeparatorHandler _itemSeparatorHandler;
    CGFloat _headerTopPadding;
}

- (instancetype)initWithAppearance:(UICollectionLayoutListAppearance)appearance
{
    if ((self = [super init])) {
        _appearance = appearance;
        _showsSeparators = YES;
        _headerTopPadding = CGFLOAT_MAX;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithAppearance:UICollectionLayoutListAppearancePlain];
}

- (id)copyWithZone:(NSZone *)zone
{
    UICollectionLayoutListConfiguration *copy = [[[self class] allocWithZone:zone] initWithAppearance:_appearance];
    copy->_showsSeparators = _showsSeparators;
    copy->_backgroundColor = _backgroundColor;
    copy->_leadingSwipeActionsConfigurationProvider = [_leadingSwipeActionsConfigurationProvider copy];
    copy->_trailingSwipeActionsConfigurationProvider = [_trailingSwipeActionsConfigurationProvider copy];
    copy->_headerMode = _headerMode;
    copy->_footerMode = _footerMode;
    copy->_separatorConfiguration = [_separatorConfiguration copy];
    copy->_itemSeparatorHandler = [_itemSeparatorHandler copy];
    copy->_headerTopPadding = _headerTopPadding;
    return copy;
}

- (UIListSeparatorConfiguration *)separatorConfiguration
{
    return _separatorConfiguration ?: [[UIListSeparatorConfiguration alloc] initWithListAppearance:_appearance];
}

- (void)setSeparatorConfiguration:(UIListSeparatorConfiguration *)separatorConfiguration
{
    if (!separatorConfiguration)
        [NSException raise:NSInvalidArgumentException format:@"Setting a nil separatorConfiguration is not supported"];
    _separatorConfiguration = [separatorConfiguration copy];
}

- (UICollectionLayoutListItemSeparatorHandler)itemSeparatorHandler
{
    return _itemSeparatorHandler;
}

- (void)setItemSeparatorHandler:(UICollectionLayoutListItemSeparatorHandler)itemSeparatorHandler
{
    _itemSeparatorHandler = [itemSeparatorHandler copy];
}

- (CGFloat)headerTopPadding
{
    return _headerTopPadding;
}

- (void)setHeaderTopPadding:(CGFloat)headerTopPadding
{
    _headerTopPadding = headerTopPadding;
}

- (UICollectionLayoutListAppearance)appearance
{
    return _appearance;
}

- (UICollectionLayoutListAppearance)charon_appearance
{
    return _appearance;
}

- (BOOL)showsSeparators
{
    return _showsSeparators;
}

- (BOOL)charon_showsSeparators
{
    return _showsSeparators;
}

- (void)setShowsSeparators:(BOOL)showsSeparators
{
    _showsSeparators = showsSeparators;
}

- (UIColor *)backgroundColor
{
    return _backgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    _backgroundColor = backgroundColor;
}

- (UICollectionLayoutListSwipeActionsConfigurationProvider)leadingSwipeActionsConfigurationProvider
{
    return _leadingSwipeActionsConfigurationProvider;
}

- (void)setLeadingSwipeActionsConfigurationProvider:(UICollectionLayoutListSwipeActionsConfigurationProvider)leadingSwipeActionsConfigurationProvider
{
    _leadingSwipeActionsConfigurationProvider = [leadingSwipeActionsConfigurationProvider copy];
}

- (UICollectionLayoutListSwipeActionsConfigurationProvider)trailingSwipeActionsConfigurationProvider
{
    return _trailingSwipeActionsConfigurationProvider;
}

- (void)setTrailingSwipeActionsConfigurationProvider:(UICollectionLayoutListSwipeActionsConfigurationProvider)trailingSwipeActionsConfigurationProvider
{
    _trailingSwipeActionsConfigurationProvider = [trailingSwipeActionsConfigurationProvider copy];
}

- (UICollectionLayoutListHeaderMode)headerMode
{
    return _headerMode;
}

- (void)setHeaderMode:(UICollectionLayoutListHeaderMode)headerMode
{
    _headerMode = headerMode;
}

- (UICollectionLayoutListFooterMode)footerMode
{
    return _footerMode;
}

- (void)setFooterMode:(UICollectionLayoutListFooterMode)footerMode
{
    _footerMode = footerMode;
}

@end

static const CGFloat CharonListRowEstimate = 44;

@implementation NSCollectionLayoutSection (CharonListConfiguration)

+ (instancetype)sectionWithListConfiguration:(UICollectionLayoutListConfiguration *)configuration layoutEnvironment:(id<NSCollectionLayoutEnvironment>)layoutEnvironment
{
    UICollectionLayoutListAppearance appearance = [configuration charon_appearance];
    UICollectionLayoutListHeaderMode header = configuration.headerMode;
    UICollectionLayoutListFooterMode footer = configuration.footerMode;
    BOOL plain = appearance == UICollectionLayoutListAppearancePlain, sidebarPlain = appearance == UICollectionLayoutListAppearanceSidebarPlain;
    BOOL grouped = appearance == UICollectionLayoutListAppearanceGrouped || appearance == UICollectionLayoutListAppearanceInsetGrouped;
    BOOL sidebar = appearance == UICollectionLayoutListAppearanceSidebar;
    NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:[NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
                                                                                                          heightDimension:[NSCollectionLayoutDimension estimatedDimension:CharonListRowEstimate]]];
    NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:item.layoutSize subitems:@[item]];
    NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
    CGFloat top = 0, bottom = 0, side = 0;
    if (plain)
        top = header == UICollectionLayoutListHeaderModeFirstItemInSection ? 22 : 0;
    else if (grouped) {
        top = header == UICollectionLayoutListHeaderModeNone ? 35 : 0;
        bottom = footer == UICollectionLayoutListFooterModeNone ? 20 : 0;
        side = appearance == UICollectionLayoutListAppearanceInsetGrouped ? 16 : 0;
    } else if (sidebar) {
        bottom = footer == UICollectionLayoutListFooterModeNone ? 10 : 0;
        side = 12.987012987012987;
    } else if (sidebarPlain)
        side = 12.987012987012987;
    section.contentInsets = NSDirectionalEdgeInsetsMake(top, side, bottom, side);
    section.contentInsetsReference = UIContentInsetsReferenceNone;
    BOOL pinned = plain || sidebarPlain;
    NSCollectionLayoutDimension *height = [NSCollectionLayoutDimension estimatedDimension:pinned ? 28 : 17.5];
    NSCollectionLayoutSize *size = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1] heightDimension:height];
    NSMutableArray *boundaries = [NSMutableArray array];
    if (header == UICollectionLayoutListHeaderModeSupplementary) {
        NSCollectionLayoutBoundarySupplementaryItem *boundary = [NSCollectionLayoutBoundarySupplementaryItem boundarySupplementaryItemWithLayoutSize:size elementKind:UICollectionElementKindSectionHeader
                                                                                                                                         alignment:NSRectAlignmentTop];
        boundary.extendsBoundary = YES;
        boundary.pinToVisibleBounds = pinned;
        boundary.zIndex = 200;
        [boundaries addObject:boundary];
    }
    if (footer == UICollectionLayoutListFooterModeSupplementary) {
        NSCollectionLayoutBoundarySupplementaryItem *boundary = [NSCollectionLayoutBoundarySupplementaryItem boundarySupplementaryItemWithLayoutSize:size elementKind:UICollectionElementKindSectionFooter
                                                                                                                                         alignment:NSRectAlignmentBottom];
        boundary.extendsBoundary = YES;
        boundary.pinToVisibleBounds = pinned;
        boundary.zIndex = 200;
        [boundaries addObject:boundary];
    }
    section.boundarySupplementaryItems = boundaries;
    [section charon_setListConfiguration:[configuration copy]];
    return section;
}

@end

@implementation UICollectionViewCompositionalLayout (CharonListConfiguration)

+ (instancetype)layoutWithListConfiguration:(UICollectionLayoutListConfiguration *)configuration
{
    UICollectionLayoutListConfiguration *copy = [configuration copy];
    UICollectionViewCompositionalLayout *layout = [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger sectionIndex, id<NSCollectionLayoutEnvironment> environment) {
        return [NSCollectionLayoutSection sectionWithListConfiguration:copy layoutEnvironment:environment];
    }];
    [layout charon_setListConfiguration:copy];
    return layout;
}

@end
