#import "check.h"

NSString *revenant_date_context(NSString *text, NSString *pattern, NSLocale *locale, NSFormattingContext context);

static void revenant_system_context(NSDateFormatter *formatter, NSFormattingContext context)
{
    unsigned count = 0;
    Method *methods = class_copyMethodList([NSDateFormatter class], &count);
    IMP original = NULL;
    for (unsigned index = 0; index < count; index++) {
        if (method_getName(methods[index]) == @selector(setFormattingContext:))
            original = method_getImplementation(methods[index]);
    }
    free(methods);
    ((void (*)(id, SEL, NSFormattingContext))original)(formatter, @selector(setFormattingContext:), context);
}

static NSString *revenant_format(NSLocale *locale, NSString *pattern, NSFormattingContext context, NSDate *date)
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = locale;
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = pattern;
    revenant_system_context(formatter, context);
    return [formatter stringFromDate:date];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1760000000];
    NSArray *patterns = @[@"EEEE d MMMM y", @"MMMM y", @"MMMM", @"EEEE", @"EEE", @"LLL", @"cccc", @"MMM d", @"d MMMM", @"y"];
    NSArray *languages = @[@"es", @"fr", @"it", @"pt", @"nl", @"ru", @"pl", @"cs", @"ca", @"fi", @"de", @"en", @"ja", @"tr", @"sv", @"da", @"hu", @"uk", @"hr", @"zh"];
    NSArray *contexts = @[@(NSFormattingContextStandalone), @(NSFormattingContextListItem), @(NSFormattingContextBeginningOfSentence), @(NSFormattingContextMiddleOfSentence), @(NSFormattingContextDynamic)];
    int compared = 0, wrong = 0;
    NSString *first = nil;
    for (NSString *language in languages) {
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:language];
        for (NSString *pattern in patterns) {
            NSString *base = revenant_format(locale, pattern, NSFormattingContextUnknown, date);
            for (NSNumber *context in contexts) {
                NSString *expected = revenant_format(locale, pattern, (NSFormattingContext)context.integerValue, date);
                NSString *ours = revenant_date_context(base, pattern, locale, (NSFormattingContext)context.integerValue);
                compared++;
                if (![ours isEqualToString:expected]) {
                    wrong++;
                    if (!first)
                        first = [NSString stringWithFormat:@"%@ %@ %@: %@ is not %@", language, pattern, context, ours, expected];
                }
            }
        }
    }
    revenant_check(compared > 0 && wrong == 0, "the capitalization matches Foundation for every language, pattern and context", first ?: @"matched");
    revenant_expect_string("a Spanish standalone weekday is capitalized", revenant_date_context(@"jueves", @"EEEE", [NSLocale localeWithLocaleIdentifier:@"es"], NSFormattingContextStandalone), revenant_negative ? @"jueves" : @"Jueves");
    revenant_expect_string("a Spanish middle of sentence weekday is kept", revenant_date_context(@"jueves", @"EEEE", [NSLocale localeWithLocaleIdentifier:@"es"], NSFormattingContextMiddleOfSentence), @"jueves");
    revenant_expect_string("a number first is kept", revenant_date_context(@"9 octubre", @"d MMMM", [NSLocale localeWithLocaleIdentifier:@"es"], NSFormattingContextStandalone), @"9 octubre");
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    revenant_check(formatter.formattingContext == NSFormattingContextUnknown, "the default context is unknown", @"differs");
    formatter.formattingContext = NSFormattingContextListItem;
    revenant_check(formatter.formattingContext == NSFormattingContextListItem, "the context is stored", @"differs");
    return revenant_finish();
}
