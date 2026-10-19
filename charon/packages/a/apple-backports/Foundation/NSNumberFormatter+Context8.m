#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

/* The minimum grouping digits of a number formatter, and its formatting context.

   The minimum grouping digits are applied: they decide which of the groups the release's formatter
   wrote are long enough to keep a separator. The host's own default is 1 (measured: a fresh formatter
   answers 1), so 1.234 keeps its separator, and a formatter that asks for 2 takes the separator off a
   three digit group.

   The formatting context is kept and answered, and is not applied to the digits: the line direction
   contexts that move a negative sign arrived with iOS 26 and the release's own number formatting has
   no such context, so a port that moved the sign would be writing something the release's formatter
   does not. The value the application sets is the value it reads back, which is the whole of what the
   property is on this release; facts/Foundation/NSNumberFormatterContext.md says so. */

static char CharonNumberFormatterContextKey;
static char CharonNumberFormatterGroupingKey;

/* The minimum grouping digits are ICU's rule, and it is all or nothing: the integer part is grouped
   at all when it has at least `grouping size + minimum` digits, and then every separator the release
   wrote stays. Which is what the host answers, measured over five numbers, five thresholds and three
   locales by tests/backports/host/foundationbatch: 1,234 is four digits and is not grouped at a
   minimum of two (4 < 3 + 2), while 1,234,567 is seven digits and keeps both of its separators at
   every threshold (7 >= 3 + 4 at four). The grouping size is the release's own, three, which is what
   the separators it wrote show. */
/* The digits of the integer part, which is everything before the locale's own decimal separator --
   and not before a grouping separator, which is part of the integer part too. */
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
        return text; /* enough digits for every group, so every separator the release wrote stays */
    /* Not enough digits to group at all, so the release's grouping separators come off. Which
       character those are is the locale's own answer rather than a guess: en_US groups with a comma
       and de_DE with a full stop, and a full stop is also the decimal separator in de_DE, so the two
       cannot be told apart by looking at the number. */
    NSString *grouping = locale.groupingSeparator;
    if (!grouping.length)
        return text;
    NSArray *parts = [text componentsSeparatedByString:grouping];
    if (parts.count < 2)
        return text;
    return [parts componentsJoinedByString:@""];
}

/* The release's own -[NSNumberFormatter stringFromNumber:] and the name it answers to, both taken
   before this port takes that name over. A category cannot do this itself, and not because of a
   spelling: attach.c's charon_collect skips a selector the class already answers (attach.c:165), so a
   category's -stringFromNumber: is dropped on every release that has one -- which is every release
   this port is for -- and the grouping was never applied at all. Reached through objc_msgSendSuper
   naming the class it does not work either, because the lookup starts at the class and finds this
   port's own method again: that is a call that never returns, which is what tests/backports/host/
   foundationbatch measured (a stack of alternating -[NSNumberFormatter(CharonContext) stringFromNumber:]
   and charon_release_string, ending in objc_storeStrong). So the release's implementation is held by
   name, the way UICollectionView+Prefetching10.m and UIImageView+Template7.m hold theirs. */
static IMP CharonReleaseStringFromNumber;
static SEL CharonReleaseStringFromNumberName;

static NSString *charon_release_string(NSNumberFormatter *formatter, NSNumber *number)
{
    return ((NSString * (*)(id, SEL, id))CharonReleaseStringFromNumber)(formatter, CharonReleaseStringFromNumberName, number);
}

@interface NSNumberFormatter (CharonGrouping)
/* The locale whose separators the grouping reads, read by name so that the selector rewriter can
   rename it: a category cannot reach a method through dot syntax when the method is renamed. */
- (NSLocale *)charon_groupingLocale;
- (NSUInteger)charon_numberFormatterMinimumGroupingDigits;
@end

/* What the port puts in place of the release's own -stringFromNumber:, as a plain function so that
   the loader below can hand it to class_replaceMethod: a category method's IMP is not reachable
   before attach.c runs, and a category's copy of it is dropped anyway. */
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

/* +load, and not the library's own constructor, because the runtime finishes every +load in the
   image before it runs the first constructor: the release's -stringFromNumber: is still the class's
   own here, which is the only moment at which it can be read (the same ordering UICollectionView+
   Prefetching10.m's +load relies on). The two selectors are spelled as strings and not as
   @selector() because tests/backports/host/prefix_selectors.py renames an @selector of a selector
   this file defines, and the release's own spelling is the one that must not move. */
+ (void)load
{
    Class formatter = [NSNumberFormatter class];
    Method release = class_getInstanceMethod(formatter, NSSelectorFromString(@"stringFromNumber:"));
    if (!release)
        return;
    CharonReleaseStringFromNumber = method_getImplementation(release);
    CharonReleaseStringFromNumberName = method_getName(release);
    /* Nothing to install where the release's own formatter already answers the minimum: it applies it
       itself, so its -stringFromNumber: is the answer, and taking the name over would replace a method
       the host still needs for its own. This is the guard UICollectionView+Prefetching10.m and
       UITableView+PrefetchingEnabled15.m install theirs behind, asked of the release's spelling:
       -minimumGroupingDigits arrived in iOS 18 and the releases this port is for have none
       (registry/Foundation/nz-batch2.json). */
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

/* Read by name, for the same reason as the progress's handler: the rewriter renames the selector. */
- (NSUInteger)charon_numberFormatterMinimumGroupingDigits
{
    return [self minimumGroupingDigits];
}

/* The same work the loader installs, under the name the host differential's rewrite renames. On a
   release that has no -minimumGroupingDigits the loader has already put charon_grouped_string in
   place of this name and attach.c drops this copy (charon_collect skips a selector the class
   answers), so this answers only where the host differential sends it -- beside the host's own
   -stringFromNumber:, which is what the differential compares it against. */
- (NSString *)stringFromNumber:(NSNumber *)number
{
    return charon_grouped_string(self, _cmd, number);
}

@end
