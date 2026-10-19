#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "check.h"

@interface RevenantFakeBarField : UITextField
@end

@implementation RevenantFakeBarField
@end

@interface RevenantFakeBar : UISearchBar
@property (nonatomic, strong) UIView *content;
@end

@implementation RevenantFakeBar

- (NSArray<UIView *> *)subviews
{
    return self.content ? @[self.content] : @[];
}

@end

void revenant_windowed_run(UIWindow *window)
{
    SEL find = NSSelectorFromString(@"revenantHostSearchTextField");
    UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    [window addSubview:bar];
    id found = ((id (*)(id, SEL))objc_msgSend)(bar, find);
    revenant_check(found != nil && found == bar.searchTextField && found == ((id (*)(id, SEL))objc_msgSend)(bar, find), "the search bar's text field is the one the system answers", ([NSString stringWithFormat:@"%@", found]));
    revenant_check(object_getClass(found) == object_getClass(bar.searchTextField), "and a field that is already a search text field is not changed", @"its class changed");

    RevenantFakeBar *fake_bar = [[RevenantFakeBar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    UIView *wrapper = [[UIView alloc] init];
    RevenantFakeBarField *fake = [[RevenantFakeBarField alloc] init];
    [wrapper addSubview:fake];
    fake_bar.content = wrapper;
    id upgraded = ((id (*)(id, SEL))objc_msgSend)(fake_bar, find);
    revenant_check(upgraded == fake && [upgraded isKindOfClass:[RevenantFakeBarField class]] && [NSStringFromClass(object_getClass(upgraded)) isEqual:@"RevenantSearchRevenantFakeBarField"],
                 "a text field of another class, found in a subview, is given a class of its own that extends it", NSStringFromClass(object_getClass(upgraded)));
    for (NSString *name in @[@"tokens", @"setTokens:", @"insertToken:atIndex:", @"removeTokenAtIndex:", @"positionOfTokenAtIndex:", @"tokensInRange:", @"textualRange",
                             @"replaceTextualPortionOfRange:withToken:atIndex:", @"tokenBackgroundColor", @"setTokenBackgroundColor:", @"allowsDeletingTokens", @"setAllowsDeletingTokens:",
                             @"allowsCopyingTokens", @"setAllowsCopyingTokens:"])
        revenant_check([upgraded respondsToSelector:NSSelectorFromString(name)], [[@"the upgraded field answers " stringByAppendingString:name] UTF8String], @"it does not");
    revenant_check(((id (*)(id, SEL))objc_msgSend)(fake_bar, find) == upgraded && [NSStringFromClass(object_getClass(upgraded)) isEqual:@"RevenantSearchRevenantFakeBarField"], "asking again finds it as it is", @"it changed");
    RevenantFakeBar *empty = [[RevenantFakeBar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    revenant_check(((id (*)(id, SEL))objc_msgSend)(empty, find) == nil, "a search bar with no text field answers nil", @"it answered one");

    SEL get = NSSelectorFromString(@"revenantHostAutomaticallyShowsScopeBar"), set = NSSelectorFromString(@"revenantHostSetAutomaticallyShowsScopeBar:");
    UISearchController *controller = [[UISearchController alloc] initWithSearchResultsController:nil];
    BOOL first = ((BOOL (*)(id, SEL))objc_msgSend)(controller, get);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, set, NO);
    BOOL off = ((BOOL (*)(id, SEL))objc_msgSend)(controller, get);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, set, YES);
    BOOL on = ((BOOL (*)(id, SEL))objc_msgSend)(controller, get);
    controller.automaticallyShowsScopeBar = NO;
    BOOL system_off = controller.automaticallyShowsScopeBar;
    controller.automaticallyShowsScopeBar = YES;
    revenant_check(!first && !off && on && !system_off && controller.automaticallyShowsScopeBar, "the scope bar flag starts off, as an iPad app measures it, and is kept as the system's is", @"it differs");
}
