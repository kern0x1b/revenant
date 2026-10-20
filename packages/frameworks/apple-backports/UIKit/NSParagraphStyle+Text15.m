#import "RevenantMenus.h"
#import <objc/runtime.h>

static const void *RevenantDefaultHyphenationKey = &RevenantDefaultHyphenationKey;

static BOOL revenant_default_hyphenation(id style)
{
    return [objc_getAssociatedObject(style, RevenantDefaultHyphenationKey) boolValue];
}

static void revenant_set_default_hyphenation(id style, BOOL value)
{
    if (value)
        revenant_menus_say_once(@"default-hyphenation",
                              @"NSParagraphStyle.usesDefaultHyphenation: the text system of iOS 6 hyphenates nothing by "
                              @"default, so the flag is kept and read back and lines break as before");
    objc_setAssociatedObject(style, RevenantDefaultHyphenationKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation NSParagraphStyle (RevenantText15)

- (BOOL)usesDefaultHyphenation
{
    return revenant_default_hyphenation(self);
}

- (void)setUsesDefaultHyphenation:(BOOL)usesDefaultHyphenation
{
    revenant_set_default_hyphenation(self, usesDefaultHyphenation);
}

@end

@implementation NSMutableParagraphStyle (RevenantText15)

- (void)setUsesDefaultHyphenation:(BOOL)usesDefaultHyphenation
{
    revenant_set_default_hyphenation(self, usesDefaultHyphenation);
}

@end
