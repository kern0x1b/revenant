#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_preferred_content_size_key;

@implementation UIViewController (CharonPreferredContentSize)

- (CGSize)preferredContentSize
{
    NSValue *stored = objc_getAssociatedObject(self, &charon_preferred_content_size_key);
    return stored ? [stored CGSizeValue] : CGSizeZero;
}

- (void)setPreferredContentSize:(CGSize)preferredContentSize
{
    objc_setAssociatedObject(self, &charon_preferred_content_size_key, [NSValue valueWithCGSize:preferredContentSize], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
