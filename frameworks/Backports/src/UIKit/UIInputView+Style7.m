#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_style_key;

@implementation UIInputView (RevenantStyle7)

- (instancetype)initWithFrame:(CGRect)frame inputViewStyle:(UIInputViewStyle)inputViewStyle
{
    if ((self = [self initWithFrame:frame]))
        objc_setAssociatedObject(self, &revenant_style_key, @(inputViewStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (UIInputViewStyle)inputViewStyle
{
    return (UIInputViewStyle)[objc_getAssociatedObject(self, &revenant_style_key) integerValue];
}

@end
