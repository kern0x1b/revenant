#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_style_key;

@implementation UISplitViewController (CharonBackground13)

- (UISplitViewControllerBackgroundStyle)primaryBackgroundStyle
{
    return (UISplitViewControllerBackgroundStyle)[objc_getAssociatedObject(self, &charon_style_key) integerValue];
}

- (void)setPrimaryBackgroundStyle:(UISplitViewControllerBackgroundStyle)primaryBackgroundStyle
{
    if (primaryBackgroundStyle != UISplitViewControllerBackgroundStyleNone)
        charon_menus_say_once(@"split-background", @"UISplitViewController.primaryBackgroundStyle: the sidebar background belongs to the Mac idiom, so the style is kept and read back and the primary column is drawn as before");
    objc_setAssociatedObject(self, &charon_style_key, @(primaryBackgroundStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
