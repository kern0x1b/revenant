#import <Foundation/Foundation.h>
#include <stdint.h>

typedef double RevenantUDate;
typedef void *RevenantUDateIntervalFormat;
typedef int32_t RevenantUErrorCode;

extern __attribute__((weak_import)) RevenantUDateIntervalFormat
    udtitvfmt_open(const char *locale, const uint16_t *skeleton, int32_t skeletonLength,
                   const uint16_t *tzID, int32_t tzIDLength, RevenantUErrorCode *status);
extern __attribute__((weak_import)) void udtitvfmt_close(RevenantUDateIntervalFormat *formatter);
extern __attribute__((weak_import)) int32_t
    udtitvfmt_format(const RevenantUDateIntervalFormat *formatter, RevenantUDate fromDate, RevenantUDate toDate,
                     uint16_t *result, int32_t resultCapacity, void *position, RevenantUErrorCode *status);

static NSString *RevenantDateSkeleton(NSInteger style)
{
    switch (style) {
        case 1: return @"yMd";
        case 2: return @"yMMMd";
        case 3: return @"yMMMMd";
        case 4: return @"yMMMMdE";
        default: return @"";
    }
}

static NSString *RevenantTimeSkeleton(NSInteger style)
{
    switch (style) {
        case 1: return @"jm";
        case 2: return @"jmms";
        case 3: return @"jmmsz";
        case 4: return @"jmmszzzz";
        default: return @"";
    }
}

static NSString *RevenantPatternSkeleton(NSString *pattern)
{
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
            continue;
        if ([letter isEqualToString:@"h"] || [letter isEqualToString:@"K"] || [letter isEqualToString:@"k"])
            continue;
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

static NSString *RevenantIntervalSkeleton(NSInteger dateStyle, NSInteger timeStyle, NSString *template, NSLocale *locale)
{
    if (template.length)
        return RevenantPatternSkeleton([NSDateFormatter dateFormatFromTemplate:template options:0 locale:locale]);
    return [RevenantDateSkeleton(dateStyle) stringByAppendingString:RevenantTimeSkeleton(timeStyle)];
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

- (NSString *)revenant_intervalFrom:(NSDate *)from to:(NSDate *)to
{
    NSString *skeleton = RevenantIntervalSkeleton((NSInteger)_dateStyle, (NSInteger)_timeStyle, _dateTemplate, self.locale);
    if (!skeleton.length)
        return @"";
    NSString *zone = self.timeZone.name ?: @"GMT";
    uint16_t skeletonChars[256], zoneChars[256];
    int32_t skeletonLength = 0, zoneLength = 0;
    for (NSUInteger index = 0; index < skeleton.length && index < 255; index++)
        skeletonChars[skeletonLength++] = (uint16_t)[skeleton characterAtIndex:index];
    for (NSUInteger index = 0; index < zone.length && index < 255; index++)
        zoneChars[zoneLength++] = (uint16_t)[zone characterAtIndex:index];

    if (!udtitvfmt_open || !udtitvfmt_format || !udtitvfmt_close)
        return nil;
    RevenantUErrorCode status = 0;
    RevenantUDateIntervalFormat formatter =
        udtitvfmt_open(self.locale.localeIdentifier.UTF8String, skeletonChars, skeletonLength,
                       zoneChars, zoneLength, &status);
    if (status != 0 || !formatter)
        return nil;
    uint16_t buffer[512];
    status = 0;
    int32_t written = udtitvfmt_format(&formatter, (RevenantUDate)from.timeIntervalSinceReferenceDate,
                                       (RevenantUDate)to.timeIntervalSinceReferenceDate, buffer, 512, NULL, &status);
    RevenantUDateIntervalFormat closing = formatter;
    udtitvfmt_close(&closing);
    if (status != 0 || written <= 0)
        return nil;
    return [[NSString alloc] initWithCharacters:(const unichar *)buffer length:(NSUInteger)written];
}

- (NSString *)stringFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate
{
    if (!fromDate || !toDate)
        return nil;
    return [self revenant_intervalFrom:fromDate to:toDate];
}

- (NSString *)stringFromDateInterval:(NSDateInterval *)dateInterval
{
    if (!dateInterval)
        return nil;
    return [self revenant_intervalFrom:dateInterval.startDate to:dateInterval.endDate];
}

@end
