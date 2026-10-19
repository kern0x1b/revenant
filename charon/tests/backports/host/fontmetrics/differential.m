#import <UIKit/UIKit.h>

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static NSString *number(CGFloat value)
{
    return [NSString stringWithFormat:@"%g", value];
}

int main(void)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostUIFontMetrics");
        NSArray *styles = @[UIFontTextStyleBody, UIFontTextStyleHeadline, UIFontTextStyleFootnote, UIFontTextStyleCaption1];
        for (UIFontTextStyle style in styles) {
            UIFontMetrics *system = [UIFontMetrics metricsForTextStyle:style];
            UIFontMetrics *mine = [ours metricsForTextStyle:style];
            for (NSNumber *value in @[@10, @10.3, @10.5, @10.7, @0.1, @(-3.3), @0, @100.25])
                compare([NSString stringWithFormat:@"%@ scales %@", style, value],
                        number([system scaledValueForValue:value.doubleValue]),
                        number([mine scaledValueForValue:value.doubleValue]));

            for (NSNumber *size in @[@11, @17, @34]) {
                UIFont *font = [UIFont systemFontOfSize:size.doubleValue];
                compare([NSString stringWithFormat:@"%@ scales a %@ point font", style, size],
                        number([system scaledFontForFont:font].pointSize),
                        number([mine scaledFontForFont:font].pointSize));
                compare([NSString stringWithFormat:@"%@ caps a %@ point font at 12", style, size],
                        number([system scaledFontForFont:font maximumPointSize:12].pointSize),
                        number([mine scaledFontForFont:font maximumPointSize:12].pointSize));
            }
        }

        UIFont *custom = [UIFont fontWithName:@"Helvetica" size:13];
        UIFontMetrics *system = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
        UIFontMetrics *mine = [ours metricsForTextStyle:UIFontTextStyleBody];
        compare(@"a custom font keeps its name", [system scaledFontForFont:custom].fontName, [mine scaledFontForFont:custom].fontName);
        compare(@"a custom font keeps its size", number([system scaledFontForFont:custom].pointSize), number([mine scaledFontForFont:custom].pointSize));
        compare(@"the scaled font is a new object",
                [system scaledFontForFont:custom] == custom ? @"the same" : @"a new one",
                [mine scaledFontForFont:custom] == custom ? @"the same" : @"a new one");
        compare(@"the default metrics scale like the body",
                number([[UIFontMetrics defaultMetrics] scaledValueForValue:10.3]),
                number([[ours defaultMetrics] scaledValueForValue:10.3]));

        NSString *systemRaise = @"none", *ourRaise = @"none";
        @try { [system scaledFontForFont:nil]; } @catch (NSException *exception) { systemRaise = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]; }
        @try { [mine scaledFontForFont:nil]; } @catch (NSException *exception) { ourRaise = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]; }
        compare(@"a nil font is refused the same way", systemRaise, ourRaise);

        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
