#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char revenant_preferred_content_size_key;

@implementation UIViewController (RevenantPreferredContentSize)

- (CGSize)preferredContentSize
{
    NSValue *stored = objc_getAssociatedObject(self, &revenant_preferred_content_size_key);
    return stored ? [stored CGSizeValue] : CGSizeZero;
}

- (void)setPreferredContentSize:(CGSize)preferredContentSize
{
    objc_setAssociatedObject(self, &revenant_preferred_content_size_key, [NSValue valueWithCGSize:preferredContentSize], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
