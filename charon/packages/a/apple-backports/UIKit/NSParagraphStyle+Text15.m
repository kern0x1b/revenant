// NSParagraphStyle+Text15.m - usesDefaultHyphenation, the paragraph-style half of iOS 15.0.
//
// Two rows: NSParagraphStyle.usesDefaultHyphenation and NSMutableParagraphStyle.usesDefaultHyphenation.
// Both are 15.0 and both are carried from 6.0, so this file is one object's API and belongs to
// release 15 alone. It is a category file, so it exports no class symbol of its own; what it adds
// is four selectors on two classes the SDK declares, which is the shape the registry check counts
// (check_categories, backports.lua:1361) and the shape NSLayoutManager+Text13.m already uses for
// the layout-manager half of the same flag.
//
// The behaviour is the layout manager's, measured on this release, and it is why this is `inert`
// and not `implemented`. The 13.0 row -[NSLayoutManager usesDefaultHyphenation] - is already
// carried that way, in NSLayoutManager+Text13.m, with the same statement: iOS 6 hyphenates
// nothing by default, so the flag is kept and read back and the lines break exactly as they did.
// The paragraph style is where the same flag is set, so it gets the same treatment and the same
// wording; the two halves agree with each other, which is the only thing that makes a shared
// answer honest here.
//
// What the release actually carries was measured rather than read out of a header: 6.1.3's
// NSParagraphStyle has -hyphenationFactor and NSMutableParagraphStyle has -setHyphenationFactor:,
// and neither has the boolean, so there is no system default to defer to - which is precisely why
// the flag has to be kept rather than derived. The getter returns NO until something sets it,
// exactly as the layout manager's does.
//
// Not carried, and named rather than left silent: the flag does not hyphenate anything. An
// implementation that claimed otherwise would be claiming a text engine, and a caller that set it
// and measured line breaking would find no difference. The one-time note in charon_menus_say_once
// is what a caller sees, and it is what the 13.0 row's effect already says.

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
