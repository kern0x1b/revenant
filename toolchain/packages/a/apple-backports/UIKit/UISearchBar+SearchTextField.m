#import "CharonSearch.h"
#import <objc/runtime.h>

static UITextField *charon_find_field(UIView *view)
{
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UITextField class]])
            return (UITextField *)sub;
        UITextField *found = charon_find_field(sub);
        if (found)
            return found;
    }
    return nil;
}

static NSArray *charon_token_selectors(void)
{
    return @[@"tokens", @"setTokens:", @"insertToken:atIndex:", @"removeTokenAtIndex:", @"positionOfTokenAtIndex:", @"tokensInRange:", @"textualRange",
             @"replaceTextualPortionOfRange:withToken:atIndex:", @"tokenBackgroundColor", @"setTokenBackgroundColor:", @"allowsDeletingTokens", @"setAllowsDeletingTokens:",
             @"allowsCopyingTokens", @"setAllowsCopyingTokens:"];
}

@implementation UISearchBar (CharonSearchTextField)

- (UISearchTextField *)searchTextField
{
    UITextField *field = charon_find_field(self);
    Class carrier = NSClassFromString(@"UISearchTextField");
    if (!field || !carrier || [field isKindOfClass:carrier] || [field respondsToSelector:NSSelectorFromString(@"insertToken:atIndex:")])
        return (UISearchTextField *)field;
    Class current = object_getClass(field);
    NSString *name = [@"CharonSearch" stringByAppendingString:NSStringFromClass(current)];
    Class extended = NSClassFromString(name);
    if (!extended) {
        extended = objc_allocateClassPair(current, name.UTF8String, 0);
        if (!extended)
            return (UISearchTextField *)field;
        for (NSString *selector in charon_token_selectors()) {
            Method method = class_getInstanceMethod(carrier, NSSelectorFromString(selector));
            class_addMethod(extended, NSSelectorFromString(selector), method_getImplementation(method), method_getTypeEncoding(method));
        }
        objc_registerClassPair(extended);
    }
    object_setClass(field, extended);
    return (UISearchTextField *)field;
}

@end
