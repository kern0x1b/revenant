#import "CharonMenus.h"

typedef NS_ENUM(NSInteger, CharonListStyle) {
    CharonListStyleBare,
    CharonListStyleCell,
    CharonListStyleSubtitle,
    CharonListStyleValue,
    CharonListStylePlainHeader,
    CharonListStylePlainFooter,
    CharonListStyleGroupedHeader,
    CharonListStyleGroupedFooter,
    CharonListStyleSidebarCell,
    CharonListStyleSidebarSubtitle,
    CharonListStyleAccompaniedSidebar,
    CharonListStyleAccompaniedSidebarSubtitle,
    CharonListStyleSidebarHeader,
    CharonListStyleHeader,
    CharonListStyleFooter
};

typedef NS_ENUM(NSInteger, CharonBackgroundStyle) {
    CharonBackgroundStyleCustom,
    CharonBackgroundStyleListPlainCell,
    CharonBackgroundStyleListPlainHeaderFooter,
    CharonBackgroundStyleListGroupedCell,
    CharonBackgroundStyleListGroupedHeaderFooter,
    CharonBackgroundStyleListSidebarHeader,
    CharonBackgroundStyleListSidebarCell,
    CharonBackgroundStyleListAccompaniedSidebarCell,
    CharonBackgroundStyleListCell
};

typedef NS_ENUM(NSInteger, CharonSemanticColor) {
    CharonSemanticColorLabel,
    CharonSemanticColorSecondaryLabel,
    CharonSemanticColorTertiaryLabel,
    CharonSemanticColorQuaternaryLabel,
    CharonSemanticColorSystemBackground,
    CharonSemanticColorSecondarySystemGroupedBackground,
    CharonSemanticColorSystemGray4,
    CharonSemanticColorQuaternarySystemFill,
    CharonSemanticColorSeparator
};

static inline UIColor *charon_semantic_color(CharonSemanticColor which)
{
    static const SEL selectors[] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    (void)selectors;
    switch (which) {
    case CharonSemanticColorLabel:
        return [UIColor respondsToSelector:@selector(labelColor)] ? [UIColor labelColor] : [UIColor blackColor];
    case CharonSemanticColorSecondaryLabel:
        return [UIColor respondsToSelector:@selector(secondaryLabelColor)] ? [UIColor secondaryLabelColor] : [UIColor colorWithRed:60.0 / 255 green:60.0 / 255 blue:67.0 / 255 alpha:0.6];
    case CharonSemanticColorTertiaryLabel:
        return [UIColor respondsToSelector:@selector(tertiaryLabelColor)] ? [UIColor tertiaryLabelColor] : [UIColor colorWithRed:60.0 / 255 green:60.0 / 255 blue:67.0 / 255 alpha:0.3];
    case CharonSemanticColorQuaternaryLabel:
        return [UIColor respondsToSelector:@selector(quaternaryLabelColor)] ? [UIColor quaternaryLabelColor] : [UIColor colorWithRed:60.0 / 255 green:60.0 / 255 blue:67.0 / 255 alpha:0.18];
    case CharonSemanticColorSystemBackground:
        return [UIColor respondsToSelector:@selector(systemBackgroundColor)] ? [UIColor systemBackgroundColor] : [UIColor whiteColor];
    case CharonSemanticColorSecondarySystemGroupedBackground:
        return [UIColor respondsToSelector:@selector(secondarySystemGroupedBackgroundColor)] ? [UIColor secondarySystemGroupedBackgroundColor] : [UIColor whiteColor];
    case CharonSemanticColorSystemGray4:
        return [UIColor respondsToSelector:@selector(systemGray4Color)] ? [UIColor systemGray4Color] : [UIColor colorWithRed:209.0 / 255 green:209.0 / 255 blue:214.0 / 255 alpha:1];
    case CharonSemanticColorQuaternarySystemFill:
        return [UIColor respondsToSelector:@selector(quaternarySystemFillColor)] ? [UIColor quaternarySystemFillColor] : [UIColor colorWithRed:116.0 / 255 green:116.0 / 255 blue:128.0 / 255 alpha:0.08];
    case CharonSemanticColorSeparator:
        return [UIColor respondsToSelector:@selector(separatorColor)] ? [UIColor separatorColor] : [UIColor colorWithRed:60.0 / 255 green:60.0 / 255 blue:67.0 / 255 alpha:0.29];
    }
    return nil;
}
NSString *charon_elided_text(NSString *text);
static inline CGFloat charon_screen_scale(void)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    return scale > 0 ? scale : 1;
}

static inline CGFloat charon_pixel_ceil(CGFloat value, CGFloat scale)
{
    return ceil(value * scale - 0.0001) / scale;
}

static inline CGFloat charon_pixel_round(CGFloat value, CGFloat scale)
{
    return round(value * scale) / scale;
}
UIFont *charon_medium_font(CGFloat pointSize);
UIFont *charon_medium_body_font(void);

@interface UIListContentTextProperties (CharonLists)
- (instancetype)initCharonWithStyle:(NSInteger)style secondary:(BOOL)secondary;
- (void)charon_setOwnerText:(NSString *)text;
- (BOOL)charon_fontCustomized;
- (BOOL)charon_colorCustomized;
- (void)charon_setDefaultFont:(UIFont *)font;
- (void)charon_setDefaultColor:(UIColor *)color;
- (void)charon_setTransformerNamed:(NSString *)name block:(UIConfigurationColorTransformer)block;
@end

@interface UIListContentImageProperties (CharonLists)
- (instancetype)initCharonDefault;
- (instancetype)initCharonBare;
- (void)charon_setOwnerImage:(UIImage *)image;
- (BOOL)charon_tintCustomized;
- (void)charon_setDefaultTintColor:(UIColor *)color;
- (void)charon_setTransformerNamed:(NSString *)name block:(UIConfigurationColorTransformer)block;
@end

@interface UIListContentConfiguration (CharonLists)
- (instancetype)initCharonWithStyle:(NSInteger)style;
- (NSInteger)charon_style;
- (BOOL)charon_isHeaderFooterStyle;
- (CGFloat)charon_alpha;
@end

@interface UIBackgroundConfiguration (CharonLists)
- (instancetype)initCharonWithStyle:(NSInteger)style;
- (NSInteger)charon_style;
@end

@interface UIListContentView (CharonLists)
- (CGSize)charon_sizeFittingWidth:(CGFloat)width;
@end

@interface UICellAccessoryCustomView (CharonLists)
- (BOOL)charon_hasDefaultPosition;
@end

@interface UICellAccessory (CharonLists)
- (UIView *)charon_makeView;
- (CGFloat)charon_width;
- (BOOL)charon_isLeading;
- (NSInteger)charon_order;
@end

@interface UICollectionLayoutListConfiguration (CharonLists)
- (BOOL)charon_showsSeparators;
- (UICollectionLayoutListAppearance)charon_appearance;
@end

@interface UICollectionViewCompositionalLayout (CharonLists)
- (UICollectionLayoutListConfiguration *)charon_listConfiguration;
- (void)charon_setListConfiguration:(UICollectionLayoutListConfiguration *)configuration;
- (void)charon_beginNotingSections;
- (void)charon_noteSection:(NSCollectionLayoutSection *)section;
- (UICollectionLayoutListConfiguration *)charon_listConfigurationForSectionIndex:(NSInteger)index;
@end

@interface NSCollectionLayoutSection (CharonLists)
- (UICollectionLayoutListConfiguration *)charon_listConfiguration;
- (void)charon_setListConfiguration:(UICollectionLayoutListConfiguration *)configuration;
@end

@interface UICollectionViewCell (CharonListConfigurationLookup)
- (UICollectionLayoutListConfiguration *)charon_layoutListConfiguration;
@end

@interface UIListContentView (CharonTextLeading)
- (CGFloat)charon_textLeading;
@end

@interface UILayoutGuide (CharonLists)
- (void)charon_pinFrame:(CGRect)frame inView:(UIView *)view;
@end

@interface UIView (CharonListHost)
- (UIView *)charon_configurationContainer;
- (UIViewConfigurationState *)charon_makeConfigurationState;
- (void)charon_setNeedsUpdateConfiguration;
- (void)charon_layoutWillRun;
- (void)charon_layoutDidRun;
@end

id<UIContentConfiguration> charon_host_content(UIView *host);
void charon_host_set_content(UIView *host, id<UIContentConfiguration> configuration);
UIBackgroundConfiguration *charon_host_background(UIView *host);
void charon_host_set_background(UIView *host, UIBackgroundConfiguration *configuration);
BOOL charon_host_automatic(UIView *host, BOOL background);
void charon_host_set_automatic(UIView *host, BOOL background, BOOL automatic);
void charon_host_default_update(UIView *host, UIViewConfigurationState *state);
NSNumber *charon_host_table_style(UITableViewCell *cell);
UIView *charon_host_content_view(UIView *host);
void charon_request_update(UIView *view);
id charon_host_update_handler(UIView *host);
void charon_host_set_update_handler(UIView *host, id handler);
UICollectionView *charon_owning_collection_view(UIView *view);

@interface UICollectionView (CharonLists)
- (BOOL)charon_editing;
@end

@interface UICollectionViewCell (CharonLists)
- (void)charon_setListPrepared;
@end

@interface UICollectionViewListCell (CharonOutline)
- (BOOL)charon_isExpanded;
- (void)charon_setExpanded:(BOOL)expanded animated:(BOOL)animated;
- (void)charon_setExpansionHandler:(void (^)(void))handler;
- (void)charon_toggleExpansion;
@end

@interface UIListSeparatorConfiguration (CharonVisualEffect15)
- (void)charon_takeVisualEffectFrom:(UIListSeparatorConfiguration *)other;
- (BOOL)charon_visualEffectIsEqualTo:(UIListSeparatorConfiguration *)other;
- (void)charon_encodeVisualEffectWithCoder:(NSCoder *)coder;
- (void)charon_decodeVisualEffectWithCoder:(NSCoder *)coder;
@end
