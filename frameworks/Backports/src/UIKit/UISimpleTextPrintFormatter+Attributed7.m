#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantPrintAttributedKey;

static BOOL revenant_uniform(NSAttributedString *text)
{
    if (!text.length)
        return YES;
    NSRange range;
    [text attributesAtIndex:0 effectiveRange:&range];
    return NSMaxRange(range) == text.length;
}

@implementation UISimpleTextPrintFormatter (RevenantAttributed7)

- (instancetype)initWithAttributedText:(NSAttributedString *)attributedText
{
    if ((self = [self initWithText:attributedText.string]))
        self.attributedText = attributedText;
    return self;
}

- (NSAttributedString *)attributedText
{
    NSAttributedString *stored = objc_getAssociatedObject(self, &RevenantPrintAttributedKey);
    if (stored && [stored.string isEqualToString:self.text ?: @""])
        return stored;
    if (!self.text)
        return nil;
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (self.font)
        attributes[NSFontAttributeName] = self.font;
    if (self.color)
        attributes[NSForegroundColorAttributeName] = self.color;
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = self.textAlignment;
    attributes[NSParagraphStyleAttributeName] = style;
    return [[NSAttributedString alloc] initWithString:self.text attributes:attributes];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    objc_setAssociatedObject(self, &RevenantPrintAttributedKey, [attributedText copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.text = attributedText.string;
    if (!attributedText.length)
        return;
    NSDictionary *first = [attributedText attributesAtIndex:0 effectiveRange:NULL];
    UIFont *font = first[NSFontAttributeName];
    UIColor *color = first[NSForegroundColorAttributeName];
    NSParagraphStyle *style = first[NSParagraphStyleAttributeName];
    if (font)
        self.font = font;
    if (color)
        self.color = color;
    if (style)
        self.textAlignment = style.alignment;
    if (!revenant_uniform(attributedText))
        revenant_menus_say_once(@"print-attributed", @"UISimpleTextPrintFormatter.attributedText: the iOS 6 formatter draws the whole text in one font, colour and alignment, so the attributes of the first character are used for the whole text");
}

@end
