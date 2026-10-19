#import "CharonBarAppearance.h"
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

id charon_appearance_peek(id owner, const void *key)
{
    return objc_getAssociatedObject(owner, key);
}

void charon_appearance_store(id owner, const void *key, id appearance)
{
    objc_setAssociatedObject(owner, key, appearance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

BOOL charon_flag_get(id owner, const void *key)
{
    return [objc_getAssociatedObject(owner, key) boolValue];
}

void charon_flag_set(id owner, const void *key, BOOL value)
{
    objc_setAssociatedObject(owner, key, value ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void charon_observe(id owner, id appearance, SEL changed)
{
    __weak id weak = owner;
    [appearance charon_setChangeObserver:^{
        id strong = weak;
        if (strong)
            ((void (*)(id, SEL))objc_msgSend)(strong, changed);
    }];
}

id charon_appearance_get(id owner, const void *key, Class kind, SEL changed)
{
    id appearance = objc_getAssociatedObject(owner, key);
    if (!appearance) {
        appearance = [[kind alloc] init];
        charon_observe(owner, appearance, changed);
        objc_setAssociatedObject(owner, key, appearance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return appearance;
}

void charon_appearance_set(id owner, const void *key, id appearance, SEL changed)
{
    id stored = [appearance copy];
    if (stored)
        charon_observe(owner, stored, changed);
    objc_setAssociatedObject(owner, key, stored, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void charon_schedule(id owner, SEL apply, const void *pendingKey)
{
    if (charon_flag_get(owner, pendingKey))
        return;
    charon_flag_set(owner, pendingKey, YES);
    __weak id weak = owner;
    dispatch_async(dispatch_get_main_queue(), ^{
        id strong = weak;
        if (!strong)
            return;
        charon_flag_set(strong, pendingKey, NO);
        ((void (*)(id, SEL))objc_msgSend)(strong, apply);
    });
}

NSDictionary *charon_bar_text_attributes(NSDictionary *attributes)
{
    if (!attributes.count)
        return nil;
    NSMutableDictionary *translated = [NSMutableDictionary dictionary];
    if (attributes[NSFontAttributeName])
        translated[UITextAttributeFont] = attributes[NSFontAttributeName];
    if (attributes[NSForegroundColorAttributeName])
        translated[UITextAttributeTextColor] = attributes[NSForegroundColorAttributeName];
    id shadow = attributes[NSShadowAttributeName];
    Class shadowClass = NSClassFromString(@"NSShadow");
    if (shadowClass && [shadow isKindOfClass:shadowClass]) {
        CGSize size = [(NSShadow *)shadow shadowOffset];
        id colour = [(NSShadow *)shadow shadowColor];
        translated[UITextAttributeTextShadowOffset] = [NSValue valueWithUIOffset:UIOffsetMake(size.width, size.height)];
        if ([colour isKindOfClass:[UIColor class]])
            translated[UITextAttributeTextShadowColor] = colour;
    }
    return translated.count ? translated : nil;
}

static UIImage *charon_hairline(UIColor *colour)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1 / scale), NO, scale);
    [colour setFill];
    UIRectFill(CGRectMake(0, 0, 1, 1 / scale));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsZero];
}

static UIImage *charon_background_image(UIBarAppearance *appearance)
{
    if (appearance.backgroundImage)
        return appearance.backgroundImage;
    if (appearance.backgroundColor)
        return charon_solid_image(appearance.backgroundColor);
    if (!appearance.backgroundEffect)
        return charon_solid_image([UIColor clearColor]);
    return nil;
}

static UIImage *charon_shadow_image(UIBarAppearance *appearance, BOOL customBackground)
{
    if (appearance.shadowImage)
        return appearance.shadowImage;
    if (!customBackground)
        return nil;
    return appearance.shadowColor ? charon_hairline(appearance.shadowColor) : [[UIImage alloc] init];
}

static NSDictionary *charon_customised_attributes(UIBarButtonItemStateAppearance *state, UIBarButtonItemAppearance *appearance)
{
    UIBarButtonItemAppearance *plain = [[UIBarButtonItemAppearance alloc] initCharonWithStyle:[appearance charon_style] == 2 ? 2 : 0];
    NSInteger index = state == appearance.normal ? 0 : (state == appearance.highlighted ? 1 : 2);
    UIBarButtonItemStateAppearance *reference = index == 0 ? plain.normal : (index == 1 ? plain.highlighted : plain.disabled);
    return [state.titleTextAttributes isEqual:reference.titleTextAttributes] ? nil : charon_bar_text_attributes(state.titleTextAttributes);
}

static void charon_apply_buttons(UIBarButtonItem *proxy, UIBarButtonItemAppearance *plain, UIBarButtonItemAppearance *done, UIBarButtonItemAppearance *back, UIBarMetrics metrics,
                                 BOOL withText)
{
    UIControlState controlStates[3] = {UIControlStateNormal, UIControlStateHighlighted, UIControlStateDisabled};
    UIBarButtonItemStateAppearance *plainStates[3] = {plain.normal, plain.highlighted, plain.disabled};
    UIBarButtonItemStateAppearance *doneStates[3] = {done.normal, done.highlighted, done.disabled};
    UIBarButtonItemStateAppearance *backStates[3] = {back.normal, back.highlighted, back.disabled};
    for (int index = 0; index < 3; index++) {
        if (withText)
            [proxy setTitleTextAttributes:plain ? charon_customised_attributes(plainStates[index], plain) : nil forState:controlStates[index]];
        [proxy setBackgroundImage:plain ? plainStates[index].backgroundImage : nil forState:controlStates[index] style:UIBarButtonItemStylePlain barMetrics:metrics];
        [proxy setBackgroundImage:done ? doneStates[index].backgroundImage : nil forState:controlStates[index] style:UIBarButtonItemStyleDone barMetrics:metrics];
        if (back)
            [proxy setBackButtonBackgroundImage:backStates[index].backgroundImage forState:controlStates[index] barMetrics:metrics];
    }
    [proxy setTitlePositionAdjustment:plain ? plain.normal.titlePositionAdjustment : UIOffsetZero forBarMetrics:metrics];
    if (back)
        [proxy setBackButtonTitlePositionAdjustment:back.normal.titlePositionAdjustment forBarMetrics:metrics];
}

void charon_apply_navigation_bar(UINavigationBar *bar, UINavigationBarAppearance *standard, UINavigationBarAppearance *compact)
{
    if (![standard isKindOfClass:[UINavigationBarAppearance class]])
        standard = nil;
    if (![compact isKindOfClass:[UINavigationBarAppearance class]])
        compact = nil;
    UIImage *background = standard ? charon_background_image(standard) : nil;
    [bar setBackgroundImage:background forBarMetrics:UIBarMetricsDefault];
    [bar setBackgroundImage:compact ? charon_background_image(compact) : nil forBarMetrics:UIBarMetricsLandscapePhone];
    [bar setShadowImage:standard ? charon_shadow_image(standard, background != nil) : nil];
    bar.titleTextAttributes = standard ? charon_bar_text_attributes(standard.titleTextAttributes) : nil;
    [bar setTitleVerticalPositionAdjustment:standard.titlePositionAdjustment.vertical forBarMetrics:UIBarMetricsDefault];
    [bar setTitleVerticalPositionAdjustment:(compact ?: standard).titlePositionAdjustment.vertical forBarMetrics:UIBarMetricsLandscapePhone];
    UIBarButtonItem *proxy = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil];
    charon_apply_buttons(proxy, standard.buttonAppearance, standard.doneButtonAppearance, standard.backButtonAppearance, UIBarMetricsDefault, YES);
    UINavigationBarAppearance *landscape = compact ?: standard;
    charon_apply_buttons(proxy, landscape.buttonAppearance, landscape.doneButtonAppearance, landscape.backButtonAppearance, UIBarMetricsLandscapePhone, NO);
    if ([standard charon_titleCustom][@"largeTitle"])
        charon_bar_say_once(@"largeTitle", [NSString stringWithFormat:@"UINavigationBarAppearance: iOS %@ has no large title, so largeTitleTextAttributes are kept and not drawn", [UIDevice currentDevice].systemVersion]);
}

void charon_apply_toolbar(UIToolbar *bar, UIToolbarAppearance *standard, UIToolbarAppearance *compact)
{
    if (![standard isKindOfClass:[UIToolbarAppearance class]])
        standard = nil;
    if (![compact isKindOfClass:[UIToolbarAppearance class]])
        compact = nil;
    UIImage *background = standard ? charon_background_image(standard) : nil;
    [bar setBackgroundImage:background forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    [bar setBackgroundImage:compact ? charon_background_image(compact) : nil forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsLandscapePhone];
    [bar setShadowImage:standard ? charon_shadow_image(standard, background != nil) : nil forToolbarPosition:UIBarPositionAny];
    UIBarButtonItem *proxy = [UIBarButtonItem appearanceWhenContainedIn:[UIToolbar class], nil];
    charon_apply_buttons(proxy, standard.buttonAppearance, standard.doneButtonAppearance, nil, UIBarMetricsDefault, YES);
    UIToolbarAppearance *landscape = compact ?: standard;
    charon_apply_buttons(proxy, landscape.buttonAppearance, landscape.doneButtonAppearance, nil, UIBarMetricsLandscapePhone, NO);
}

static NSDictionary *charon_customised_item_attributes(UITabBarItemStateAppearance *state, UITabBarItemAppearance *appearance, BOOL selected)
{
    UITabBarItemAppearance *plain = [[UITabBarItemAppearance alloc] initCharonWithStyle:[appearance charon_style]];
    UITabBarItemStateAppearance *reference = selected ? plain.selected : plain.normal;
    return [state.titleTextAttributes isEqual:reference.titleTextAttributes] ? nil : charon_bar_text_attributes(state.titleTextAttributes);
}

void charon_apply_tab_bar(UITabBar *bar, UITabBarAppearance *standard)
{
    if (![standard isKindOfClass:[UITabBarAppearance class]])
        standard = nil;
    UIImage *background = standard ? charon_background_image(standard) : nil;
    bar.backgroundImage = background;
    bar.shadowImage = standard ? charon_shadow_image(standard, background != nil) : nil;
    bar.selectionIndicatorImage = standard.selectionIndicatorImage;
    bar.selectedImageTintColor = standard.stackedLayoutAppearance.selected.iconColor;
    UITabBarItem *proxy = [UITabBarItem appearanceWhenContainedIn:[UITabBar class], nil];
    UITabBarItemAppearance *stacked = standard.stackedLayoutAppearance;
    [proxy setTitleTextAttributes:stacked ? charon_customised_item_attributes(stacked.normal, stacked, NO) : nil forState:UIControlStateNormal];
    [proxy setTitleTextAttributes:stacked ? charon_customised_item_attributes(stacked.selected, stacked, YES) : nil forState:UIControlStateSelected];
    proxy.titlePositionAdjustment = stacked.normal.titlePositionAdjustment;
    if (stacked.normal.iconColor || standard.selectionIndicatorTintColor || standard.stackedItemWidth > 0 || standard.stackedItemSpacing > 0 || standard.stackedItemPositioning != UITabBarItemPositioningAutomatic)
        charon_bar_say_once(@"tabLayout", [NSString stringWithFormat:@"UITabBarAppearance: iOS %@ has one tab layout, an icon colour only for the selected tab and no selection indicator tint, so the icon colour of an unselected tab, the tint and the width, spacing and positioning of the items are kept and not drawn",
                                                                     [UIDevice currentDevice].systemVersion]);
}
