#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char revenant_ignores_key;

@implementation UIView (RevenantInvertColors)

- (BOOL)accessibilityIgnoresInvertColors
{
    return [objc_getAssociatedObject(self, &revenant_ignores_key) boolValue];
}

- (void)setAccessibilityIgnoresInvertColors:(BOOL)ignores
{
    if (ignores)
        revenant_menus_say_once(@"invert-colors", @"UIView.accessibilityIgnoresInvertColors: iOS 6 inverts the whole screen in the render server and cannot leave one view out, so the flag is kept and read back and the view is inverted with the rest");
    objc_setAssociatedObject(self, &revenant_ignores_key, @(ignores ? YES : NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
