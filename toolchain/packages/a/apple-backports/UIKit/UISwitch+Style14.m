#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_preferred_key, charon_title_key;

@implementation UISwitch (CharonStyle14)

- (UISwitchStyle)style
{
    return UISwitchStyleSliding;
}

- (UISwitchStyle)preferredStyle
{
    return (UISwitchStyle)[objc_getAssociatedObject(self, &charon_preferred_key) integerValue];
}

- (void)setPreferredStyle:(UISwitchStyle)preferredStyle
{
    objc_setAssociatedObject(self, &charon_preferred_key, @(preferredStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)title
{
    return objc_getAssociatedObject(self, &charon_title_key);
}

- (void)setTitle:(NSString *)title
{
    if (title.length)
        charon_menus_say_once(@"switch-title", @"UISwitch.title: the title belongs to the checkbox style of the Mac idiom, so on this release it is kept and not drawn");
    objc_setAssociatedObject(self, &charon_title_key, [title copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
