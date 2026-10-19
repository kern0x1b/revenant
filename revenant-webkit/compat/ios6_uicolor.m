#import <UIKit/UIKit.h>
#import <objc/runtime.h>

typedef struct {
    const char *selector;
    CGFloat r, g, b, a;
} WebKitIOS6SystemColor;

static const WebKitIOS6SystemColor webKitIOS6SystemColors[] = {
    { "labelColor",                              0.000, 0.000, 0.000, 1.00 },
    { "secondaryLabelColor",                     0.235, 0.235, 0.263, 0.60 },
    { "tertiaryLabelColor",                      0.235, 0.235, 0.263, 0.30 },
    { "quaternaryLabelColor",                    0.235, 0.235, 0.263, 0.18 },
    { "placeholderTextColor",                    0.235, 0.235, 0.263, 0.30 },
    { "separatorColor",                          0.235, 0.235, 0.263, 0.29 },
    { "opaqueSeparatorColor",                    0.776, 0.776, 0.784, 1.00 },
    { "systemBackgroundColor",                   1.000, 1.000, 1.000, 1.00 },
    { "secondarySystemBackgroundColor",          0.949, 0.949, 0.969, 1.00 },
    { "tertiarySystemBackgroundColor",           1.000, 1.000, 1.000, 1.00 },
    { "systemGroupedBackgroundColor",            0.949, 0.949, 0.969, 1.00 },
    { "secondarySystemGroupedBackgroundColor",   1.000, 1.000, 1.000, 1.00 },
    { "tertiarySystemGroupedBackgroundColor",    0.949, 0.949, 0.969, 1.00 },
    { "systemFillColor",                         0.471, 0.471, 0.502, 0.20 },
    { "secondarySystemFillColor",                0.471, 0.471, 0.502, 0.16 },
    { "tertiarySystemFillColor",                 0.463, 0.463, 0.502, 0.12 },
    { "quaternarySystemFillColor",               0.455, 0.455, 0.502, 0.08 },
    { "systemBlueColor",                         0.000, 0.478, 1.000, 1.00 },
    { "systemBrownColor",                        0.635, 0.518, 0.369, 1.00 },
    { "systemGrayColor",                         0.557, 0.557, 0.576, 1.00 },
    { "systemGreenColor",                        0.204, 0.780, 0.349, 1.00 },
    { "systemIndigoColor",                       0.345, 0.337, 0.839, 1.00 },
    { "systemOrangeColor",                       1.000, 0.584, 0.000, 1.00 },
    { "systemPinkColor",                         1.000, 0.176, 0.333, 1.00 },
    { "systemPurpleColor",                       0.686, 0.322, 0.871, 1.00 },
    { "systemRedColor",                          1.000, 0.231, 0.188, 1.00 },
    { "systemTealColor",                         0.188, 0.690, 0.780, 1.00 },
    { "systemYellowColor",                       1.000, 0.800, 0.000, 1.00 },
    { "tableCellDefaultSelectionTintColor",      0.820, 0.820, 0.839, 1.00 },
};

static const size_t webKitIOS6SystemColorCount =
    sizeof(webKitIOS6SystemColors) / sizeof(webKitIOS6SystemColors[0]);

static id webKitIOS6SystemColorIMP(id self, SEL selector)
{
    static UIColor *cache[sizeof(webKitIOS6SystemColors) / sizeof(webKitIOS6SystemColors[0])];
    const char *name = sel_getName(selector);
    for (size_t i = 0; i < webKitIOS6SystemColorCount; i++) {
        if (strcmp(name, webKitIOS6SystemColors[i].selector))
            continue;
        if (!cache[i]) {
            const WebKitIOS6SystemColor *color = &webKitIOS6SystemColors[i];
            cache[i] = [[UIColor colorWithRed:color->r green:color->g blue:color->b alpha:color->a] retain];
        }
        return cache[i];
    }
    return [UIColor blackColor];
}

@interface UIColor (WebKitIOS6SystemColors)
@end

@implementation UIColor (WebKitIOS6SystemColors)

+ (void)load
{
    Class metaclass = object_getClass([UIColor class]);
    for (size_t i = 0; i < webKitIOS6SystemColorCount; i++) {
        SEL selector = sel_registerName(webKitIOS6SystemColors[i].selector);
        class_addMethod(metaclass, selector, (IMP)webKitIOS6SystemColorIMP, "@@:");
    }
}

@end
