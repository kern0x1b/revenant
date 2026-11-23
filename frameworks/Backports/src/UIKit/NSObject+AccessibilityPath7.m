#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantAccessibilityPathKey;
static const char RevenantAccessibilityNavigationStyleKey;

@implementation NSObject (RevenantAccessibilityPath7)

- (UIBezierPath *)accessibilityPath
{
    return objc_getAssociatedObject(self, &RevenantAccessibilityPathKey);
}

- (void)setAccessibilityPath:(UIBezierPath *)accessibilityPath
{
    objc_setAssociatedObject(self, &RevenantAccessibilityPathKey, accessibilityPath, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIAccessibilityNavigationStyle)accessibilityNavigationStyle
{
    NSNumber *style = objc_getAssociatedObject(self, &RevenantAccessibilityNavigationStyleKey);
    return style ? (UIAccessibilityNavigationStyle)style.integerValue : UIAccessibilityNavigationStyleAutomatic;
}

- (void)setAccessibilityNavigationStyle:(UIAccessibilityNavigationStyle)accessibilityNavigationStyle
{
    objc_setAssociatedObject(self, &RevenantAccessibilityNavigationStyleKey, @(accessibilityNavigationStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
