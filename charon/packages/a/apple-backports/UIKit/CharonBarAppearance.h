#import <UIKit/UIKit.h>

NSDictionary *charon_attributes_merge(NSDictionary *base, NSDictionary *over);
NSDictionary *charon_attributes_carried(NSDictionary *custom, BOOL colour, BOOL disabled);
NSString *charon_attributes_text(NSDictionary *custom);
UIColor *charon_disabled_colour(UIColor *colour);
UIFont *charon_font(CGFloat size, CGFloat weight);
UIColor *charon_label_colour(void);
UIColor *charon_secondary_label_colour(void);
UIColor *charon_default_shadow_colour(void);
UIColor *charon_white_colour(void);
NSArray *charon_offset_pack(UIOffset offset);
UIOffset charon_offset_unpack(NSArray *packed);
NSString *charon_offset_text(NSArray *packed);
BOOL charon_same(id first, id second);
NSString *charon_text(id object);
id charon_plist_pack(id object);
id charon_plist_unpack(id object);
NSSet *charon_plist_classes(void);
void charon_bar_say_once(NSString *key, NSString *text);
void charon_adopt_child(UIBarAppearance *owner, id child);
UIImage *charon_solid_image(UIColor *colour);
NSDictionary *charon_bar_text_attributes(NSDictionary *attributes);
NSMutableDictionary *charon_sanitised(id decoded, NSDictionary *classes, NSSet *nullable);

@class UIBarButtonItemAppearance, UITabBarItemAppearance;

@interface UIBarButtonItemStateAppearance (CharonBarAppearance)
- (instancetype)initCharonWithOwner:(UIBarButtonItemAppearance *)owner state:(NSInteger)state;
- (NSMutableDictionary *)charon_custom;
- (NSString *)charon_text;
@end

@interface UIBarButtonItemAppearance (CharonBarAppearance)
- (instancetype)initCharonWithStyle:(NSInteger)style;
- (void)charon_setUpStyle:(NSInteger)style;
- (NSInteger)charon_style;
- (UIBarButtonItemAppearance *)charon_basedOn;
- (id)charon_resolveState:(NSInteger)state key:(NSString *)key;
- (NSDictionary *)charon_customOfState:(NSInteger)state;
- (void)charon_becomeBackButtonBasedOn:(UIBarButtonItemAppearance *)button;
- (void)charon_setBackIndicator:(UIImage *)image mask:(UIImage *)mask;
- (UIImage *)charon_backIndicator;
- (UIImage *)charon_backMask;
- (NSString *)charon_text;
- (NSArray *)charon_signature;
- (void)charon_setChangeObserver:(void (^)(void))observer;
- (void)charon_notify;
@end

@interface UITabBarItemStateAppearance (CharonBarAppearance)
- (instancetype)initCharonWithOwner:(UITabBarItemAppearance *)owner state:(NSInteger)state;
- (NSMutableDictionary *)charon_custom;
- (NSString *)charon_text;
@end

@interface UITabBarItemAppearance (CharonBarAppearance)
- (instancetype)initCharonWithStyle:(NSInteger)style;
- (void)charon_setUpStyle:(NSInteger)style;
- (NSInteger)charon_style;
- (id)charon_resolveState:(NSInteger)state key:(NSString *)key;
- (NSDictionary *)charon_customOfState:(NSInteger)state;
- (NSString *)charon_text;
- (NSArray *)charon_signature;
- (void)charon_setChangeObserver:(void (^)(void))observer;
- (void)charon_notify;
@end

@interface UIBarAppearance (CharonBarAppearance)
- (NSMutableDictionary *)charon_values;
- (void)charon_setUp;
- (NSArray *)charon_lines;
- (NSArray *)charon_signature;
- (void)charon_configureTransparent;
- (void)charon_encodeExtrasWithCoder:(NSCoder *)coder;
- (void)charon_decodeExtrasWithCoder:(NSCoder *)coder;
- (void)charon_copyExtrasFrom:(UIBarAppearance *)source;
- (void)charon_setChangeObserver:(void (^)(void))observer;
- (void)charon_notify;
@end

@interface UINavigationBarAppearance (CharonBarAppearance)
- (NSDictionary *)charon_titleCustom;
@end

id charon_appearance_get(id owner, const void *key, Class kind, SEL changed);
void charon_appearance_set(id owner, const void *key, id appearance, SEL changed);
id charon_appearance_peek(id owner, const void *key);
void charon_appearance_store(id owner, const void *key, id appearance);
BOOL charon_flag_get(id owner, const void *key);
void charon_flag_set(id owner, const void *key, BOOL value);
void charon_schedule(id owner, SEL apply, const void *pendingKey);

void charon_apply_navigation_bar(UINavigationBar *bar, UINavigationBarAppearance *standard, UINavigationBarAppearance *compact);
void charon_apply_toolbar(UIToolbar *bar, UIToolbarAppearance *standard, UIToolbarAppearance *compact);
void charon_apply_tab_bar(UITabBar *bar, UITabBarAppearance *standard);

@interface UINavigationBar (CharonAppearanceRefresh)
- (void)charon_refreshForced:(BOOL)force;
- (void)charon_otherChanged;
@end

@interface UIToolbar (CharonAppearanceRefresh)
- (void)charon_refreshForced:(BOOL)force;
- (void)charon_otherChanged;
@end

@interface UITabBar (CharonAppearanceRefresh)
- (void)charon_refreshForced:(BOOL)force;
- (void)charon_otherChanged;
@end

@interface UINavigationItem (CharonAppearanceRefresh)
- (void)charon_appearanceChanged;
@end

@interface UITabBarItem (CharonAppearanceRefresh)
- (void)charon_appearanceChanged;
@end

id charon_first_appearance(id first, id second, id third, id fourth, id fifth, id sixth);
BOOL charon_bar_at_edge(UIView *bar, BOOL bottom);
UIScrollView *charon_bar_scroll_view(UIView *bar);
void charon_track_bar(UIView *bar);
void charon_refresh_bars_showing(id item);
BOOL charon_bar_needs_refresh(UIView *bar, NSString *signature);
void charon_appearance_store_observed(id owner, const void *key, id appearance, SEL changed);
