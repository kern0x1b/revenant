#import <Foundation/Foundation.h>

#define RELATIVE_CASE_COUNT 1600

static uint64_t relative_mix(uint64_t value)
{
    value += 0x9E3779B97F4A7C15ull;
    value = (value ^ (value >> 30)) * 0xBF58476D1CE4E5B9ull;
    value = (value ^ (value >> 27)) * 0x94D049BB133111EBull;
    return value ^ (value >> 31);
}

static uint32_t relative_draw(uint64_t *state)
{
    *state = relative_mix(*state);
    return (uint32_t)(*state >> 20);
}

static NSString *relative_answer(NSRelativeDateTimeFormatter *formatter, size_t index)
{
    uint64_t state = index * 7919 + 1;
    NSArray *zones = @[@"UTC", @"America/New_York", @"Asia/Kolkata", @"Pacific/Auckland", @"Europe/Berlin"];
    formatter.dateTimeStyle = (NSRelativeDateTimeFormatterStyle)(relative_draw(&state) % 2);
    formatter.unitsStyle = (NSRelativeDateTimeFormatterUnitsStyle)(relative_draw(&state) % 4);
    formatter.formattingContext = (NSFormattingContext)(relative_draw(&state) % 6);
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:@"gregorian"];
    calendar.timeZone = [NSTimeZone timeZoneWithName:zones[relative_draw(&state) % zones.count]];
    formatter.calendar = calendar;
    if (index % 5 == 4) {
        NSDateComponents *components = [[NSDateComponents alloc] init];
        for (int field = 0; field < 7; field++) {
            if (relative_draw(&state) % 3 == 0)
                continue;
            NSInteger value = relative_draw(&state) % 4 == 0 ? 0 : (NSInteger)(relative_draw(&state) % 50) - 25;
            switch (field) {
            case 0: components.year = value; break;
            case 1: components.month = value; break;
            case 2: components.weekOfMonth = value; break;
            case 3: components.day = value; break;
            case 4: components.hour = value; break;
            case 5: components.minute = value; break;
            default: components.second = value; break;
            }
        }
        return [formatter localizedStringFromDateComponents:components] ?: @"(nil)";
    }
    NSDate *reference = [NSDate dateWithTimeIntervalSinceReferenceDate:(double)(relative_draw(&state) % 1100000000) - 100000000 + (relative_draw(&state) % 4 ? 0 : (relative_draw(&state) % 1000) / 1000.0)];
    double span;
    switch (relative_draw(&state) % 8) {
    case 0: span = relative_draw(&state) % 200; break;
    case 1: span = (relative_draw(&state) % 300) * 60 + relative_draw(&state) % 60; break;
    case 2: span = (relative_draw(&state) % 100) * 3600 + relative_draw(&state) % 3600; break;
    case 3: span = (relative_draw(&state) % 40) * 86400 + relative_draw(&state) % 86400; break;
    case 4: span = (relative_draw(&state) % 400) * 86400 + relative_draw(&state) % 86400; break;
    case 5: span = (double)(relative_draw(&state) % 60) * 31536000 + relative_draw(&state) % 31536000; break;
    case 6: span = (relative_draw(&state) % 90000) / 4.0 + (relative_draw(&state) % 1000) / 1000.0; break;
    default: span = (double)(relative_draw(&state) % 8) * 86400 + (relative_draw(&state) % 3 ? 0 : relative_draw(&state) % 120); break;
    }
    if (relative_draw(&state) % 2)
        span = -span;
    return [formatter localizedStringForDate:[reference dateByAddingTimeInterval:span] relativeToDate:reference] ?: @"(nil)";
}
