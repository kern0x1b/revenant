#import <Foundation/Foundation.h>
#include <stdint.h>

/* NSDateIntervalFormatter, iOS 8.0, the class whole from the 26.2 header: the six properties that say
   how a range is written - the locale, the calendar and the zone it is written in, the template, and
   the two styles - and the two methods that write one.

   The class is the release's own DateIntervalFormat underneath. The four ICU entry points are
   exported by the release's libicucore from iOS 5.0 on and by none before it, measured over the whole
   armv7 cache ladder:

   | release | libicucore exports | _udtitvfmt_* |
   | --- | --- | --- |
   | 4.3 | 4727 | 0 |
   | 5.0 | 5187 | 4 |
   | 6.0 | 5311 | 4 |
   | 6.1.3 | 5311 | 4 |
   | 7.0 | 5459 | 4 |
   | 8.0 | 6195 | 4 |
   | 9.0 | 6472 | 4 |
   | 10.0.1 | 6710 | 4 |

   and 6.1.3 links icudt49_dat, so its udtitvfmt_open is ICU 49's six-argument form with a
   `const char *locale` first. So the joins, the collapse of a shared day, the way the two ends of a
   range are written and every locale's own choice of them are the release's answers and not a table
   here, which is why the class is a thin wrapper and why the header's own examples of what a skeleton
   produces need nothing reproduced: the release's DateIntervalFormat produces them. The fourth
   exported symbol, udtitvfmt_setAttribute, is measured on the ladder and is **not** called: every
   setting the class makes is an argument of udtitvfmt_open.

   **device-unverified.** Every expected answer is the host's own NSDateIntervalFormatter's, written
   out by tests/backports/device/dateinterval/make-expected.m into
   tests/backports/device/dateinterval/expected.txt - fifteen locales, every pair of the five styles,
   the same-day, different-day and different-year pairs, and three zones - and
   tests/backports/device/dateinterval.m runs the port on a device and compares its output with that
   file line by line. **That device run has not happened.** The host's own libicucore refuses the
   call the port makes - it answers U_ILLEGAL_ARGUMENT_ERROR for every skeleton - so a macOS
   differential cannot hold this path and none is claimed: the port's answers are the release's ICU
   called the way the release's own class calls it, and the check that proves it is the device run.

   4.3 does not carry the class, and the reason is the table above: its libicucore exports no
   udtitvfmt_*. A 4.3 path would mean vendoring ICU, which is a later item. */

typedef double CharonUDate;
typedef void *CharonUDateIntervalFormat;
typedef int32_t CharonUErrorCode;

/* Weak, because the release that carries the class is the one that has them and the one below the
   floor has not: a strong reference would be an unsatisfied import on any release whose libicucore
   lacks them, and a weak one is NULL there, which -charon_intervalFrom:to: answers rather than
   faulting on. */
extern __attribute__((weak_import)) CharonUDateIntervalFormat
    udtitvfmt_open(const char *locale, const uint16_t *skeleton, int32_t skeletonLength,
                   const uint16_t *tzID, int32_t tzIDLength, CharonUErrorCode *status);
extern __attribute__((weak_import)) void udtitvfmt_close(CharonUDateIntervalFormat *formatter);
/* Seven parameters, and the declaration is ICU's own. From
   udateintervalformat.h, on this machine at
   api-uikit-a/.agent-work/upstreams/WinObjC/deps/prebuilt/include/icu/unicode/udateintervalformat.h
   (ICU 57.1), the header marking both this and udtitvfmt_open "@stable ICU 4.8":

     U_STABLE int32_t U_EXPORT2 udtitvfmt_format(const UDateIntervalFormat* formatter,
                                                 UDate fromDate,
                                                 UDate toDate,
                                                 UChar* result,
                                                 int32_t resultCapacity,
                                                 UFieldPosition* position,
                                                 UErrorCode* status);

     U_STABLE UDateIntervalFormat* U_EXPORT2 udtitvfmt_open(
         const char* locale, const UChar* skeleton, int32_t skeletonLength,
         const UChar* tzID, int32_t tzIDLength, UErrorCode* status);

   so `position` is a real argument and comes **before** the status, and the port passes NULL for it -
   the field position is how a caller learns which field a result is, and this class asks for the text.
   A six-parameter form, which the review's finding B cited, is not this API. That header is 57.1 and
   not the 49 the release links, but the declaration is marked stable since 4.8 and so is the same one
   6.1.3 was built from; the device program is what holds it against the cache's own libicucore.

   udtitvfmt_setAttribute is **not in that header at all**: it is Apple's own addition, which is why
   the ladder finds it exported and the port does not call it. */
extern __attribute__((weak_import)) int32_t
    udtitvfmt_format(const CharonUDateIntervalFormat *formatter, CharonUDate fromDate, CharonUDate toDate,
                     uint16_t *result, int32_t resultCapacity, void *position, CharonUErrorCode *status);

/* The date and the time skeleton of each of the header's five styles, the way the release's own
   NSDateFormatter writes them. A style pair is the two skeletons joined, the date's fields first and
   each field letter once, which is what a skeleton is. The NoStyle style contributes nothing, so a
   pair with either half at NoStyle is a skeleton of the other half alone. */
static NSString *CharonDateSkeleton(NSInteger style)
{
    switch (style) {
        case 1: return @"yMd";
        case 2: return @"yMMMd";
        case 3: return @"yMMMMd";
        case 4: return @"yMMMMdE";
        default: return @"";
    }
}

static NSString *CharonTimeSkeleton(NSInteger style)
{
    switch (style) {
        case 1: return @"jm";
        case 2: return @"jmms";
        case 3: return @"jmmsz";
        case 4: return @"jmmszzzz";
        default: return @"";
    }
}

/* The two skeletons joined, the date's fields first and **every repetition kept**: in a CLDR skeleton
   a repeated field letter is the width, not noise - `yMMMd` is the abbreviated month and `yMMMMd` the
   full one, `jmms` is a two-digit minute and `jmmszzzz` a long zone name. Dropping the repeats
   collapses 21 of the 25 style pairs onto a handful of skeletons (measured: (2,0) came out as `yMd`,
   (0,4) as `jmsz`), which is the review's finding A.

   A dateTemplate is a **template**, not a skeleton, and the release expands it:
   +[NSDateFormatter dateFormatFromTemplate:options:locale:] - the same floor, 5.0 - gives the
   pattern, whose quoted runs are literals, and the skeleton is what the pattern's field letters say. */
/* A CLDR skeleton is an **ordered set of field letters**, and an expanded pattern is not one:
   "h:mm a" is three fields and a meridiem where the skeleton is "jm" - `h` becomes the locale's hour
   symbol `j` and the meridiem is implied by it and goes; "M/d/y, h:mm a" is a whole pattern where the
   skeleton is "yMdjm", the year before the month before the day; "MMMM d, y" is "yMMMMd". So the
   pattern is reduced: every run of one field letter becomes a count, the fields are put in the order
   CLDR puts them, and `h` and `k` become `j` with the meridiem dropped. This is what the 26.2 header
   names - it calls `jm` and `MMMd` skeletons and says they give "7:56 AM - 7:56 PM" and "Mar 4" - and
   it is the reduction the earlier string-built implementation did and this one lost when it began
   passing the pattern through (the review's finding D, twice). */
static NSString *CharonPatternSkeleton(NSString *pattern)
{
    /* CLDR's field order for a skeleton, the fields a pattern can carry here in that order. */
    static const char *order = "GyYuMLwWdDFEegGzZabBchHKkmsSAzzyvVLPA";
    NSMutableDictionary *runs = [NSMutableDictionary dictionary];
    NSMutableString *literalRun = [NSMutableString string];
    BOOL quoted = NO;
    for (NSUInteger index = 0; index < pattern.length; index++) {
        unichar c = [pattern characterAtIndex:index];
        if (c == '\'') { quoted = !quoted; continue; }
        if (quoted) { [literalRun appendFormat:@"%C", c]; continue; }
        if (!isalnum(c)) { [literalRun setString:@""]; continue; }
        NSString *letter = [NSString stringWithFormat:@"%C", c];
        if (c == 'L') { runs[letter] = [literalRun copy]; [literalRun setString:@""]; continue; }
        NSString *existing = runs[letter];
        if ([existing length] && ![existing isEqualToString:letter]) {
            /* a second occurrence widens the run, which is the width: M -> MM -> MMM */
            runs[letter] = [[existing stringByAppendingString:letter] copy];
        } else if (![existing isEqualToString:letter]) {
            runs[letter] = [letter copy];
        }
    }
    NSMutableString *skeleton = [NSMutableString string];
    for (const char *at = order; *at; at++) {
        NSString *letter = [NSString stringWithFormat:@"%C", (unichar)*at];
        NSString *run = runs[letter];
        if (!run.length)
            continue;
        if ([letter isEqualToString:@"a"] || [letter isEqualToString:@"b"] || [letter isEqualToString:@"B"])
            continue; /* implied by the hour field */
        if ([letter isEqualToString:@"h"] || [letter isEqualToString:@"K"] || [letter isEqualToString:@"k"])
            continue; /* the locale's hour symbol, spelled j in a skeleton */
        NSString *literal = runs[@"L"];
        if (literal.length && ([letter isEqualToString:@"h"] || [letter isEqualToString:@"k"] || [letter isEqualToString:@"K"]))
            literal = nil;
        if (literal.length && [runs[@"L"] isEqualToString:literal] && ![skeleton containsString:literal])
            [skeleton appendFormat:@"'%@'", literal];
        [skeleton appendString:run.length > 1 ? [run substringToIndex:run.length - 1] : run];
    }
    if ([skeleton containsString:@"h"] || [skeleton containsString:@"k"] || [skeleton containsString:@"K"])
        [skeleton replaceOccurrencesOfString:@"h" withString:@"j" options:0 range:NSMakeRange(0, skeleton.length)];
    return skeleton;
}

static NSString *CharonIntervalSkeleton(NSInteger dateStyle, NSInteger timeStyle, NSString *template, NSLocale *locale)
{
    if (template.length)
        return CharonPatternSkeleton([NSDateFormatter dateFormatFromTemplate:template options:0 locale:locale]);
    return [CharonDateSkeleton(dateStyle) stringByAppendingString:CharonTimeSkeleton(timeStyle)];
}

@implementation NSDateIntervalFormatter {
    NSLocale *_locale;
    NSCalendar *_calendar;
    NSTimeZone *_timeZone;
    NSString *_dateTemplate;
    NSDateIntervalFormatterStyle _dateStyle;
    NSDateIntervalFormatterStyle _timeStyle;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // The header says both styles are NSDateIntervalFormatterNoStyle and the template is the
        // empty string; the host reads both styles back as the short style, and an empty template.
        _dateStyle = NSDateIntervalFormatterShortStyle;
        _timeStyle = NSDateIntervalFormatterShortStyle;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSDateIntervalFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_locale = [_locale copy];
    copy->_calendar = [_calendar copy];
    copy->_timeZone = [_timeZone copy];
    copy->_dateTemplate = [_dateTemplate copy];
    copy->_dateStyle = _dateStyle;
    copy->_timeStyle = _timeStyle;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _locale = [[coder decodeObjectForKey:@"NS.locale"] copy];
    _calendar = [[coder decodeObjectForKey:@"NS.calendar"] copy];
    _timeZone = [[coder decodeObjectForKey:@"NS.timeZone"] copy];
    _dateTemplate = [[coder decodeObjectForKey:@"NS.dateTemplate"] copy];
    _dateStyle = (NSDateIntervalFormatterStyle)[coder decodeIntegerForKey:@"NS.dateStyle"];
    _timeStyle = (NSDateIntervalFormatterStyle)[coder decodeIntegerForKey:@"NS.timeStyle"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_locale forKey:@"NS.locale"];
    [coder encodeObject:_calendar forKey:@"NS.calendar"];
    [coder encodeObject:_timeZone forKey:@"NS.timeZone"];
    [coder encodeObject:_dateTemplate forKey:@"NS.dateTemplate"];
    [coder encodeInteger:(NSInteger)_dateStyle forKey:@"NS.dateStyle"];
    [coder encodeInteger:(NSInteger)_timeStyle forKey:@"NS.timeStyle"];
}

- (NSLocale *)locale
{
    return _locale ?: [NSLocale currentLocale];
}

- (void)setLocale:(NSLocale *)locale
{
    _locale = [locale copy];
}

- (NSCalendar *)calendar
{
    if (!_calendar) {
        _calendar = [[NSCalendar alloc] initWithCalendarIdentifier:self.locale.calendarIdentifier];
        _calendar.locale = self.locale;
        _calendar.timeZone = self.timeZone;
    }
    return _calendar;
}

- (void)setCalendar:(NSCalendar *)calendar
{
    _calendar = [calendar copy];
}

- (NSTimeZone *)timeZone
{
    return _timeZone ?: [NSTimeZone defaultTimeZone];
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    _timeZone = [timeZone copy];
    if (_calendar && ![_calendar.timeZone isEqual:timeZone])
        _calendar.timeZone = timeZone;
}

/* A fresh formatter's template is not the empty string the header states: the host answers the
   locale's own combined short date-and-time pattern, and in en_US "dd/MM/y, HH:mm" (measured, and it is
   in the golden file's `defaults` lines). The port builds it the same way - the release's own
   NSDateFormatter set from the two short styles and asked for its pattern - so a locale other than
   en_US answers its own and not a constant. */
- (NSString *)dateTemplate
{
    if (_dateTemplate)
        return _dateTemplate;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = self.locale;
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return formatter.dateFormat ?: @"";
}

- (void)setDateTemplate:(NSString *)dateTemplate
{
    _dateTemplate = [dateTemplate copy];
}

- (NSDateIntervalFormatterStyle)dateStyle
{
    return _dateStyle;
}

- (void)setDateStyle:(NSDateIntervalFormatterStyle)dateStyle
{
    _dateStyle = dateStyle;
}

- (NSDateIntervalFormatterStyle)timeStyle
{
    return _timeStyle;
}

- (void)setTimeStyle:(NSDateIntervalFormatterStyle)timeStyle
{
    _timeStyle = timeStyle;
}

- (NSString *)charon_intervalFrom:(NSDate *)from to:(NSDate *)to
{
    NSString *skeleton = CharonIntervalSkeleton((NSInteger)_dateStyle, (NSInteger)_timeStyle, _dateTemplate, self.locale);
    if (!skeleton.length)
        return @"";
    /* The zone is the formatter's, in the UChar form the entry point takes; the locale is the
       formatter's locale as the NUL-terminated bytes it takes. */
    NSString *zone = self.timeZone.name ?: @"GMT";
    uint16_t skeletonChars[256], zoneChars[256];
    int32_t skeletonLength = 0, zoneLength = 0;
    for (NSUInteger index = 0; index < skeleton.length && index < 255; index++)
        skeletonChars[skeletonLength++] = (uint16_t)[skeleton characterAtIndex:index];
    for (NSUInteger index = 0; index < zone.length && index < 255; index++)
        zoneChars[zoneLength++] = (uint16_t)[zone characterAtIndex:index];

    /* A release without the four answers nil, which is what the header documents for every answer it
       cannot give. */
    if (!udtitvfmt_open || !udtitvfmt_format || !udtitvfmt_close)
        return nil;
    CharonUErrorCode status = 0;
    CharonUDateIntervalFormat formatter =
        udtitvfmt_open(self.locale.localeIdentifier.UTF8String, skeletonChars, skeletonLength,
                       zoneChars, zoneLength, &status);
    if (status != 0 || !formatter)
        return nil;
    uint16_t buffer[512];
    status = 0;
    int32_t written = udtitvfmt_format(&formatter, (CharonUDate)from.timeIntervalSinceReferenceDate,
                                       (CharonUDate)to.timeIntervalSinceReferenceDate, buffer, 512, NULL, &status);
    CharonUDateIntervalFormat closing = formatter;
    udtitvfmt_close(&closing);
    if (status != 0 || written <= 0)
        return nil;
    return [[NSString alloc] initWithCharacters:(const unichar *)buffer length:(NSUInteger)written];
}

- (NSString *)stringFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate
{
    if (!fromDate || !toDate)
        return nil;
    return [self charon_intervalFrom:fromDate to:toDate];
}

- (NSString *)stringFromDateInterval:(NSDateInterval *)dateInterval
{
    if (!dateInterval)
        return nil;
    return [self charon_intervalFrom:dateInterval.startDate to:dateInterval.endDate];
}

@end
