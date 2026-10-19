#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static char CharonNumberFormatterContextKey;
static char CharonNumberFormatterGroupingKey;

static NSUInteger charon_integer_digits(NSString *text, NSString *decimal)
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

static NSString *charon_grouped(NSString *text, NSLocale *locale, NSUInteger minimum)
{
    NSString *decimal = locale.decimalSeparator;
    if (charon_integer_digits(text, decimal) >= 3 + minimum)
        return text;
    NSString *grouping = locale.groupingSeparator;
    if (!grouping.length)
        return text;
    NSArray *parts = [text componentsSeparatedByString:grouping];
    if (parts.count < 2)
        return text;
    return [parts componentsJoinedByString:@""];
}

static IMP CharonReleaseStringFromNumber;
static SEL CharonReleaseStringFromNumberName;

static NSString *charon_release_string(NSNumberFormatter *formatter, NSNumber *number)
{
    return ((NSString * (*)(id, SEL, id))CharonReleaseStringFromNumber)(formatter, CharonReleaseStringFromNumberName, number);
}

@interface NSNumberFormatter (CharonGrouping)
- (NSLocale *)charon_groupingLocale;
- (NSUInteger)charon_numberFormatterMinimumGroupingDigits;
@end

static NSString *charon_grouped_string(id formatter, SEL command, id number)
{
    NSNumberFormatter *self_ = (NSNumberFormatter *)formatter;
    NSString *text = charon_release_string(self_, (NSNumber *)number);
    if (!text)
        return text;
    return charon_grouped(text, [self_ charon_groupingLocale], [self_ charon_numberFormatterMinimumGroupingDigits]);
}

@interface CharonNumberFormatterContextInstaller : NSObject
@end

@implementation CharonNumberFormatterContextInstaller

+ (void)load
{
    Class formatter = [NSNumberFormatter class];
    Method release = class_getInstanceMethod(formatter, NSSelectorFromString(@"stringFromNumber:"));
    if (!release)
        return;
    CharonReleaseStringFromNumber = method_getImplementation(release);
    CharonReleaseStringFromNumberName = method_getName(release);
    if (class_getInstanceMethod(formatter, NSSelectorFromString(@"minimumGroupingDigits")))
        return;
    class_replaceMethod(formatter, CharonReleaseStringFromNumberName, (IMP)charon_grouped_string, method_getTypeEncoding(release));
}

@end

@implementation NSNumberFormatter (CharonContext)

- (NSLocale *)charon_groupingLocale
{
    return self.locale ?: [NSLocale currentLocale];
}

- (NSFormattingContext)formattingContext
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonNumberFormatterContextKey);
    return (NSFormattingContext)(stored ? stored.integerValue : NSFormattingContextUnknown);
}

- (void)setFormattingContext:(NSFormattingContext)context
{
    objc_setAssociatedObject(self, &CharonNumberFormatterContextKey, @(context), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)minimumGroupingDigits
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonNumberFormatterGroupingKey);
    return stored ? stored.unsignedIntegerValue : 1;
}

- (void)setMinimumGroupingDigits:(NSUInteger)digits
{
    objc_setAssociatedObject(self, &CharonNumberFormatterGroupingKey, @(digits), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)charon_numberFormatterMinimumGroupingDigits
{
    return [self minimumGroupingDigits];
}

- (NSString *)stringFromNumber:(NSNumber *)number
{
    return charon_grouped_string(self, _cmd, number);
}

@end
