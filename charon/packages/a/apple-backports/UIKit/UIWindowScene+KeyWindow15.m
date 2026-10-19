#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIWindowScene (CharonKeyWindow15)

// The release has one scene, whose windows are the application's.
- (UIWindow *)keyWindow
{
    UIWindow *key = [UIApplication sharedApplication].keyWindow;
    return key && [self.windows containsObject:key] ? key : nil;
}

@end
