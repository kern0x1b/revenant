#import "check.h"

typedef NSAttributedString *(*RevenantInitWithContext)(id, SEL, NSAttributedString *, NSAttributedStringFormattingOptions, NSLocale *, NSDictionary *, ...);
typedef NSAttributedString *(*RevenantClassWithContext)(id, SEL, NSAttributedString *, NSDictionary *, ...);
typedef NSAttributedString *(*RevenantClassWithOptions)(id, SEL, NSAttributedString *, NSAttributedStringFormattingOptions, NSDictionary *, ...);

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSAttributedString *format = [[NSAttributedString alloc] initWithString:@"%@ has %d items" attributes:@{NSLanguageIdentifierAttributeName: @"en"}];
    NSDictionary *context = @{};
    SEL initSelector = @selector(initWithFormat:options:locale:context:);
    RevenantInitWithContext initialize = REVENANT_IMP(NSAttributedString, initSelector, RevenantInitWithContext);
    NSAttributedString *made = initialize([NSAttributedString alloc], initSelector, format, 0, [NSLocale localeWithLocaleIdentifier:@"en_US"], context, @"Box", 3);
    revenant_expect_string("the initializer formats with its arguments", made.string, revenant_negative ? @"Box has 4 items" : @"Box has 3 items");
    SEL classSelector = @selector(localizedAttributedStringWithFormat:context:);
    RevenantClassWithContext make = REVENANT_CLASS_IMP(NSAttributedString, classSelector, RevenantClassWithContext);
    NSAttributedString *localized = make([NSAttributedString class], classSelector, format, context, @"Crate", 12);
    revenant_expect_string("the class method formats with its arguments", localized.string, @"Crate has 12 items");
    SEL optionsSelector = @selector(localizedAttributedStringWithFormat:options:context:);
    RevenantClassWithOptions makeWithOptions = REVENANT_CLASS_IMP(NSAttributedString, optionsSelector, RevenantClassWithOptions);
    NSAttributedString *withOptions = makeWithOptions([NSAttributedString class], optionsSelector, format, NSAttributedStringFormattingInsertArgumentAttributesWithoutMerging, context, @"Bag", 1);
    revenant_expect_string("the class method with options formats", withOptions.string, @"Bag has 1 items");
    revenant_check([[made attribute:NSLanguageIdentifierAttributeName atIndex:0 effectiveRange:NULL] isEqual:@"en"], "the format's attributes carry over", @"lost");
    return revenant_finish();
}
