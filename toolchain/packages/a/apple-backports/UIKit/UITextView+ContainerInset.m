#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *ContainerInsetKey = &ContainerInsetKey;

static id revenant_text_view_body(UITextView *textView)
{
    Ivar ivar = class_getInstanceVariable([UITextView class], "m_body");
    return ivar ? object_getIvar(textView, ivar) : nil;
}

@implementation UITextView (RevenantContainerInset)

- (UIEdgeInsets)textContainerInset
{
    NSValue *value = objc_getAssociatedObject(self, ContainerInsetKey);
    return value ? value.UIEdgeInsetsValue : UIEdgeInsetsZero;
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset
{
    objc_setAssociatedObject(self, ContainerInsetKey, [NSValue valueWithUIEdgeInsets:textContainerInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id body = revenant_text_view_body(self);
    SEL styleSelector = @selector(style);
    id style = [body respondsToSelector:styleSelector] ? [body performSelector:styleSelector] : nil;
    SEL setPaddingSelector = @selector(setPadding:);
    if ([style respondsToSelector:setPaddingSelector]) {
        NSString *padding = [NSString stringWithFormat:@"%.0fpx %.0fpx %.0fpx %.0fpx",
            textContainerInset.top, textContainerInset.right, textContainerInset.bottom, textContainerInset.left];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [style performSelector:setPaddingSelector withObject:padding];
#pragma clang diagnostic pop
    }
}

@end
