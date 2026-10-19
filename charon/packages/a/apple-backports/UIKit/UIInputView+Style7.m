#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_style_key;
static const char charon_self_sizing_key;

@implementation UIInputView (CharonStyle7)

- (instancetype)initWithFrame:(CGRect)frame inputViewStyle:(UIInputViewStyle)inputViewStyle
{
    if ((self = [self initWithFrame:frame]))
        objc_setAssociatedObject(self, &charon_style_key, @(inputViewStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (UIInputViewStyle)inputViewStyle
{
    return (UIInputViewStyle)[objc_getAssociatedObject(self, &charon_style_key) integerValue];
}

- (BOOL)allowsSelfSizing
{
    return [objc_getAssociatedObject(self, &charon_self_sizing_key) boolValue];
}

- (void)setAllowsSelfSizing:(BOOL)allowsSelfSizing
{
    objc_setAssociatedObject(self, &charon_self_sizing_key, @(allowsSelfSizing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
