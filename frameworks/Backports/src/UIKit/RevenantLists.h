#import "RevenantMenus.h"

typedef NS_ENUM(NSInteger, RevenantListStyle) {
    RevenantListStyleBare,
    RevenantListStyleCell,
    RevenantListStyleSubtitle,
    RevenantListStyleValue,
    RevenantListStylePlainHeader,
    RevenantListStylePlainFooter,
    RevenantListStyleGroupedHeader,
    RevenantListStyleGroupedFooter,
    RevenantListStyleSidebarCell,
    RevenantListStyleSidebarSubtitle,
    RevenantListStyleAccompaniedSidebar,
    RevenantListStyleAccompaniedSidebarSubtitle,
    RevenantListStyleSidebarHeader,
    RevenantListStyleHeader,
    RevenantListStyleFooter
};

typedef NS_ENUM(NSInteger, RevenantBackgroundStyle) {
    RevenantBackgroundStyleCustom,
    RevenantBackgroundStyleListPlainCell,
    RevenantBackgroundStyleListPlainHeaderFooter,
    RevenantBackgroundStyleListGroupedCell,
    RevenantBackgroundStyleListGroupedHeaderFooter,
    RevenantBackgroundStyleListSidebarHeader,
    RevenantBackgroundStyleListSidebarCell,
    RevenantBackgroundStyleListAccompaniedSidebarCell,
    RevenantBackgroundStyleListCell
};

typedef NS_ENUM(NSInteger, RevenantSemanticColor) {
    RevenantSemanticColorLabel,
    RevenantSemanticColorSecondaryLabel,
    RevenantSemanticColorTertiaryLabel,
    RevenantSemanticColorQuaternaryLabel,
    RevenantSemanticColorSystemBackground,
    RevenantSemanticColorSecondarySystemGroupedBackground,
    RevenantSemanticColorSystemGray4,
    RevenantSemanticColorQuaternarySystemFill,
    RevenantSemanticColorSeparator
};

static inline UIColor *revenant_semantic_color(RevenantSemanticColor which)
{
    static const SEL selectors[] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    (void)selectors;
    switch (which) {
    case RevenantSemanticColorLabel:
        return [UIColor respondsToSelector:@selector(labelColor)] ? [UIColor labelColor] : [UIColor blackColor];
    case RevenantSemanticColorSecondaryLabel:
        return [UIColor respondsToSelector:@selector(secondaryLabelColor)] ? [UIColor secondaryLabelColor] : [UIColor colorWithRed:60.0 / 255 green:60.0 / 255 blue:67.0 / 255 alpha:0.6];
    case RevenantSemanticColorTertiaryLabel:
        return [UIColor respondsToSelector:@selector(tertiaryLabelColor)] ? [UIColor tertiaryLabelColor] : [UIColor colorWithRed:60.0 / 255 green:60.0 / 255 blue:67.0 / 255 alpha:0.3];
    case RevenantSemanticColorQuaternaryLabel:
        return [UIColor respondsToSelector:@selector(quaternaryLabelColor)] ? [UIColor quaternaryLabelColor] : [UIColor colorWithRed:60.0 / 255 green:60.0 / 255 blue:67.0 / 255 alpha:0.18];
    case RevenantSemanticColorSystemBackground:
        return [UIColor respondsToSelector:@selector(systemBackgroundColor)] ? [UIColor systemBackgroundColor] : [UIColor whiteColor];
    case RevenantSemanticColorSecondarySystemGroupedBackground:
        return [UIColor respondsToSelector:@selector(secondarySystemGroupedBackgroundColor)] ? [UIColor secondarySystemGroupedBackgroundColor] : [UIColor whiteColor];
    case RevenantSemanticColorSystemGray4:
        return [UIColor respondsToSelector:@selector(systemGray4Color)] ? [UIColor systemGray4Color] : [UIColor colorWithRed:209.0 / 255 green:209.0 / 255 blue:214.0 / 255 alpha:1];
    case RevenantSemanticColorQuaternarySystemFill:
        return [UIColor respondsToSelector:@selector(quaternarySystemFillColor)] ? [UIColor quaternarySystemFillColor] : [UIColor colorWithRed:116.0 / 255 green:116.0 / 255 blue:128.0 / 255 alpha:0.08];
    case RevenantSemanticColorSeparator:
        return [UIColor respondsToSelector:@selector(separatorColor)] ? [UIColor separatorColor] : [UIColor colorWithRed:60.0 / 255 green:60.0 / 255 blue:67.0 / 255 alpha:0.29];
    }
    return nil;
}
NSString *revenant_elided_text(NSString *text);
static inline CGFloat revenant_screen_scale(void)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    return scale > 0 ? scale : 1;
}

static inline CGFloat revenant_pixel_ceil(CGFloat value, CGFloat scale)
{
    return ceil(value * scale - 0.0001) / scale;
}

static inline CGFloat revenant_pixel_round(CGFloat value, CGFloat scale)
{
    return round(value * scale) / scale;
}
UIFont *revenant_medium_font(CGFloat pointSize);
UIFont *revenant_medium_body_font(void);

@interface UIListContentTextProperties (RevenantLists)
- (instancetype)initRevenantWithStyle:(NSInteger)style secondary:(BOOL)secondary;
- (void)revenant_setOwnerText:(NSString *)text;
- (BOOL)revenant_fontCustomized;
- (BOOL)revenant_colorCustomized;
- (void)revenant_setDefaultFont:(UIFont *)font;
- (void)revenant_setDefaultColor:(UIColor *)color;
- (void)revenant_setTransformerNamed:(NSString *)name block:(UIConfigurationColorTransformer)block;
@end

@interface UIListContentImageProperties (RevenantLists)
- (instancetype)initRevenantDefault;
- (instancetype)initRevenantBare;
- (void)revenant_setOwnerImage:(UIImage *)image;
- (BOOL)revenant_tintCustomized;
- (void)revenant_setDefaultTintColor:(UIColor *)color;
- (void)revenant_setTransformerNamed:(NSString *)name block:(UIConfigurationColorTransformer)block;
@end

@interface UIListContentConfiguration (RevenantLists)
- (instancetype)initRevenantWithStyle:(NSInteger)style;
- (NSInteger)revenant_style;
- (BOOL)revenant_isHeaderFooterStyle;
- (CGFloat)revenant_alpha;
@end

@interface UIBackgroundConfiguration (RevenantLists)
- (instancetype)initRevenantWithStyle:(NSInteger)style;
- (NSInteger)revenant_style;
@end

@interface UIListContentView (RevenantLists)
- (CGSize)revenant_sizeFittingWidth:(CGFloat)width;
@end

@interface UICellAccessoryCustomView (RevenantLists)
- (BOOL)revenant_hasDefaultPosition;
@end

@interface UICellAccessory (RevenantLists)
- (UIView *)revenant_makeView;
- (CGFloat)revenant_width;
- (BOOL)revenant_isLeading;
- (NSInteger)revenant_order;
@end

@interface UICollectionLayoutListConfiguration (RevenantLists)
- (BOOL)revenant_showsSeparators;
- (UICollectionLayoutListAppearance)revenant_appearance;
@end

@interface UICollectionViewCompositionalLayout (RevenantLists)
- (UICollectionLayoutListConfiguration *)revenant_listConfiguration;
- (void)revenant_setListConfiguration:(UICollectionLayoutListConfiguration *)configuration;
- (void)revenant_beginNotingSections;
- (void)revenant_noteSection:(NSCollectionLayoutSection *)section;
- (UICollectionLayoutListConfiguration *)revenant_listConfigurationForSectionIndex:(NSInteger)index;
@end

@interface NSCollectionLayoutSection (RevenantLists)
- (UICollectionLayoutListConfiguration *)revenant_listConfiguration;
- (void)revenant_setListConfiguration:(UICollectionLayoutListConfiguration *)configuration;
@end

@interface UICollectionViewCell (RevenantListConfigurationLookup)
- (UICollectionLayoutListConfiguration *)revenant_layoutListConfiguration;
@end

@interface UIListContentView (RevenantTextLeading)
- (CGFloat)revenant_textLeading;
@end

@interface UILayoutGuide (RevenantLists)
- (void)revenant_pinFrame:(CGRect)frame inView:(UIView *)view;
@end

@interface UIView (RevenantListHost)
- (UIView *)revenant_configurationContainer;
- (UIViewConfigurationState *)revenant_makeConfigurationState;
- (void)revenant_setNeedsUpdateConfiguration;
- (void)revenant_layoutWillRun;
- (void)revenant_layoutDidRun;
@end

id<UIContentConfiguration> revenant_host_content(UIView *host);
void revenant_host_set_content(UIView *host, id<UIContentConfiguration> configuration);
UIBackgroundConfiguration *revenant_host_background(UIView *host);
void revenant_host_set_background(UIView *host, UIBackgroundConfiguration *configuration);
BOOL revenant_host_automatic(UIView *host, BOOL background);
void revenant_host_set_automatic(UIView *host, BOOL background, BOOL automatic);
void revenant_host_default_update(UIView *host, UIViewConfigurationState *state);
NSNumber *revenant_host_table_style(UITableViewCell *cell);
UIView *revenant_host_content_view(UIView *host);
void revenant_request_update(UIView *view);
id revenant_host_update_handler(UIView *host);
void revenant_host_set_update_handler(UIView *host, id handler);
UICollectionView *revenant_owning_collection_view(UIView *view);

@interface UICollectionView (RevenantLists)
- (BOOL)revenant_editing;
@end

@interface UICollectionViewCell (RevenantLists)
- (void)revenant_setListPrepared;
@end

@interface UICollectionViewListCell (RevenantOutline)
- (BOOL)revenant_isExpanded;
- (void)revenant_setExpanded:(BOOL)expanded animated:(BOOL)animated;
- (void)revenant_setExpansionHandler:(void (^)(void))handler;
- (void)revenant_toggleExpansion;
@end

@interface UIListSeparatorConfiguration (RevenantVisualEffect15)
- (void)revenant_takeVisualEffectFrom:(UIListSeparatorConfiguration *)other;
- (BOOL)revenant_visualEffectIsEqualTo:(UIListSeparatorConfiguration *)other;
- (void)revenant_encodeVisualEffectWithCoder:(NSCoder *)coder;
- (void)revenant_decodeVisualEffectWithCoder:(NSCoder *)coder;
@end
