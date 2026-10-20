#import <UIKit/UIKit.h>

NSDictionary *revenant_attributes_merge(NSDictionary *base, NSDictionary *over);
NSDictionary *revenant_attributes_carried(NSDictionary *custom, BOOL colour, BOOL disabled);
NSString *revenant_attributes_text(NSDictionary *custom);
UIColor *revenant_disabled_colour(UIColor *colour);
UIFont *revenant_font(CGFloat size, CGFloat weight);
UIColor *revenant_label_colour(void);
UIColor *revenant_secondary_label_colour(void);
UIColor *revenant_default_shadow_colour(void);
UIColor *revenant_white_colour(void);
NSArray *revenant_offset_pack(UIOffset offset);
UIOffset revenant_offset_unpack(NSArray *packed);
NSString *revenant_offset_text(NSArray *packed);
BOOL revenant_same(id first, id second);
NSString *revenant_text(id object);
id revenant_plist_pack(id object);
id revenant_plist_unpack(id object);
NSSet *revenant_plist_classes(void);
void revenant_bar_say_once(NSString *key, NSString *text);
void revenant_adopt_child(UIBarAppearance *owner, id child);
UIImage *revenant_solid_image(UIColor *colour);
NSDictionary *revenant_bar_text_attributes(NSDictionary *attributes);
NSMutableDictionary *revenant_sanitised(id decoded, NSDictionary *classes, NSSet *nullable);

@class UIBarButtonItemAppearance, UITabBarItemAppearance;

@interface UIBarButtonItemStateAppearance (RevenantBarAppearance)
- (instancetype)initRevenantWithOwner:(UIBarButtonItemAppearance *)owner state:(NSInteger)state;
- (NSMutableDictionary *)revenant_custom;
- (NSString *)revenant_text;
@end

@interface UIBarButtonItemAppearance (RevenantBarAppearance)
- (instancetype)initRevenantWithStyle:(NSInteger)style;
- (void)revenant_setUpStyle:(NSInteger)style;
- (NSInteger)revenant_style;
- (UIBarButtonItemAppearance *)revenant_basedOn;
- (id)revenant_resolveState:(NSInteger)state key:(NSString *)key;
- (NSDictionary *)revenant_customOfState:(NSInteger)state;
- (void)revenant_becomeBackButtonBasedOn:(UIBarButtonItemAppearance *)button;
- (void)revenant_setBackIndicator:(UIImage *)image mask:(UIImage *)mask;
- (UIImage *)revenant_backIndicator;
- (UIImage *)revenant_backMask;
- (NSString *)revenant_text;
- (NSArray *)revenant_signature;
- (void)revenant_setChangeObserver:(void (^)(void))observer;
- (void)revenant_notify;
@end

@interface UITabBarItemStateAppearance (RevenantBarAppearance)
- (instancetype)initRevenantWithOwner:(UITabBarItemAppearance *)owner state:(NSInteger)state;
- (NSMutableDictionary *)revenant_custom;
- (NSString *)revenant_text;
@end

@interface UITabBarItemAppearance (RevenantBarAppearance)
- (instancetype)initRevenantWithStyle:(NSInteger)style;
- (void)revenant_setUpStyle:(NSInteger)style;
- (NSInteger)revenant_style;
- (id)revenant_resolveState:(NSInteger)state key:(NSString *)key;
- (NSDictionary *)revenant_customOfState:(NSInteger)state;
- (NSString *)revenant_text;
- (NSArray *)revenant_signature;
- (void)revenant_setChangeObserver:(void (^)(void))observer;
- (void)revenant_notify;
@end

@interface UIBarAppearance (RevenantBarAppearance)
- (NSMutableDictionary *)revenant_values;
- (void)revenant_setUp;
- (NSArray *)revenant_lines;
- (NSArray *)revenant_signature;
- (void)revenant_configureTransparent;
- (void)revenant_encodeExtrasWithCoder:(NSCoder *)coder;
- (void)revenant_decodeExtrasWithCoder:(NSCoder *)coder;
- (void)revenant_copyExtrasFrom:(UIBarAppearance *)source;
- (void)revenant_setChangeObserver:(void (^)(void))observer;
- (void)revenant_notify;
@end

@interface UINavigationBarAppearance (RevenantBarAppearance)
- (NSDictionary *)revenant_titleCustom;
@end

id revenant_appearance_get(id owner, const void *key, Class kind, SEL changed);
void revenant_appearance_set(id owner, const void *key, id appearance, SEL changed);
id revenant_appearance_peek(id owner, const void *key);
void revenant_appearance_store(id owner, const void *key, id appearance);
BOOL revenant_flag_get(id owner, const void *key);
void revenant_flag_set(id owner, const void *key, BOOL value);
void revenant_schedule(id owner, SEL apply, const void *pendingKey);

void revenant_apply_navigation_bar(UINavigationBar *bar, UINavigationBarAppearance *standard, UINavigationBarAppearance *compact);
void revenant_apply_toolbar(UIToolbar *bar, UIToolbarAppearance *standard, UIToolbarAppearance *compact);
void revenant_apply_tab_bar(UITabBar *bar, UITabBarAppearance *standard);

@interface UINavigationBar (RevenantAppearanceRefresh)
- (void)revenant_refreshForced:(BOOL)force;
- (void)revenant_otherChanged;
@end

@interface UIToolbar (RevenantAppearanceRefresh)
- (void)revenant_refreshForced:(BOOL)force;
- (void)revenant_otherChanged;
@end

@interface UITabBar (RevenantAppearanceRefresh)
- (void)revenant_refreshForced:(BOOL)force;
- (void)revenant_otherChanged;
@end

@interface UINavigationItem (RevenantAppearanceRefresh)
- (void)revenant_appearanceChanged;
@end

@interface UITabBarItem (RevenantAppearanceRefresh)
- (void)revenant_appearanceChanged;
@end

id revenant_first_appearance(id first, id second, id third, id fourth, id fifth, id sixth);
BOOL revenant_bar_at_edge(UIView *bar, BOOL bottom);
UIScrollView *revenant_bar_scroll_view(UIView *bar);
void revenant_track_bar(UIView *bar);
void revenant_refresh_bars_showing(id item);
BOOL revenant_bar_needs_refresh(UIView *bar, NSString *signature);
void revenant_appearance_store_observed(id owner, const void *key, id appearance, SEL changed);
