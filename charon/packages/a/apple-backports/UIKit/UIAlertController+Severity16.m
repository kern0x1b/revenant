#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation UIAlertController (CharonSeverity16)

- (UIAlertControllerSeverity)severity
{
    return [objc_getAssociatedObject(self, @selector(severity)) integerValue];
}

- (void)setSeverity:(UIAlertControllerSeverity)severity
{
    objc_setAssociatedObject(self, @selector(severity), @(severity), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
