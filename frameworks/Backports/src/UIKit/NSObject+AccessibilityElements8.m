#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantAccessibilityElementsKey;

@implementation NSObject (RevenantAccessibilityElements8)

- (NSArray *)accessibilityElements
{
    return objc_getAssociatedObject(self, &RevenantAccessibilityElementsKey);
}

- (void)setAccessibilityElements:(NSArray *)accessibilityElements
{
    objc_setAssociatedObject(self, &RevenantAccessibilityElementsKey, accessibilityElements, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
