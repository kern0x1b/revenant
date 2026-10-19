#import <Foundation/Foundation.h>
#include <dlfcn.h>

typedef void CharonICUCalendar;

enum {
    CharonICUWeekday = 0,
    CharonICUWeekend = 1,
    CharonICUWeekendOnset = 2,
    CharonICUWeekendCease = 3
};

typedef struct {
    CharonICUCalendar *(*open)(const unichar *zoneID, int32_t length, const char *locale, int32_t type, int32_t *status);
    void (*close)(CharonICUCalendar *calendar);
    unsigned char (*isWeekend)(const CharonICUCalendar *calendar, double date, int32_t *status);
    int32_t (*dayOfWeekType)(const CharonICUCalendar *calendar, int32_t dayOfWeek, int32_t *status);
    int32_t (*weekendTransition)(const CharonICUCalendar *calendar, int32_t dayOfWeek, int32_t *status);
} CharonICU;

static const CharonICU *charon_icu(void)
{
    static CharonICU functions;
    static BOOL loaded;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *library = dlopen("/usr/lib/libicucore.dylib", RTLD_LAZY);
        if (!library)
            library = RTLD_DEFAULT;
        functions.open = dlsym(library, "ucal_open");
        functions.close = dlsym(library, "ucal_close");
        functions.isWeekend = dlsym(library, "ucal_isWeekend");
        functions.dayOfWeekType = dlsym(library, "ucal_getDayOfWeekType");
        functions.weekendTransition = dlsym(library, "ucal_getWeekendTransition");
        loaded = functions.open && functions.close && functions.isWeekend && functions.dayOfWeekType && functions.weekendTransition;
        if (!loaded)
            NSLog(@"the weekend of a calendar is unknown because %s exports no ucal_isWeekend", library == RTLD_DEFAULT ? "this process" : "/usr/lib/libicucore.dylib");
    });
    return loaded ? &functions : NULL;
}

static CharonICUCalendar *charon_icu_calendar(NSCalendar *calendar, const CharonICU *icu)
{
    NSString *zone = calendar.timeZone.name;
    NSString *locale = calendar.locale.localeIdentifier;
    locale = locale.length ? [NSString stringWithFormat:@"%@@calendar=%@", locale, calendar.calendarIdentifier] : [NSString stringWithFormat:@"@calendar=%@", calendar.calendarIdentifier];
    NSUInteger length = zone.length;
    unichar *characters = malloc((length ? length : 1) * sizeof(unichar));
    [zone getCharacters:characters range:NSMakeRange(0, length)];
    int32_t status = 0;
    CharonICUCalendar *opened = icu->open(characters, (int32_t)length, locale.UTF8String, 0, &status);
    free(characters);
    if (status > 0) {
        icu->close(opened);
        return NULL;
    }
    return opened;
}

static int32_t charon_day_type(const CharonICU *icu, CharonICUCalendar *opened, NSInteger weekday)
{
    int32_t status = 0;
    int32_t type = icu->dayOfWeekType(opened, (int32_t)weekday, &status);
    return status > 0 ? CharonICUWeekday : type;
}

static NSTimeInterval charon_transition(const CharonICU *icu, CharonICUCalendar *opened, NSInteger weekday)
{
    int32_t status = 0;
    int32_t milliseconds = icu->weekendTransition(opened, (int32_t)weekday, &status);
    return status > 0 ? 0 : milliseconds / 1000.0;
}

static NSDate *charon_next_day(NSCalendar *calendar, NSDate *day)
{
    NSDateComponents *step = [[NSDateComponents alloc] init];
    step.day = 1;
    NSDate *start = nil;
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&start interval:NULL forDate:[calendar dateByAddingComponents:step toDate:day options:0]];
    return start;
}

static BOOL charon_weekend_range(NSCalendar *calendar, NSDate *date, NSDate **startDate, NSTimeInterval *interval)
{
    const CharonICU *icu = charon_icu();
    if (!icu)
        return NO;
    CharonICUCalendar *opened = charon_icu_calendar(calendar, icu);
    if (!opened)
        return NO;
    int32_t status = 0;
    BOOL weekend = icu->isWeekend(opened, date.timeIntervalSince1970 * 1000.0, &status) && status <= 0;
    if (!weekend) {
        icu->close(opened);
        return NO;
    }
    NSDate *day = nil;
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&day interval:NULL forDate:date];
    NSDate *start = day, *finish = nil;
    for (NSInteger moved = 0; moved < 8; moved++) {
        NSInteger weekday = [calendar components:NSCalendarUnitWeekday fromDate:start].weekday;
        int32_t type = charon_day_type(icu, opened, weekday);
        if (type == CharonICUWeekendOnset) {
            start = [start dateByAddingTimeInterval:charon_transition(icu, opened, weekday)];
            break;
        }
        NSDateComponents *back = [[NSDateComponents alloc] init];
        back.day = -1;
        NSDate *previousDay = nil;
        [calendar rangeOfUnit:NSCalendarUnitDay startDate:&previousDay interval:NULL forDate:[calendar dateByAddingComponents:back toDate:start options:0]];
        NSInteger previousWeekday = [calendar components:NSCalendarUnitWeekday fromDate:previousDay].weekday;
        int32_t previousType = charon_day_type(icu, opened, previousWeekday);
        if (previousType != CharonICUWeekend && previousType != CharonICUWeekendOnset)
            break;
        start = previousDay;
    }
    finish = day;
    for (NSInteger moved = 0; moved < 8; moved++) {
        NSInteger weekday = [calendar components:NSCalendarUnitWeekday fromDate:finish].weekday;
        int32_t type = charon_day_type(icu, opened, weekday);
        if (type == CharonICUWeekendCease) {
            NSTimeInterval transition = charon_transition(icu, opened, weekday);
            finish = transition >= 86400 ? charon_next_day(calendar, finish) : [finish dateByAddingTimeInterval:transition];
            break;
        }
        NSDate *nextDay = charon_next_day(calendar, finish);
        NSInteger nextWeekday = [calendar components:NSCalendarUnitWeekday fromDate:nextDay].weekday;
        int32_t nextType = charon_day_type(icu, opened, nextWeekday);
        finish = nextDay;
        if (nextType != CharonICUWeekend && nextType != CharonICUWeekendCease)
            break;
    }
    icu->close(opened);
    if (startDate)
        *startDate = start;
    if (interval)
        *interval = [finish timeIntervalSinceDate:start];
    return YES;
}

@implementation NSCalendar (CharonWeekend)

- (BOOL)isDateInWeekend:(NSDate *)date
{
    const CharonICU *icu = charon_icu();
    if (!icu)
        return NO;
    CharonICUCalendar *opened = charon_icu_calendar(self, icu);
    if (!opened)
        return NO;
    int32_t status = 0;
    BOOL weekend = icu->isWeekend(opened, date.timeIntervalSince1970 * 1000.0, &status) != 0;
    icu->close(opened);
    return status > 0 ? NO : weekend;
}

- (BOOL)rangeOfWeekendStartDate:(NSDate **)datep interval:(NSTimeInterval *)tip containingDate:(NSDate *)date
{
    return charon_weekend_range(self, date, datep, tip);
}

- (BOOL)nextWeekendStartDate:(NSDate **)datep interval:(NSTimeInterval *)tip options:(NSCalendarOptions)options afterDate:(NSDate *)date
{
    BOOL backwards = (options & NSCalendarSearchBackwards) != 0;
    NSDate *cursor = date;
    if (backwards) {
        NSDate *startOfDay = nil;
        [self rangeOfUnit:NSCalendarUnitDay startDate:&startOfDay interval:NULL forDate:date];
        cursor = [(startOfDay ? startOfDay : date) dateByAddingTimeInterval:-1];
    }
    NSDateComponents *step = [[NSDateComponents alloc] init];
    step.day = backwards ? -1 : 1;
    for (NSInteger moved = 0; moved < 40; moved++) {
        NSDate *start = nil;
        NSTimeInterval interval = 0;
        if (charon_weekend_range(self, cursor, &start, &interval)) {
            if (backwards || [start compare:date] == NSOrderedDescending) {
                if (datep)
                    *datep = start;
                if (tip)
                    *tip = interval;
                return YES;
            }
            cursor = [start dateByAddingTimeInterval:interval];
            continue;
        }
        cursor = [self dateByAddingComponents:step toDate:cursor options:0];
    }
    return NO;
}

@end
