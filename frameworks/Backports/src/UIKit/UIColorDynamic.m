#import "RevenantTraitStyle.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

typedef UIColor *(^RevenantColorProvider)(UITraitCollection *traits);

static const char revenant_provider_key;
static const char revenant_layer_providers_key;

static void revenant_install_layer_colour_hooks(void);

static NSMapTable *revenant_carriers_by_cgcolor(void)
{
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality valueOptions:NSPointerFunctionsWeakMemory];
    });
    return table;
}

static UIColor *revenant_resolve(UIColor *color, UITraitCollection *traits)
{
    RevenantColorProvider provider = objc_getAssociatedObject(color, &revenant_provider_key);
    if (!provider)
        return color;
    UIColor *resolved = provider(traits);
    return resolved ? revenant_resolve(resolved, traits) : nil;
}

static UIColor *revenant_carrier(RevenantColorProvider provider, UITraitCollection *traits)
{
    UIColor *base = revenant_resolve(provider(traits), traits);
    CGColorRef colour = CGColorCreateCopy(base ? base.CGColor : [UIColor clearColor].CGColor);
    UIColor *carrier = [[UIColor alloc] initWithCGColor:colour];
    CGColorRelease(colour);
    objc_setAssociatedObject(carrier, &revenant_provider_key, [provider copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [revenant_carriers_by_cgcolor() setObject:carrier forKey:(__bridge id)carrier.CGColor];
    revenant_install_layer_colour_hooks();
    return carrier;
}

static UIColor *revenant_dynamic(RevenantColorProvider provider)
{
    return revenant_carrier(provider, [UITraitCollection currentTraitCollection]);
}

UIColor *revenant_color_for_traits(UIColor *color, UITraitCollection *traits)
{
    if (!color)
        return nil;
    RevenantColorProvider provider = objc_getAssociatedObject(color, &revenant_provider_key);
    return provider ? revenant_carrier(provider, traits) : color;
}

static void revenant_remember_layer_colour(CALayer *layer, NSString *name, CGColorRef colour)
{
    UIColor *carrier = colour ? [revenant_carriers_by_cgcolor() objectForKey:(__bridge id)colour] : nil;
    RevenantColorProvider provider = carrier ? objc_getAssociatedObject(carrier, &revenant_provider_key) : nil;
    NSMutableDictionary *providers = objc_getAssociatedObject(layer, &revenant_layer_providers_key);
    if (!provider) {
        [providers removeObjectForKey:name];
        return;
    }
    if (!providers) {
        providers = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(layer, &revenant_layer_providers_key, providers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [providers setObject:provider forKey:name];
}

static void revenant_hook_layer_colour(SEL selector, NSString *name)
{
    Method method = class_getInstanceMethod([CALayer class], selector);
    void (*original)(id, SEL, CGColorRef) = (void (*)(id, SEL, CGColorRef))method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^(CALayer *layer, CGColorRef colour) {
        revenant_remember_layer_colour(layer, name, colour);
        original(layer, selector, colour);
    }));
}

static void revenant_install_layer_colour_hooks(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_hook_layer_colour(@selector(setBorderColor:), @"borderColor");
        revenant_hook_layer_colour(@selector(setShadowColor:), @"shadowColor");
    });
}

static void revenant_refresh_layer_colours(CALayer *layer, UITraitCollection *traits)
{
    NSDictionary *providers = [objc_getAssociatedObject(layer, &revenant_layer_providers_key) copy];
    [providers enumerateKeysAndObjectsUsingBlock:^(NSString *name, id value, BOOL *stop) {
        RevenantColorProvider provider = value;
        UIColor *colour = revenant_carrier(provider, traits);
        if ([name isEqualToString:@"shadowColor"])
            layer.shadowColor = colour.CGColor;
        else
            layer.borderColor = colour.CGColor;
    }];
}

void revenant_refresh_view_colours(UIView *view)
{
    UITraitCollection *traits = view.traitCollection;
    UIColor *background = view.backgroundColor;
    UIColor *resolvedBackground = revenant_color_for_traits(background, traits);
    if (resolvedBackground != background)
        view.backgroundColor = resolvedBackground;
    UIColor *tint = revenant_view_stored_tint(view);
    UIColor *resolvedTint = revenant_color_for_traits(tint, traits);
    if (resolvedTint != tint)
        view.tintColor = resolvedTint;
    id target = view;
    if ([target respondsToSelector:@selector(textColor)]) {
        UIColor *text = [target textColor];
        UIColor *resolved = revenant_color_for_traits(text, traits);
        if (resolved != text)
            [target setTextColor:resolved];
    }
    if ([target respondsToSelector:@selector(highlightedTextColor)]) {
        UIColor *highlighted = [target highlightedTextColor];
        UIColor *resolved = revenant_color_for_traits(highlighted, traits);
        if (resolved != highlighted)
            [target setHighlightedTextColor:resolved];
    }
    revenant_refresh_layer_colours(view.layer, traits);
}

typedef struct {
    double light[4], dark[4], lightHigh[4], darkHigh[4], darkElevated[4], darkElevatedHigh[4];
} RevenantColorRow;

#define C(r, g, b, a) {r / 255.0, g / 255.0, b / 255.0, a}
#define SAME {-1, 0, 0, 0}

static const RevenantColorRow revenant_rows[] = {
    [0] = {C(0, 0, 0, 1), C(255, 255, 255, 1), SAME, SAME, SAME, SAME},
    [1] = {C(60, 60, 67, 153 / 255.0), C(235, 235, 245, 153 / 255.0), C(60, 60, 67, 204 / 255.0), C(235, 235, 245, 178 / 255.0), SAME, SAME},
    [2] = {C(60, 60, 67, 76 / 255.0), C(235, 235, 245, 76 / 255.0), C(60, 60, 67, 178 / 255.0), C(235, 235, 245, 140 / 255.0), SAME, SAME},
    [3] = {C(60, 60, 67, 45 / 255.0), C(235, 235, 245, 40 / 255.0), C(60, 60, 67, 140 / 255.0), C(235, 235, 245, 102 / 255.0), SAME, SAME},
    [4] = {C(0, 122, 255, 1), C(9, 132, 255, 1), SAME, SAME, SAME, SAME},
    [5] = {C(60, 60, 67, 0.3), C(235, 235, 245, 0.3), SAME, SAME, SAME, SAME},
    [6] = {C(60, 60, 67, 0.29), C(84, 84, 88, 0.6), C(60, 60, 67, 0.37), C(84, 84, 88, 0.68), SAME, SAME},
    [7] = {C(198, 198, 200, 1), C(56, 56, 58, 1), SAME, SAME, SAME, SAME},
    [8] = {C(255, 255, 255, 1), C(0, 0, 0, 1), SAME, SAME, C(28, 28, 30, 1), C(36, 36, 38, 1)},
    [9] = {C(242, 242, 247, 1), C(28, 28, 30, 1), C(235, 235, 240, 1), C(36, 36, 38, 1), C(44, 44, 46, 1), C(54, 54, 56, 1)},
    [10] = {C(255, 255, 255, 1), C(44, 44, 46, 1), SAME, C(54, 54, 56, 1), C(58, 58, 60, 1), C(68, 68, 70, 1)},
    [11] = {C(242, 242, 247, 1), C(0, 0, 0, 1), C(235, 235, 240, 1), SAME, C(28, 28, 30, 1), C(36, 36, 38, 1)},
    [12] = {C(255, 255, 255, 1), C(28, 28, 30, 1), SAME, C(36, 36, 38, 1), C(44, 44, 46, 1), C(54, 54, 56, 1)},
    [13] = {C(242, 242, 247, 1), C(44, 44, 46, 1), C(235, 235, 240, 1), C(54, 54, 56, 1), C(58, 58, 60, 1), C(68, 68, 70, 1)},
    [14] = {C(120, 120, 128, 0.2), C(120, 120, 128, 0.36), C(120, 120, 128, 0.28), C(120, 120, 128, 0.44), SAME, SAME},
    [15] = {C(120, 120, 128, 0.16), C(120, 120, 128, 0.32), C(120, 120, 128, 0.24), C(120, 120, 128, 0.4), SAME, SAME},
    [16] = {C(118, 118, 128, 0.12), C(118, 118, 128, 0.24), C(118, 118, 128, 0.2), C(118, 118, 128, 0.32), SAME, SAME},
    [17] = {C(116, 116, 128, 0.08), C(118, 118, 128, 0.18), C(116, 116, 128, 0.16), C(118, 118, 128, 0.26), SAME, SAME},
    [18] = {C(174, 174, 178, 1), C(99, 99, 102, 1), C(142, 142, 147, 1), C(124, 124, 128, 1), SAME, SAME},
    [19] = {C(199, 199, 204, 1), C(72, 72, 74, 1), C(174, 174, 178, 1), C(84, 84, 86, 1), SAME, SAME},
    [20] = {C(209, 209, 214, 1), C(58, 58, 60, 1), C(188, 188, 192, 1), C(68, 68, 70, 1), SAME, SAME},
    [21] = {C(229, 229, 234, 1), C(44, 44, 46, 1), C(216, 216, 220, 1), C(54, 54, 56, 1), SAME, SAME},
    [22] = {C(242, 242, 247, 1), C(28, 28, 30, 1), C(235, 235, 240, 1), C(36, 36, 38, 1), SAME, SAME},
    [23] = {C(162, 132, 94, 1), C(172, 142, 104, 1), C(127, 101, 69, 1), C(181, 148, 105, 1), SAME, SAME},
    [24] = {C(88, 86, 214, 1), C(94, 92, 230, 1), C(54, 52, 163, 1), C(125, 122, 255, 1), SAME, SAME},
    [25] = {C(50, 173, 230, 1), C(100, 210, 255, 1), C(0, 113, 164, 1), C(112, 215, 255, 1), SAME, SAME},
    [26] = {C(0, 199, 190, 1), C(99, 230, 226, 1), C(12, 129, 123, 1), SAME, SAME, SAME},
    [27] = {C(255, 59, 48, 1), C(255, 69, 58, 1), C(215, 0, 21, 1), C(255, 105, 97, 1), SAME, SAME},
    [28] = {C(52, 199, 89, 1), C(48, 209, 88, 1), C(36, 138, 61, 1), C(48, 219, 91, 1), SAME, SAME},
    [29] = {C(0, 122, 255, 1), C(10, 132, 255, 1), C(0, 64, 221, 1), C(64, 156, 255, 1), SAME, SAME},
    [30] = {C(255, 149, 0, 1), C(255, 159, 10, 1), C(201, 52, 0, 1), C(255, 179, 64, 1), SAME, SAME},
    [31] = {C(255, 204, 0, 1), C(255, 214, 10, 1), C(178, 80, 0, 1), C(255, 212, 38, 1), SAME, SAME},
    [32] = {C(255, 45, 85, 1), C(255, 55, 95, 1), C(211, 15, 69, 1), C(255, 100, 130, 1), SAME, SAME},
    [33] = {C(48, 176, 199, 1), C(64, 200, 224, 1), C(0, 130, 153, 1), C(93, 230, 255, 1), SAME, SAME},
    [34] = {C(142, 142, 147, 1), C(142, 142, 147, 1), C(108, 108, 112, 1), C(174, 174, 178, 1), SAME, SAME},
    [35] = {C(175, 82, 222, 1), C(191, 90, 242, 1), C(137, 68, 171, 1), C(218, 143, 255, 1), SAME, SAME},
};

static UIColor *revenant_row_color(const double *values)
{
    return [UIColor colorWithRed:(CGFloat)values[0] green:(CGFloat)values[1] blue:(CGFloat)values[2] alpha:(CGFloat)values[3]];
}

static UIColor *revenant_system_color(NSUInteger row)
{
    static UIColor *cache[sizeof(revenant_rows) / sizeof(revenant_rows[0])];
    static dispatch_once_t once;
    static NSObject *lock;
    dispatch_once(&once, ^{
        lock = [[NSObject alloc] init];
    });
    @synchronized (lock) {
        if (!cache[row]) {
            cache[row] = revenant_dynamic(^UIColor *(UITraitCollection *traits) {
                const RevenantColorRow *entry = &revenant_rows[row];
                BOOL dark = traits.userInterfaceStyle == UIUserInterfaceStyleDark;
                BOOL high = traits.accessibilityContrast == UIAccessibilityContrastHigh;
                const double *values = dark ? entry->dark : entry->light;
                if (high && (dark ? entry->darkHigh[0] : entry->lightHigh[0]) >= 0)
                    values = dark ? entry->darkHigh : entry->lightHigh;
                if (dark && traits.userInterfaceLevel == UIUserInterfaceLevelElevated) {
                    if (high && entry->darkElevatedHigh[0] >= 0)
                        values = entry->darkElevatedHigh;
                    else if (entry->darkElevated[0] >= 0)
                        values = entry->darkElevated;
                }
                return revenant_row_color(values);
            });
        }
        return cache[row];
    }
}

UIColor *revenant_system_colour(NSUInteger row)
{
    return revenant_system_color(row);
}

@implementation UIColor (RevenantDynamicColor)

+ (UIColor *)colorWithDynamicProvider:(UIColor * (^)(UITraitCollection *))dynamicProvider
{
    return revenant_dynamic(dynamicProvider);
}

- (UIColor *)initWithDynamicProvider:(UIColor * (^)(UITraitCollection *))dynamicProvider
{
    return revenant_dynamic(dynamicProvider);
}

- (UIColor *)resolvedColorWithTraitCollection:(UITraitCollection *)traitCollection
{
    return revenant_resolve(self, traitCollection);
}

+ (UIColor *)labelColor { return revenant_system_color(0); }
+ (UIColor *)secondaryLabelColor { return revenant_system_color(1); }
+ (UIColor *)tertiaryLabelColor { return revenant_system_color(2); }
+ (UIColor *)quaternaryLabelColor { return revenant_system_color(3); }
+ (UIColor *)linkColor { return revenant_system_color(4); }
+ (UIColor *)placeholderTextColor { return revenant_system_color(5); }
+ (UIColor *)separatorColor { return revenant_system_color(6); }
+ (UIColor *)opaqueSeparatorColor { return revenant_system_color(7); }
+ (UIColor *)systemBackgroundColor { return revenant_system_color(8); }
+ (UIColor *)secondarySystemBackgroundColor { return revenant_system_color(9); }
+ (UIColor *)tertiarySystemBackgroundColor { return revenant_system_color(10); }
+ (UIColor *)systemGroupedBackgroundColor { return revenant_system_color(11); }
+ (UIColor *)secondarySystemGroupedBackgroundColor { return revenant_system_color(12); }
+ (UIColor *)tertiarySystemGroupedBackgroundColor { return revenant_system_color(13); }
+ (UIColor *)systemFillColor { return revenant_system_color(14); }
+ (UIColor *)secondarySystemFillColor { return revenant_system_color(15); }
+ (UIColor *)tertiarySystemFillColor { return revenant_system_color(16); }
+ (UIColor *)quaternarySystemFillColor { return revenant_system_color(17); }
+ (UIColor *)systemGray2Color { return revenant_system_color(18); }
+ (UIColor *)systemGray3Color { return revenant_system_color(19); }
+ (UIColor *)systemGray4Color { return revenant_system_color(20); }
+ (UIColor *)systemGray5Color { return revenant_system_color(21); }
+ (UIColor *)systemGray6Color { return revenant_system_color(22); }
+ (UIColor *)systemBrownColor { return revenant_system_color(23); }
+ (UIColor *)systemIndigoColor { return revenant_system_color(24); }
+ (UIColor *)systemCyanColor { return revenant_system_color(25); }
+ (UIColor *)systemMintColor { return revenant_system_color(26); }

@end
