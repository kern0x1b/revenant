#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_adjusts_key;

static void charon_say_adjusting(BOOL adjusts)
{
    if (adjusts)
        charon_menus_say_once(@"content-size-adjusting", @"adjustsFontForContentSizeCategory: iOS 6 has one content size category and never changes it, so the flag is kept and read back and the font is left as it was set");
}

static BOOL charon_adjusts(id object)
{
    return [objc_getAssociatedObject(object, &charon_adjusts_key) boolValue];
}

static void charon_set_adjusts(id object, BOOL adjusts)
{
    charon_say_adjusting(adjusts);
    objc_setAssociatedObject(object, &charon_adjusts_key, adjusts ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface UILabel (CharonContentSizeAdjusting) <UIContentSizeCategoryAdjusting>
@end

@interface UITextField (CharonContentSizeAdjusting) <UIContentSizeCategoryAdjusting>
@end

@interface UITextView (CharonContentSizeAdjusting) <UIContentSizeCategoryAdjusting>
@end

@implementation UILabel (CharonContentSizeAdjusting)

- (BOOL)adjustsFontForContentSizeCategory
{
    return charon_adjusts(self);
}

- (void)setAdjustsFontForContentSizeCategory:(BOOL)adjusts
{
    charon_set_adjusts(self, adjusts);
}

@end

@implementation UITextField (CharonContentSizeAdjusting)

- (BOOL)adjustsFontForContentSizeCategory
{
    return charon_adjusts(self);
}

- (void)setAdjustsFontForContentSizeCategory:(BOOL)adjusts
{
    charon_set_adjusts(self, adjusts);
}

@end

@implementation UITextView (CharonContentSizeAdjusting)

- (BOOL)adjustsFontForContentSizeCategory
{
    return charon_adjusts(self);
}

- (void)setAdjustsFontForContentSizeCategory:(BOOL)adjusts
{
    charon_set_adjusts(self, adjusts);
}

@end
