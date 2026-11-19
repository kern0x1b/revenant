#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char RevenantTypingAttributesKey;
static IMP RevenantNativeTypingAttributes;
static IMP RevenantNativeSetTypingAttributes;

static BOOL revenant_has_selection(UITextView *view)
{
    return [view selectedRange].location != NSNotFound;
}

static NSDictionary *revenant_typing_attributes(UITextView *self, SEL selector)
{
    if (revenant_has_selection(self)) {
        objc_setAssociatedObject(self, &RevenantTypingAttributesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return ((NSDictionary * (*)(id, SEL))RevenantNativeTypingAttributes)(self, selector);
    }
    NSDictionary *kept = objc_getAssociatedObject(self, &RevenantTypingAttributesKey);
    if (kept)
        return kept;
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:3];
    UIFont *font = self.font;
    if (font)
        [attributes setObject:font forKey:NSFontAttributeName];
    UIColor *color = self.textColor;
    if (color)
        [attributes setObject:color forKey:NSForegroundColorAttributeName];
    if (self.textAlignment != NSTextAlignmentLeft) {
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.alignment = self.textAlignment;
        [attributes setObject:paragraph forKey:NSParagraphStyleAttributeName];
    }
    return attributes;
}

static void revenant_set_typing_attributes(UITextView *self, SEL selector, NSDictionary *attributes)
{
    if (revenant_has_selection(self)) {
        objc_setAssociatedObject(self, &RevenantTypingAttributesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void (*)(id, SEL, NSDictionary *))RevenantNativeSetTypingAttributes)(self, selector, attributes);
        return;
    }
    objc_setAssociatedObject(self, &RevenantTypingAttributesKey, [attributes copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface RevenantTextViewTypingAttributes6 : NSObject
@end

@implementation RevenantTextViewTypingAttributes6

+ (void)load
{
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0)
        return;
    Method getter = class_getInstanceMethod([UITextView class], @selector(typingAttributes));
    Method setter = class_getInstanceMethod([UITextView class], @selector(setTypingAttributes:));
    if (!getter || !setter)
        return;
    RevenantNativeTypingAttributes = method_setImplementation(getter, (IMP)revenant_typing_attributes);
    RevenantNativeSetTypingAttributes = method_setImplementation(setter, (IMP)revenant_set_typing_attributes);
}

@end
