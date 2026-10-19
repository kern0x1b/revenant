#import "CharonMenus.h"
#import <objc/runtime.h>

static const char charon_quotes_key;
static const char charon_dashes_key;
static const char charon_insert_key;
static const char charon_rules_key;

static void charon_traits_note(NSString *name, NSInteger value)
{
    if (value == UITextSmartQuotesTypeYes)
        charon_menus_say_once(name, [NSString stringWithFormat:@"%@: the keyboard of iOS 6 makes no smart substitutions, so the value is kept and read back and typing is as before", name]);
}

#define CHARON_TEXT_TRAITS(CLASS) \
@implementation CLASS (CharonTextInputTraits11) \
- (UITextSmartQuotesType)smartQuotesType \
{ \
    return (UITextSmartQuotesType)[objc_getAssociatedObject(self, &charon_quotes_key) integerValue]; \
} \
- (void)setSmartQuotesType:(UITextSmartQuotesType)smartQuotesType \
{ \
    charon_traits_note(@"smartQuotesType", smartQuotesType); \
    objc_setAssociatedObject(self, &charon_quotes_key, @(smartQuotesType), OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
- (UITextSmartDashesType)smartDashesType \
{ \
    return (UITextSmartDashesType)[objc_getAssociatedObject(self, &charon_dashes_key) integerValue]; \
} \
- (void)setSmartDashesType:(UITextSmartDashesType)smartDashesType \
{ \
    charon_traits_note(@"smartDashesType", smartDashesType); \
    objc_setAssociatedObject(self, &charon_dashes_key, @(smartDashesType), OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
- (UITextSmartInsertDeleteType)smartInsertDeleteType \
{ \
    return (UITextSmartInsertDeleteType)[objc_getAssociatedObject(self, &charon_insert_key) integerValue]; \
} \
- (void)setSmartInsertDeleteType:(UITextSmartInsertDeleteType)smartInsertDeleteType \
{ \
    charon_traits_note(@"smartInsertDeleteType", smartInsertDeleteType); \
    objc_setAssociatedObject(self, &charon_insert_key, @(smartInsertDeleteType), OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
- (UITextInputPasswordRules *)passwordRules \
{ \
    return objc_getAssociatedObject(self, &charon_rules_key); \
} \
- (void)setPasswordRules:(UITextInputPasswordRules *)passwordRules \
{ \
    if (passwordRules) \
        charon_menus_say_once(@"passwordRules", @"passwordRules: the keyboard of iOS 6 offers no generated password, so the rules are kept and read back and nothing is generated"); \
    objc_setAssociatedObject(self, &charon_rules_key, [passwordRules copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
@end

CHARON_TEXT_TRAITS(UITextField)
CHARON_TEXT_TRAITS(UITextView)
CHARON_TEXT_TRAITS(UISearchBar)
