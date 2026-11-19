#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>

@interface RevenantTypingSubclassView : UITextView
@end

@implementation RevenantTypingSubclassView
- (NSDictionary *)typingAttributes
{
    return [super typingAttributes];
}
@end

static void revenant_prepare_text_view_host(void)
{
    (void)[UIApplication sharedApplication];
    void *graphics = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_NOW);
    void (*initialize)(void) = graphics ? dlsym(graphics, "GSInitialize") : NULL;
    if (initialize)
        initialize();
    void (*webkit)(void) = dlsym(RTLD_DEFAULT, "WebKitInitialize");
    printf("typing host: GSInitialize %d, WebKitInitialize %d\n", initialize != NULL, webkit != NULL);
    fflush(stdout);
    if (webkit)
        webkit();
}

REVENANT_CASE(uitextview_typing_attributes)
{
    revenant_prepare_text_view_host();
    printf("typing step: creating a text view\n");
    fflush(stdout);
    UITextView *fresh = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 160, 44)];
    printf("typing fact: a fresh view has selectedRange %s, text length %lu, font %s, text colour %s, alignment %ld\n",
           [NSStringFromRange(fresh.selectedRange) UTF8String], (unsigned long)fresh.text.length,
           [[fresh.font description] UTF8String], [[fresh.textColor description] UTF8String], (long)fresh.textAlignment);
    fflush(stdout);

    NSDictionary *attributes = [fresh typingAttributes];
    printf("typing fact: a fresh view answers the keys %s\n", [[[attributes allKeys] description] UTF8String]);
    fflush(stdout);
    revenant_expect_true(@"the font of the view is the font of the next character",
                         (!fresh.font || [[attributes objectForKey:NSFontAttributeName] isEqual:fresh.font]) != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", attributes]);
    revenant_expect_true(@"the text colour of the view is the colour of the next character",
                         (!fresh.textColor || [[attributes objectForKey:NSForegroundColorAttributeName] isEqual:fresh.textColor]) != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", attributes]);
    revenant_expect_true(@"a left aligned view has no paragraph style",
                         ([attributes objectForKey:NSParagraphStyleAttributeName] == nil) != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", attributes]);

    UITextView *centered = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 160, 44)];
    centered.font = [UIFont systemFontOfSize:19];
    centered.textColor = [UIColor redColor];
    centered.textAlignment = NSTextAlignmentCenter;
    NSDictionary *styled = [centered typingAttributes];
    NSParagraphStyle *paragraph = [styled objectForKey:NSParagraphStyleAttributeName];
    revenant_expect_true(@"font and colour follow the properties set on the view",
                         ([[styled objectForKey:NSFontAttributeName] isEqual:centered.font] &&
                          [[styled objectForKey:NSForegroundColorAttributeName] isEqual:[UIColor redColor]]) != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", styled]);
    revenant_expect_true(@"a centred view has a centred paragraph style",
                         ([paragraph isKindOfClass:[NSParagraphStyle class]] && paragraph.alignment == NSTextAlignmentCenter) != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", paragraph]);

    NSDictionary *chosen = @{NSFontAttributeName: [UIFont systemFontOfSize:23], NSForegroundColorAttributeName: [UIColor blueColor]};
    [centered setTypingAttributes:chosen];
    NSDictionary *after = [centered typingAttributes];
    revenant_expect_true(@"setTypingAttributes: is answered as it was set",
                         (after.count == 2 && [[after objectForKey:NSFontAttributeName] isEqual:[chosen objectForKey:NSFontAttributeName]] &&
                          [[after objectForKey:NSForegroundColorAttributeName] isEqual:[chosen objectForKey:NSForegroundColorAttributeName]]) != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", after]);

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"hello"];
    [text addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(0, 5)];
    UITextView *withSelection = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 160, 44)];
    withSelection.attributedText = text;
    [withSelection setSelectedRange:NSMakeRange(2, 0)];
    printf("typing fact: a view with text and a caret has selectedRange %s\n", [NSStringFromRange(withSelection.selectedRange) UTF8String]);
    fflush(stdout);
    NSDictionary *atSelection = [withSelection typingAttributes];
    revenant_expect_true(@"the system answers where a selection exists",
                         [[atSelection objectForKey:NSForegroundColorAttributeName] isEqual:[UIColor redColor]] != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", atSelection]);

    UITextView *stored = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 160, 44)];
    [stored setTypingAttributes:chosen];
    stored.attributedText = text;
    [stored setSelectedRange:NSMakeRange(2, 0)];
    NSDictionary *replaced = [stored typingAttributes];
    revenant_expect_true(@"attributes set before a selection existed do not outlive it",
                         [[replaced objectForKey:NSForegroundColorAttributeName] isEqual:[UIColor redColor]] != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", replaced]);

    RevenantTypingSubclassView *subclass = [[RevenantTypingSubclassView alloc] initWithFrame:CGRectMake(0, 0, 160, 44)];
    NSDictionary *fromSubclass = [subclass typingAttributes];
    revenant_expect_true(@"a subclass that calls super gets the answer",
                         (!subclass.textColor || [[fromSubclass objectForKey:NSForegroundColorAttributeName] isEqual:subclass.textColor]) != (BOOL)negative,
                         [NSString stringWithFormat:@"%@", fromSubclass]);
}
