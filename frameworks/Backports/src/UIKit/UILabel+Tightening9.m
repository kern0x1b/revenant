#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantTightening.h"

static const char RevenantLabelTighteningKey;
static IMP revenant_label_draw_text_original;

static BOOL revenant_truncates(NSLineBreakMode mode)
{
    return mode == NSLineBreakByTruncatingHead || mode == NSLineBreakByTruncatingMiddle || mode == NSLineBreakByTruncatingTail;
}

static NSMutableAttributedString *revenant_label_text(UILabel *label)
{
    NSAttributedString *source = label.attributedText ?: [[NSAttributedString alloc] initWithString:label.text ?: @""];
    NSMutableAttributedString *text = [source mutableCopy];
    NSRange all = NSMakeRange(0, text.length);
    [source enumerateAttribute:NSFontAttributeName inRange:all options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (!value)
            [text addAttribute:NSFontAttributeName value:label.font range:range];
    }];
    [source enumerateAttribute:NSForegroundColorAttributeName inRange:all options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (!value && label.textColor)
            [text addAttribute:NSForegroundColorAttributeName value:label.textColor range:range];
    }];
    return text;
}

static BOOL revenant_tightening_wanted(UILabel *label, NSAttributedString *text)
{
    if (label.numberOfLines != 1 || !revenant_truncates(label.lineBreakMode))
        return NO;
    if ([objc_getAssociatedObject(label, &RevenantLabelTighteningKey) boolValue])
        return YES;
    if (text.length == 0)
        return NO;
    NSParagraphStyle *style = [text attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
    return style.allowsDefaultTighteningForTruncation;
}

static void revenant_draw_text_in_rect(UILabel *label, SEL selector, CGRect rect)
{
    NSMutableAttributedString *text = revenant_label_text(label);
    double kern = 0;
    if (revenant_tightening_wanted(label, text)) {
        NSUInteger gaps = text.length > 0 ? text.length - 1 : 0;
        if (revenant_tightening_kern([text size].width, rect.size.width, label.font.pointSize, gaps, &kern)) {
            NSAttributedString *source = [text copy];
            [source enumerateAttribute:NSKernAttributeName inRange:NSMakeRange(0, source.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
                [text addAttribute:NSKernAttributeName value:@([value doubleValue] + kern) range:range];
            }];
            CGSize size = [text size];
            CGFloat x = CGRectGetMinX(rect);
            if (label.textAlignment == NSTextAlignmentCenter)
                x += (CGRectGetWidth(rect) - size.width) / 2;
            else if (label.textAlignment == NSTextAlignmentRight)
                x += CGRectGetWidth(rect) - size.width;
            [text drawAtPoint:CGPointMake(x, CGRectGetMinY(rect) + (CGRectGetHeight(rect) - size.height) / 2)];
            return;
        }
    }
    ((void (*)(id, SEL, CGRect))revenant_label_draw_text_original)(label, selector, rect);
}

@implementation UILabel (RevenantTightening9)

+ (void)load
{
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_9_0)
        return;
    Method method = class_getInstanceMethod(self, @selector(drawTextInRect:));
    if (!method)
        return;
    revenant_label_draw_text_original = method_getImplementation(method);
    method_setImplementation(method, (IMP)revenant_draw_text_in_rect);
}

- (BOOL)allowsDefaultTighteningForTruncation
{
    return [objc_getAssociatedObject(self, &RevenantLabelTighteningKey) boolValue];
}

- (void)setAllowsDefaultTighteningForTruncation:(BOOL)allowsDefaultTighteningForTruncation
{
    objc_setAssociatedObject(self, &RevenantLabelTighteningKey, @(allowsDefaultTighteningForTruncation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
