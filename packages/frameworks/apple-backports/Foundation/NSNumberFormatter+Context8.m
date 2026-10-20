#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static char RevenantNumberFormatterContextKey;
static char RevenantNumberFormatterGroupingKey;

static NSUInteger revenant_integer_digits(NSString *text, NSString *decimal)
{
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    NSString *integer = text;
    NSRange point = decimal.length ? [text rangeOfString:decimal] : NSMakeRange(NSNotFound, 0);
    if (point.location != NSNotFound)
        integer = [text substringToIndex:point.location];
    NSUInteger seen = 0;
    for (NSUInteger index = 0; index < integer.length; index++)
        if ([digits characterIsMember:[integer characterAtIndex:index]])
            seen++;
    return seen;
}

static NSString *revenant_grouped(NSString *text, NSLocale *locale, NSUInteger minimum)
{
    NSString *decimal = locale.decimalSeparator;
    if (revenant_integer_digits(text, decimal) >= 3 + minimum)
        return text;
    NSString *grouping = locale.groupingSeparator;
    if (!grouping.length)
        return text;
    NSArray *parts = [text componentsSeparatedByString:grouping];
    if (parts.count < 2)
        return text;
    return [parts componentsJoinedByString:@""];
}

static IMP RevenantReleaseStringFromNumber;
static SEL RevenantReleaseStringFromNumberName;

static NSString *revenant_release_string(NSNumberFormatter *formatter, NSNumber *number)
{
    return ((NSString * (*)(id, SEL, id))RevenantReleaseStringFromNumber)(formatter, RevenantReleaseStringFromNumberName, number);
}

@interface NSNumberFormatter (RevenantGrouping)
- (NSLocale *)revenant_groupingLocale;
- (NSUInteger)revenant_numberFormatterMinimumGroupingDigits;
@end

static NSString *revenant_grouped_string(id formatter, SEL command, id number)
{
    NSNumberFormatter *self_ = (NSNumberFormatter *)formatter;
    NSString *text = revenant_release_string(self_, (NSNumber *)number);
    if (!text)
        return text;
    return revenant_grouped(text, [self_ revenant_groupingLocale], [self_ revenant_numberFormatterMinimumGroupingDigits]);
}

@interface RevenantNumberFormatterContextInstaller : NSObject
@end

@implementation RevenantNumberFormatterContextInstaller

+ (void)load
{
    Class formatter = [NSNumberFormatter class];
    Method release = class_getInstanceMethod(formatter, NSSelectorFromString(@"stringFromNumber:"));
    if (!release)
        return;
    RevenantReleaseStringFromNumber = method_getImplementation(release);
    RevenantReleaseStringFromNumberName = method_getName(release);
    if (class_getInstanceMethod(formatter, NSSelectorFromString(@"minimumGroupingDigits")))
        return;
    class_replaceMethod(formatter, RevenantReleaseStringFromNumberName, (IMP)revenant_grouped_string, method_getTypeEncoding(release));
}

@end

@implementation NSNumberFormatter (RevenantContext)

- (NSLocale *)revenant_groupingLocale
{
    return self.locale ?: [NSLocale currentLocale];
}

- (NSFormattingContext)formattingContext
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantNumberFormatterContextKey);
    return (NSFormattingContext)(stored ? stored.integerValue : NSFormattingContextUnknown);
}

- (void)setFormattingContext:(NSFormattingContext)context
{
    objc_setAssociatedObject(self, &RevenantNumberFormatterContextKey, @(context), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)minimumGroupingDigits
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantNumberFormatterGroupingKey);
    return stored ? stored.unsignedIntegerValue : 1;
}

- (void)setMinimumGroupingDigits:(NSUInteger)digits
{
    objc_setAssociatedObject(self, &RevenantNumberFormatterGroupingKey, @(digits), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)revenant_numberFormatterMinimumGroupingDigits
{
    return [self minimumGroupingDigits];
}

- (NSString *)stringFromNumber:(NSNumber *)number
{
    return revenant_grouped_string(self, _cmd, number);
}

@end
