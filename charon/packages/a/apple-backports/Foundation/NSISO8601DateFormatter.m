#import <Foundation/Foundation.h>

/* CFDateFormatterCreateISO8601Formatter arrived after iOS 6, but everything it is
   built out of - CFDateFormatterCreate, CFDateFormatterSetFormat and the rest - was
   there already, so the formatter is assembled here instead. The pattern fragments
   and the locale are Apple's, read out of that function; which of them go together
   is held to the answers the real one gives for every one of the 1024 combinations
   of the options. */

/* An offset at the end of a written date, with its colon taken out or put back. */
static NSString *charon_without_offset_colon(NSString *written)
{
    NSUInteger length = written.length;
    if (length < 6)
        return written;
    NSString *tail = [written substringFromIndex:length - 6];
    unichar sign = [tail characterAtIndex:0];
    if ((sign != '+' && sign != '-') || [tail characterAtIndex:3] != ':')
        return written;
    return [[written substringToIndex:length - 6]
               stringByAppendingFormat:@"%@%@", [tail substringToIndex:3], [tail substringFromIndex:4]];
}

static NSString *charon_with_offset_colon(NSString *written)
{
    NSUInteger length = written.length;
    if (length < 5)
        return written;
    NSString *tail = [written substringFromIndex:length - 5];
    unichar sign = [tail characterAtIndex:0];
    if (sign != '+' && sign != '-')
        return written;
    for (NSUInteger index = 1; index < 5; index++)
        if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[tail characterAtIndex:index]])
            return written;
    return [[written substringToIndex:length - 5]
               stringByAppendingFormat:@"%@:%@", [tail substringToIndex:3], [tail substringFromIndex:3]];
}

static NSString *charon_iso_date_pattern(NSISO8601DateFormatOptions options)
{
    BOOL year = (options & NSISO8601DateFormatWithYear) != 0;
    BOOL month = (options & NSISO8601DateFormatWithMonth) != 0;
    /* Asked for the whole internet date and time, the formatter writes the calendar
       date and drops the week, even where the week was asked for beside it. Those
       two combinations are the only ones in all 1024 that do. */
    BOOL week = (options & NSISO8601DateFormatWithWeekOfYear) != 0
             && (options & NSISO8601DateFormatWithInternetDateTime) != NSISO8601DateFormatWithInternetDateTime;
    BOOL day = (options & NSISO8601DateFormatWithDay) != 0;
    BOOL dashes = (options & NSISO8601DateFormatWithDashSeparatorInDate) != 0;
    NSMutableArray *pieces = [[NSMutableArray alloc] init];
    if (year)
        [pieces addObject:week ? @"YYYY" : @"yyyy"];
    if (month)
        [pieces addObject:@"MM"];
    if (week)
        [pieces addObject:@"'W'ww"];
    if (day)
        [pieces addObject:week ? @"ee" : (month ? @"dd" : @"DDD")];
    return [pieces componentsJoinedByString:dashes ? @"-" : @""];
}

/* The letter X, which writes an offset and a plain Z at Greenwich, is younger than
   the oldest release this is built for: an ICU that does not know it writes nothing
   at all where the zone should be. ZZZZZ says the same thing in the extended shape
   there - Z at Greenwich, +09:00 elsewhere - so that is used instead, and the colon
   is taken out again where the basic shape was asked for. */
static BOOL charon_icu_writes_offsets(void)
{
    static BOOL known;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CFLocaleRef locale = CFLocaleCreate(kCFAllocatorSystemDefault, CFSTR("en_GB_POSIX"));
        CFDateFormatterRef probe = CFDateFormatterCreate(kCFAllocatorSystemDefault, locale,
                                                         kCFDateFormatterNoStyle, kCFDateFormatterNoStyle);
        if (locale)
            CFRelease(locale);
        CFDateFormatterSetFormat(probe, CFSTR("XXXXX"));
        CFDateRef when = CFDateCreate(kCFAllocatorSystemDefault, 0);
        CFStringRef written = CFDateFormatterCreateStringWithDate(kCFAllocatorSystemDefault, probe, when);
        known = written && CFStringGetLength(written) > 0;
        if (written)
            CFRelease(written);
        CFRelease(when);
        CFRelease(probe);
    });
    return known;
}

static NSString *charon_iso_time_pattern(NSISO8601DateFormatOptions options)
{
    NSMutableString *pattern = [[NSMutableString alloc] init];
    if (options & NSISO8601DateFormatWithTime) {
        [pattern appendString:(options & NSISO8601DateFormatWithColonSeparatorInTime) ? @"HH:mm:ss" : @"HHmmss"];
        if (options & NSISO8601DateFormatWithFractionalSeconds)
            [pattern appendString:@".SSS"];
    }
    if (options & NSISO8601DateFormatWithTimeZone) {
        if (charon_icu_writes_offsets())
            [pattern appendString:(options & NSISO8601DateFormatWithColonSeparatorInTimeZone) ? @"XXXXX" : @"XXXX"];
        else
            [pattern appendString:@"ZZZZZ"];
    }
    return pattern;
}

NSString *charon_iso8601_pattern(NSISO8601DateFormatOptions options)
{
    /* One option alone asks for nothing the formatter will write - not even the
       field it names - and the real one answers an empty pattern for it. */
    NSUInteger asked = 0;
    for (NSISO8601DateFormatOptions bit = 1; bit; bit <<= 1)
        if (options & bit)
            asked++;
    if (asked < 2)
        return @"";
    NSString *date = charon_iso_date_pattern(options), *time = charon_iso_time_pattern(options);
    if (!date.length)
        return time;
    if (!time.length)
        return date;
    /* The letter between the date and the time belongs to the time of day, not to
       the zone: a date followed by an offset alone runs straight on. */
    if (!(options & NSISO8601DateFormatWithTime))
        return [date stringByAppendingString:time];
    return [NSString stringWithFormat:@"%@%@%@", date,
                                      (options & NSISO8601DateFormatWithSpaceBetweenDateAndTime) ? @" " : @"'T'",
                                      time];
}

@implementation NSISO8601DateFormatter

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone
               formatOptions:(NSISO8601DateFormatOptions)formatOptions
{
    NSISO8601DateFormatter *formatter = [[self alloc] init];
    formatter.timeZone = timeZone;
    formatter.formatOptions = formatOptions;
    return [formatter stringFromDate:date];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _formatOptions = NSISO8601DateFormatWithInternetDateTime;
        _timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
        [self charon_updateFormatter];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"Encoder does not allow key encoding"];
        return nil;
    }
    if ((self = [super init])) {
        _formatOptions = (NSISO8601DateFormatOptions)[coder decodeIntegerForKey:@"NS.formatOptions"];
        if ([coder containsValueForKey:@"NS.timeZone"]) {
            _timeZone = [coder decodeObjectOfClass:[NSTimeZone class] forKey:@"NS.timeZone"];
            if (!_timeZone) {
                [coder failWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderReadCorruptError
                                                     userInfo:@{NSLocalizedDescriptionKey: @"Timezone has been corrupted!"}]];
                return nil;
            }
        } else {
            _timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
        }
        [self charon_updateFormatter];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"Encoder does not allow key encoding"];
        return;
    }
    [coder encodeInteger:(NSInteger)_formatOptions forKey:@"NS.formatOptions"];
    [coder encodeObject:_timeZone forKey:@"NS.timeZone"];
}

- (void)dealloc
{
    if (_formatter)
        CFRelease(_formatter);
}

- (void)charon_updateFormatter
{
    if (_formatter)
        CFRelease(_formatter);
    /* Apple's own formatter is built on en_US_POSIX with a gregorian calendar whose
       week starts on Monday and whose first week is the one with four days in it -
       the ISO 8601 rule. Core Foundation will not take that calendar from
       CFDateFormatterSetProperty: it reads straight back as Sunday with one day, so
       the rule has to come from the locale. Asking for the ISO calendar by name
       brings the rule but changes what a pattern without a date parses to - the year
       comes back as 12000 - so what is used is the POSIX-invariant locale whose own
       week rule is already the ISO one. Every pattern here is numeric, so nothing
       else of a locale shows through, and all 1024 of them are held to the real
       formatter's answers. */
    CFLocaleRef locale = CFLocaleCreate(kCFAllocatorSystemDefault, CFSTR("en_GB_POSIX"));
    _formatter = CFDateFormatterCreate(kCFAllocatorSystemDefault, locale,
                                       kCFDateFormatterNoStyle, kCFDateFormatterNoStyle);
    if (locale)
        CFRelease(locale);
    CFDateFormatterSetFormat(_formatter, (__bridge CFStringRef)charon_iso8601_pattern(_formatOptions));
    CFDateFormatterSetProperty(_formatter, kCFDateFormatterTimeZone, (__bridge CFTypeRef)_timeZone);
}

- (NSISO8601DateFormatOptions)formatOptions
{
    return _formatOptions;
}

- (void)setFormatOptions:(NSISO8601DateFormatOptions)formatOptions
{
    NSAssert(formatOptions == 0 || !(formatOptions & ~(NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth
             | NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithTime
             | NSISO8601DateFormatWithTimeZone | NSISO8601DateFormatWithSpaceBetweenDateAndTime
             | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime
             | NSISO8601DateFormatWithColonSeparatorInTimeZone | NSISO8601DateFormatWithFractionalSeconds
             | NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithFullTime | NSISO8601DateFormatWithInternetDateTime)),
             @"Invalid parameter not satisfying: %@",
             @"formatOptions == 0 || !(formatOptions & ~(NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth"
             @" | NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithTime"
             @" | NSISO8601DateFormatWithTimeZone | NSISO8601DateFormatWithSpaceBetweenDateAndTime"
             @" | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime"
             @" | NSISO8601DateFormatWithColonSeparatorInTimeZone | NSISO8601DateFormatWithFractionalSeconds"
             @" | NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithFullTime | NSISO8601DateFormatWithInternetDateTime))");
    _formatOptions = formatOptions;
    [self charon_updateFormatter];
}

- (NSTimeZone *)timeZone
{
    return _timeZone;
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    if ([_timeZone isEqualToTimeZone:timeZone])
        return;
    _timeZone = timeZone ? [timeZone copy] : [NSTimeZone timeZoneWithName:@"GMT"];
    [self charon_updateFormatter];
}

- (NSString *)stringFromDate:(NSDate *)date
{
    return [self stringForObjectValue:date];
}

- (NSString *)stringForObjectValue:(id)object
{
    if (![object isKindOfClass:[NSDate class]])
        return nil;
    CFStringRef made = CFDateFormatterCreateStringWithDate(kCFAllocatorSystemDefault, _formatter,
                                                          (__bridge CFDateRef)object);
    if (!made)
        return nil;
    NSString *written = (__bridge_transfer NSString *)made;
    return [self charon_basicZoneWanted] ? charon_without_offset_colon(written) : written;
}

/* Whether the offset this formatter writes has to lose its colon again. */
- (BOOL)charon_basicZoneWanted
{
    return (_formatOptions & NSISO8601DateFormatWithTimeZone)
        && !(_formatOptions & NSISO8601DateFormatWithColonSeparatorInTimeZone)
        && !charon_icu_writes_offsets();
}

- (NSDate *)dateFromString:(NSString *)string
{
    NSDate *date = nil;
    return [self getObjectValue:&date forString:string range:NULL error:NULL] ? date : nil;
}

- (BOOL)getObjectValue:(out id *)object forString:(NSString *)string range:(inout NSRange *)range error:(out NSError **)error
{
    if (!string.length || [string isEqual:@""]) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFormattingError
                                     userInfo:@{NSLocalizedDescriptionKey: @"The value is not a valid ISO 8601 date."}];
        return NO;
    }
    NSString *text = [self charon_basicZoneWanted] ? charon_with_offset_colon(string) : string;
    CFAbsoluteTime when = 0;
    CFRange whole = CFRangeMake(0, (CFIndex)text.length);
    NSDate *date = CFDateFormatterGetAbsoluteTimeFromString(_formatter, (__bridge CFStringRef)text, &whole, &when)
                 ? [NSDate dateWithTimeIntervalSinceReferenceDate:when] : nil;
    if (!date) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFormattingError
                                     userInfo:@{NSLocalizedDescriptionKey: @"The value is not a valid ISO 8601 date."}];
        return NO;
    }
    if (object)
        *object = date;
    if (range)
        *range = NSMakeRange(0, string.length);
    return YES;
}

- (BOOL)getObjectValue:(out id *)object forString:(NSString *)string errorDescription:(out NSString **)errorDescription
{
    NSError *failure = nil;
    if ([self getObjectValue:object forString:string range:NULL error:&failure])
        return YES;
    if (errorDescription)
        *errorDescription = failure.localizedDescription;
    return NO;
}

@end
