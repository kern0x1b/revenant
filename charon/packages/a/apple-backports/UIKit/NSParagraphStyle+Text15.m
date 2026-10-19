#import "CharonMenus.h"
#import <objc/runtime.h>

static const void *CharonDefaultHyphenationKey = &CharonDefaultHyphenationKey;

static BOOL charon_default_hyphenation(id style)
{
    return [objc_getAssociatedObject(style, CharonDefaultHyphenationKey) boolValue];
}

static void charon_set_default_hyphenation(id style, BOOL value)
{
    if (value)
        charon_menus_say_once(@"default-hyphenation",
                              @"NSParagraphStyle.usesDefaultHyphenation: the text system of iOS 6 hyphenates nothing by "
                              @"default, so the flag is kept and read back and lines break as before");
    objc_setAssociatedObject(style, CharonDefaultHyphenationKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation NSParagraphStyle (CharonText15)

- (BOOL)usesDefaultHyphenation
{
    return charon_default_hyphenation(self);
}

- (void)setUsesDefaultHyphenation:(BOOL)usesDefaultHyphenation
{
    charon_set_default_hyphenation(self, usesDefaultHyphenation);
}

@end

@implementation NSMutableParagraphStyle (CharonText15)

- (void)setUsesDefaultHyphenation:(BOOL)usesDefaultHyphenation
{
    charon_set_default_hyphenation(self, usesDefaultHyphenation);
}

@end
