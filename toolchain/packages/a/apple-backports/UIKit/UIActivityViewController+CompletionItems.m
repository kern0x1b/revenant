#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_items_handler_key;

@implementation UIActivityViewController (CharonCompletionItems)

- (UIActivityViewControllerCompletionWithItemsHandler)completionWithItemsHandler
{
    return objc_getAssociatedObject(self, &charon_items_handler_key);
}

- (void)setCompletionWithItemsHandler:(UIActivityViewControllerCompletionWithItemsHandler)completionWithItemsHandler
{
    objc_setAssociatedObject(self, &charon_items_handler_key, completionWithItemsHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
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
