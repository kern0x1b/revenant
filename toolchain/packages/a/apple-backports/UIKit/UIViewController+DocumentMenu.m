#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonCustomTransition.h"

@interface UIDocumentMenuViewController (CharonAlert)
- (UIAlertController *)charon_alertForPresenter:(UIViewController *)presenter;
@end

static const char charon_menu_alert_key;

BOOL charon_document_menu_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void))
{
    if (![presented isKindOfClass:[UIDocumentMenuViewController class]] || ![presented respondsToSelector:@selector(charon_alertForPresenter:)])
        return NO;
    UIDocumentMenuViewController *menu = (UIDocumentMenuViewController *)presented;
    UIAlertController *alert = [menu charon_alertForPresenter:presenting];
    objc_setAssociatedObject(menu, &charon_menu_alert_key, alert, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenting presentViewController:alert animated:animated completion:completion];
    return YES;
}
