#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_adjusts_key;

static void revenant_say_adjusting(BOOL adjusts)
{
    if (adjusts)
        revenant_menus_say_once(@"content-size-adjusting", @"adjustsFontForContentSizeCategory: iOS 6 has one content size category and never changes it, so the flag is kept and read back and the font is left as it was set");
}

static BOOL revenant_adjusts(id object)
{
    return [objc_getAssociatedObject(object, &revenant_adjusts_key) boolValue];
}

static void revenant_set_adjusts(id object, BOOL adjusts)
{
    revenant_say_adjusting(adjusts);
    objc_setAssociatedObject(object, &revenant_adjusts_key, adjusts ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface UILabel (RevenantContentSizeAdjusting) <UIContentSizeCategoryAdjusting>
@end

@interface UITextField (RevenantContentSizeAdjusting) <UIContentSizeCategoryAdjusting>
@end

@interface UITextView (RevenantContentSizeAdjusting) <UIContentSizeCategoryAdjusting>
@end

@implementation UILabel (RevenantContentSizeAdjusting)

- (BOOL)adjustsFontForContentSizeCategory
{
    return revenant_adjusts(self);
}

- (void)setAdjustsFontForContentSizeCategory:(BOOL)adjusts
{
    revenant_set_adjusts(self, adjusts);
}

@end

@implementation UITextField (RevenantContentSizeAdjusting)

- (BOOL)adjustsFontForContentSizeCategory
{
    return revenant_adjusts(self);
}

- (void)setAdjustsFontForContentSizeCategory:(BOOL)adjusts
{
    revenant_set_adjusts(self, adjusts);
}

@end

@implementation UITextView (RevenantContentSizeAdjusting)

- (BOOL)adjustsFontForContentSizeCategory
{
    return revenant_adjusts(self);
}

- (void)setAdjustsFontForContentSizeCategory:(BOOL)adjusts
{
    revenant_set_adjusts(self, adjusts);
}

@end
