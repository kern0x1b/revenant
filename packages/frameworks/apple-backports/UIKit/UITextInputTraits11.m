#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char revenant_quotes_key;
static const char revenant_dashes_key;
static const char revenant_insert_key;
static const char revenant_rules_key;

static void revenant_traits_note(NSString *name, NSInteger value)
{
    if (value == UITextSmartQuotesTypeYes)
        revenant_menus_say_once(name, [NSString stringWithFormat:@"%@: the keyboard of iOS 6 makes no smart substitutions, so the value is kept and read back and typing is as before", name]);
}

#define REVENANT_TEXT_TRAITS(CLASS) \
@implementation CLASS (RevenantTextInputTraits11) \
- (UITextSmartQuotesType)smartQuotesType \
{ \
    return (UITextSmartQuotesType)[objc_getAssociatedObject(self, &revenant_quotes_key) integerValue]; \
} \
- (void)setSmartQuotesType:(UITextSmartQuotesType)smartQuotesType \
{ \
    revenant_traits_note(@"smartQuotesType", smartQuotesType); \
    objc_setAssociatedObject(self, &revenant_quotes_key, @(smartQuotesType), OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
- (UITextSmartDashesType)smartDashesType \
{ \
    return (UITextSmartDashesType)[objc_getAssociatedObject(self, &revenant_dashes_key) integerValue]; \
} \
- (void)setSmartDashesType:(UITextSmartDashesType)smartDashesType \
{ \
    revenant_traits_note(@"smartDashesType", smartDashesType); \
    objc_setAssociatedObject(self, &revenant_dashes_key, @(smartDashesType), OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
- (UITextSmartInsertDeleteType)smartInsertDeleteType \
{ \
    return (UITextSmartInsertDeleteType)[objc_getAssociatedObject(self, &revenant_insert_key) integerValue]; \
} \
- (void)setSmartInsertDeleteType:(UITextSmartInsertDeleteType)smartInsertDeleteType \
{ \
    revenant_traits_note(@"smartInsertDeleteType", smartInsertDeleteType); \
    objc_setAssociatedObject(self, &revenant_insert_key, @(smartInsertDeleteType), OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
- (UITextInputPasswordRules *)passwordRules \
{ \
    return objc_getAssociatedObject(self, &revenant_rules_key); \
} \
- (void)setPasswordRules:(UITextInputPasswordRules *)passwordRules \
{ \
    if (passwordRules) \
        revenant_menus_say_once(@"passwordRules", @"passwordRules: the keyboard of iOS 6 offers no generated password, so the rules are kept and read back and nothing is generated"); \
    objc_setAssociatedObject(self, &revenant_rules_key, [passwordRules copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
@end

REVENANT_TEXT_TRAITS(UITextField)
REVENANT_TEXT_TRAITS(UITextView)
REVENANT_TEXT_TRAITS(UISearchBar)
