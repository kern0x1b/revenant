#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "check.h"

@interface CharonFakeBarField : UITextField
@end

@implementation CharonFakeBarField
@end

@interface CharonFakeBar : UISearchBar
@property (nonatomic, strong) UIView *content;
@end

@implementation CharonFakeBar

- (NSArray<UIView *> *)subviews
{
    return self.content ? @[self.content] : @[];
}

@end

void charon_windowed_run(UIWindow *window)
{
    SEL find = NSSelectorFromString(@"charonHostSearchTextField");
    UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    [window addSubview:bar];
    id found = ((id (*)(id, SEL))objc_msgSend)(bar, find);
    charon_check(found != nil && found == bar.searchTextField && found == ((id (*)(id, SEL))objc_msgSend)(bar, find), "the search bar's text field is the one the system answers", ([NSString stringWithFormat:@"%@", found]));
    charon_check(object_getClass(found) == object_getClass(bar.searchTextField), "and a field that is already a search text field is not changed", @"its class changed");

    CharonFakeBar *fake_bar = [[CharonFakeBar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    UIView *wrapper = [[UIView alloc] init];
    CharonFakeBarField *fake = [[CharonFakeBarField alloc] init];
    [wrapper addSubview:fake];
    fake_bar.content = wrapper;
    id upgraded = ((id (*)(id, SEL))objc_msgSend)(fake_bar, find);
    charon_check(upgraded == fake && [upgraded isKindOfClass:[CharonFakeBarField class]] && [NSStringFromClass(object_getClass(upgraded)) isEqual:@"CharonSearchCharonFakeBarField"],
                 "a text field of another class, found in a subview, is given a class of its own that extends it", NSStringFromClass(object_getClass(upgraded)));
    for (NSString *name in @[@"tokens", @"setTokens:", @"insertToken:atIndex:", @"removeTokenAtIndex:", @"positionOfTokenAtIndex:", @"tokensInRange:", @"textualRange",
                             @"replaceTextualPortionOfRange:withToken:atIndex:", @"tokenBackgroundColor", @"setTokenBackgroundColor:", @"allowsDeletingTokens", @"setAllowsDeletingTokens:",
                             @"allowsCopyingTokens", @"setAllowsCopyingTokens:"])
        charon_check([upgraded respondsToSelector:NSSelectorFromString(name)], [[@"the upgraded field answers " stringByAppendingString:name] UTF8String], @"it does not");
    charon_check(((id (*)(id, SEL))objc_msgSend)(fake_bar, find) == upgraded && [NSStringFromClass(object_getClass(upgraded)) isEqual:@"CharonSearchCharonFakeBarField"], "asking again finds it as it is", @"it changed");
    CharonFakeBar *empty = [[CharonFakeBar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    charon_check(((id (*)(id, SEL))objc_msgSend)(empty, find) == nil, "a search bar with no text field answers nil", @"it answered one");

    SEL get = NSSelectorFromString(@"charonHostAutomaticallyShowsScopeBar"), set = NSSelectorFromString(@"charonHostSetAutomaticallyShowsScopeBar:");
    UISearchController *controller = [[UISearchController alloc] initWithSearchResultsController:nil];
    BOOL first = ((BOOL (*)(id, SEL))objc_msgSend)(controller, get);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, set, NO);
    BOOL off = ((BOOL (*)(id, SEL))objc_msgSend)(controller, get);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, set, YES);
    BOOL on = ((BOOL (*)(id, SEL))objc_msgSend)(controller, get);
    controller.automaticallyShowsScopeBar = NO;
    BOOL system_off = controller.automaticallyShowsScopeBar;
    controller.automaticallyShowsScopeBar = YES;
    charon_check(!first && !off && on && !system_off && controller.automaticallyShowsScopeBar, "the scope bar flag starts off, as an iPad app measures it, and is kept as the system's is", @"it differs");
}
