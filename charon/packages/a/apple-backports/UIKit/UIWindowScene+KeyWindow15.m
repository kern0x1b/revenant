#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIWindowScene (CharonKeyWindow15)

- (UIWindow *)keyWindow
{
    UIWindow *key = [UIApplication sharedApplication].keyWindow;
    return key && [self.windows containsObject:key] ? key : nil;
}

@end
