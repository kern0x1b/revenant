#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantCustomTransition.h"

@interface UIDocumentMenuViewController (RevenantAlert)
- (UIAlertController *)revenant_alertForPresenter:(UIViewController *)presenter;
@end

static const char revenant_menu_alert_key;

BOOL revenant_document_menu_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void))
{
    if (![presented isKindOfClass:[UIDocumentMenuViewController class]] || ![presented respondsToSelector:@selector(revenant_alertForPresenter:)])
        return NO;
    UIDocumentMenuViewController *menu = (UIDocumentMenuViewController *)presented;
    UIAlertController *alert = [menu revenant_alertForPresenter:presenting];
    objc_setAssociatedObject(menu, &revenant_menu_alert_key, alert, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenting presentViewController:alert animated:animated completion:completion];
    return YES;
}
