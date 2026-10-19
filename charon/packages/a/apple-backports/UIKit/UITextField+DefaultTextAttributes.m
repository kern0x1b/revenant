#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_default_attributes_key;

static UITextField *charon_reference_field(void)
{
    static UITextField *field;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        field = [[UITextField alloc] init];
    });
    return field;
}

@implementation UITextField (CharonDefaultTextAttributes)

- (NSDictionary *)defaultTextAttributes
{
    NSMutableDictionary *attributes = [objc_getAssociatedObject(self, &charon_default_attributes_key) mutableCopy];
    if (!attributes)
        attributes = [NSMutableDictionary dictionary];
    NSMutableParagraphStyle *paragraph = [[attributes objectForKey:NSParagraphStyleAttributeName] mutableCopy];
    if (!paragraph) {
        paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    paragraph.alignment = self.textAlignment;
    [attributes setObject:paragraph forKey:NSParagraphStyleAttributeName];
    UIFont *font = self.font;
    if (font)
        [attributes setObject:font forKey:NSFontAttributeName];
    else
        [attributes removeObjectForKey:NSFontAttributeName];
    UIColor *color = self.textColor;
    if (color)
        [attributes setObject:color forKey:NSForegroundColorAttributeName];
    else
        [attributes removeObjectForKey:NSForegroundColorAttributeName];
    return attributes;
}

- (void)setDefaultTextAttributes:(NSDictionary *)defaultTextAttributes
{
    UITextField *reference = charon_reference_field();
    NSMutableDictionary *kept = [defaultTextAttributes mutableCopy] ?: [NSMutableDictionary dictionary];
    UIFont *font = [kept objectForKey:NSFontAttributeName];
    UIColor *color = [kept objectForKey:NSForegroundColorAttributeName];
    NSParagraphStyle *paragraph = [kept objectForKey:NSParagraphStyleAttributeName];
    [kept removeObjectForKey:NSFontAttributeName];
    [kept removeObjectForKey:NSForegroundColorAttributeName];
    if (paragraph)
        [kept setObject:[paragraph copy] forKey:NSParagraphStyleAttributeName];
    objc_setAssociatedObject(self, &charon_default_attributes_key, kept, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.font = font ?: reference.font;
    self.textColor = color ?: reference.textColor;
    self.textAlignment = paragraph ? paragraph.alignment : reference.textAlignment;
    NSString *text = self.text;
    if (text.length)
        self.attributedText = [[NSAttributedString alloc] initWithString:text attributes:[self defaultTextAttributes]];
}

@end
