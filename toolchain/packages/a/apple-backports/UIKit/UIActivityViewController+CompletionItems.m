#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_items_handler_key;

@implementation UIActivityViewController (RevenantCompletionItems)

- (UIActivityViewControllerCompletionWithItemsHandler)completionWithItemsHandler
{
    return objc_getAssociatedObject(self, &revenant_items_handler_key);
}

- (void)setCompletionWithItemsHandler:(UIActivityViewControllerCompletionWithItemsHandler)completionWithItemsHandler
{
    objc_setAssociatedObject(self, &revenant_items_handler_key, completionWithItemsHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (!completionWithItemsHandler) {
        self.completionHandler = nil;
        return;
    }
    UIActivityViewControllerCompletionWithItemsHandler handler = [completionWithItemsHandler copy];
    self.completionHandler = ^(NSString *activityType, BOOL completed) {
        handler(activityType, completed, nil, nil);
    };
}

@end
