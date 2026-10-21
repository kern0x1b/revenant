#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantAccessibilityPathKey;

@implementation NSObject (RevenantAccessibilityPath7)

- (UIBezierPath *)accessibilityPath
{
    return objc_getAssociatedObject(self, &RevenantAccessibilityPathKey);
}

- (void)setAccessibilityPath:(UIBezierPath *)accessibilityPath
{
    objc_setAssociatedObject(self, &RevenantAccessibilityPathKey, accessibilityPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
