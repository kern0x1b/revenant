#import "CharonMenus.h"
#import <objc/runtime.h>

static const char charon_ignores_key;

@implementation UIView (CharonInvertColors)

- (BOOL)accessibilityIgnoresInvertColors
{
    return [objc_getAssociatedObject(self, &charon_ignores_key) boolValue];
}

- (void)setAccessibilityIgnoresInvertColors:(BOOL)ignores
{
    if (ignores)
        charon_menus_say_once(@"invert-colors", @"UIView.accessibilityIgnoresInvertColors: iOS 6 inverts the whole screen in the render server and cannot leave one view out, so the flag is kept and read back and the view is inverted with the rest");
    objc_setAssociatedObject(self, &charon_ignores_key, @(ignores ? YES : NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
