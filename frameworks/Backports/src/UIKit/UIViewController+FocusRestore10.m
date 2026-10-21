#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantRestoresFocusKey;

@implementation UIViewController (RevenantFocusRestore10)

- (BOOL)restoresFocusAfterTransition
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantRestoresFocusKey);
    return stored ? stored.boolValue : YES;
}

- (void)setRestoresFocusAfterTransition:(BOOL)restoresFocusAfterTransition
{
    objc_setAssociatedObject(self, &RevenantRestoresFocusKey, @(restoresFocusAfterTransition), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
