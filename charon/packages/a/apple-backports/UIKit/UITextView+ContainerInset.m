#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// UITextView on this release carries no TextKit surface at all (measured on the iPad 2, 6.1.3: no
// textContainer, layoutManager or textStorage selector, and its 24 own ivars are entirely WebKit's -
// facts/UIKit/TextSystem7.md). There is no NSTextContainer for this property to describe, so it is not
// backed by one: the value is kept exactly as given (round trip, no normalization) and, where the
// release's own WebKit document can express an inset, it is applied as the document body's CSS padding -
// the one part of "textContainerInset" a WebKit view can honestly mean. Nothing that would need a real
// text container (glyph-level measurement, container size) is added here at all.

static const void *ContainerInsetKey = &ContainerInsetKey;

// DOMHTMLElement and DOMCSSStyleDeclaration are real WebKit classes on the release (confirmed present,
// with setAttribute:value:, style, setPadding:/padding/setProperty:value:priority:/cssText all answering
// respondsToSelector: YES on the iPad 2, 6.1.3), but declaring their selectors in a category here collides
// with unrelated "style" properties the SDK already declares on other classes (NSPersonNameComponentsFormatter,
// CALayer, ...) and makes the compiler refuse the ambiguous send. objc_msgSend through performSelector: has
// its own fixed, unambiguous signature and sidesteps that entirely - the same reason this port's other bridges
// onto undeclared private selectors (NSLayoutManager+Text7.m) go through a forward-declared category only
// where the selector is not already claimed elsewhere; here it is, so this goes through performSelector: instead.

static id charon_text_view_body(UITextView *textView)
{
    Ivar ivar = class_getInstanceVariable([UITextView class], "m_body");
    return ivar ? object_getIvar(textView, ivar) : nil;
}

@implementation UITextView (CharonContainerInset)

- (UIEdgeInsets)textContainerInset
{
    NSValue *value = objc_getAssociatedObject(self, ContainerInsetKey);
    return value ? value.UIEdgeInsetsValue : UIEdgeInsetsZero;
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset
{
    objc_setAssociatedObject(self, ContainerInsetKey, [NSValue valueWithUIEdgeInsets:textContainerInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id body = charon_text_view_body(self);
    SEL styleSelector = @selector(style);
    id style = [body respondsToSelector:styleSelector] ? [body performSelector:styleSelector] : nil;
    SEL setPaddingSelector = @selector(setPadding:);
    if ([style respondsToSelector:setPaddingSelector]) {
        // DOMCSSStyleDeclaration.padding is the shorthand CSS box property, top/right/bottom/left, the same
        // order UIEdgeInsets uses.
        NSString *padding = [NSString stringWithFormat:@"%.0fpx %.0fpx %.0fpx %.0fpx",
            textContainerInset.top, textContainerInset.right, textContainerInset.bottom, textContainerInset.left];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [style performSelector:setPaddingSelector withObject:padding];
#pragma clang diagnostic pop
    }
}

@end
