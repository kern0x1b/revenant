#import <UIKit/UIKit.h>

static NSString *answer(UITextView *view)
{
    NSDictionary *attributes = [view typingAttributes];
    UIFont *font = [attributes objectForKey:NSFontAttributeName];
    UIColor *color = [attributes objectForKey:NSForegroundColorAttributeName];
    NSParagraphStyle *paragraph = [attributes objectForKey:NSParagraphStyleAttributeName];
    NSString *colorName = @"-";
    if (color)
        colorName = [color isEqual:[UIColor blueColor]] ? @"blue" : ([color isEqual:[UIColor redColor]] ? @"red" : @"other");
    return [NSString stringWithFormat:@"keys %lu font %@ color %@ para %@ range %@", (unsigned long)attributes.count,
            font ? [NSString stringWithFormat:@"%.0f", font.pointSize] : @"-", colorName,
            paragraph ? [NSString stringWithFormat:@"%ld", (long)paragraph.alignment] : @"-", NSStringFromRange(view.selectedRange)];
}

static void row(NSString *name, UITextView *view)
{
    printf("ROW %s: %s\n", [name UTF8String], [answer(view) UTF8String]);
}

static UITextView *make(void)
{
    return [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 160, 44)];
}

int main(void)
{
    @autoreleasepool {
        NSDictionary *chosen = @{NSFontAttributeName: [UIFont systemFontOfSize:23], NSForegroundColorAttributeName: [UIColor blueColor]};

        UITextView *empty = make();
        row(@"empty default", empty);

        UITextView *styled = make();
        styled.font = [UIFont systemFontOfSize:19];
        styled.textColor = [UIColor redColor];
        styled.textAlignment = NSTextAlignmentCenter;
        row(@"font 19 red centred", styled);

        UITextView *view = make();
        view.text = @"hello";
        row(@"text hello", view);
        [view setTypingAttributes:chosen];
        row(@"set", view);
        view.selectedRange = NSMakeRange(2, 0);
        row(@"set then the caret moved to 2", view);
        [view setTypingAttributes:chosen];
        view.selectedRange = NSMakeRange(2, 0);
        row(@"set then the same range assigned", view);
        view.selectedRange = NSMakeRange(2, 2);
        row(@"then a range selected", view);
        [view setTypingAttributes:chosen];
        view.selectedRange = NSMakeRange(5, 0);
        row(@"set then the caret moved to 5", view);
        [view setTypingAttributes:chosen];
        view.textAlignment = NSTextAlignmentCenter;
        row(@"set then textAlignment centre", view);

        UITextView *bare = make();
        bare.font = nil;
        bare.textColor = nil;
        printf("ROW font and textColor assigned nil: font %s textColor %s\n", bare.font ? "set" : "nil", bare.textColor ? "set" : "nil");
        row(@"font and textColor nil", bare);

        UITextView *left = make();
        left.font = [UIFont systemFontOfSize:15];
        left.textAlignment = NSTextAlignmentLeft;
        row(@"font 15, textAlignment assigned left", left);

        UITextView *untouched = make();
        untouched.font = [UIFont systemFontOfSize:15];
        row(@"font 15, textAlignment untouched", untouched);
        fflush(stdout);
    }
    return 0;
}
