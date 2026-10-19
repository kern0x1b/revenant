#import <UIKit/UIKit.h>
#include <stdio.h>
#include "RevenantCalendar.h"

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *components_text(NSDateComponents *c)
{
    if (!c)
        return @"nil";
    NSString *day = c.day == NSUndefinedDateComponent ? @"undefined" : [NSString stringWithFormat:@"%ld", (long)c.day];
    return [NSString stringWithFormat:@"%ld/%ld/%@", (long)c.year, (long)c.month, day];
}

static NSDateComponents *month(NSInteger year, NSInteger monthNumber)
{
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year = year;
    c.month = monthNumber;
    return c;
}

static NSDate *utc(NSInteger year, NSInteger monthNumber, NSInteger day)
{
    NSCalendar *g = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    g.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year = year;
    c.month = monthNumber;
    c.day = day;
    return [g dateFromComponents:c];
}

static NSString *raised(void (^call)(void))
{
    @try {
        call();
        return @"no raise";
    } @catch (NSException *e) {
        return e.reason ?: @"raised";
    }
}

@interface RevenantCalendarProbeDelegate : NSObject <UICalendarViewDelegate>
@property (nonatomic) NSInteger decorationCalls;
@end

@implementation RevenantCalendarProbeDelegate
- (UICalendarViewDecoration *)calendarView:(UICalendarView *)view decorationForDateComponents:(NSDateComponents *)components
{
    self.decorationCalls++;
    return nil;
}
@end

static void run(const char *side, Class cls)
{
    report(side, "view-superclass", NSStringFromClass([cls superclass]));

    id view = [[cls alloc] initWithFrame:CGRectMake(0, 0, 280, 304)];
    report(side, "default-delegate-nil", [view delegate] ? @"set" : @"nil");
    report(side, "default-selection-nil", [view selectionBehavior] ? @"set" : @"nil");
    report(side, "default-wants-decorations", yes_no([view wantsDateDecorations]));
    report(side, "default-locale", [[view locale] localeIdentifier]);
    report(side, "default-calendar", [[view calendar] calendarIdentifier]);
    report(side, "default-time-zone-nil", [view timeZone] ? @"set" : @"nil");
    report(side, "default-font-design", [view fontDesign]);
    NSDateInterval *range = [view availableDateRange];
    report(side, "default-range-start", [NSString stringWithFormat:@"%.0f", [range.startDate timeIntervalSinceReferenceDate]]);
    report(side, "default-range-end", [NSString stringWithFormat:@"%.0f", [range.endDate timeIntervalSinceReferenceDate]]);
    report(side, "default-visible-day-undefined", yes_no([[view visibleDateComponents] day] == NSUndefinedDateComponent));

    [view setVisibleDateComponents:month(2024, 5) animated:NO];
    report(side, "set-visible-month", components_text([view visibleDateComponents]));
    NSDateComponents *given = month(2024, 6);
    [view setVisibleDateComponents:given animated:NO];
    given.month = 9;
    report(side, "set-visible-copied-from-argument", components_text([view visibleDateComponents]));
    [view setVisibleDateComponents:month(2025, 2) animated:NO];
    report(side, "set-visible-month-only", components_text([view visibleDateComponents]));
    NSDateComponents *dayOnly = [[NSDateComponents alloc] init];
    dayOnly.day = 3;
    [view setVisibleDateComponents:dayOnly animated:NO];
    report(side, "set-visible-day-only-reads-year-and-month-as-one", components_text([view visibleDateComponents]));
    [view setVisibleDateComponents:month(1800, 1) animated:NO];
    report(side, "set-visible-1800", components_text([view visibleDateComponents]));
    report(side, "set-visible-outside-range", raised(^{ [view setVisibleDateComponents:month(5000, 1) animated:NO]; }));
    report(side, "set-visible-nil", raised(^{ [view setVisibleDateComponents:nil animated:NO]; }));

    [view setVisibleDateComponents:month(2024, 5) animated:NO];
    [view setAvailableDateRange:[[NSDateInterval alloc] initWithStartDate:utc(1970, 1, 1) duration:86400 * 10]];
    report(side, "range-moves-visible-to-its-month", components_text([view visibleDateComponents]));
    report(side, "range-set-visible-after-end", raised(^{ [view setVisibleDateComponents:month(1970, 2) animated:NO]; }));
    report(side, "range-set-visible-inside", raised(^{ [view setVisibleDateComponents:month(1970, 1) animated:NO]; }));
    report(side, "range-nil", raised(^{ [view setAvailableDateRange:nil]; }));

    id clamped = [[cls alloc] initWithFrame:CGRectMake(0, 0, 280, 304)];
    [clamped setAvailableDateRange:[[NSDateInterval alloc] initWithStartDate:utc(2000, 6, 15) endDate:utc(2001, 3, 20)]];
    [clamped setAvailableDateRange:[[NSDateInterval alloc] initWithStartDate:utc(1990, 1, 1) endDate:utc(1995, 2, 1)]];
    report(side, "range-clamps-to-nearer-end", components_text([clamped visibleDateComponents]));

    id props = [[cls alloc] initWithFrame:CGRectMake(0, 0, 280, 304)];
    report(side, "nil-calendar", raised(^{ [props setCalendar:nil]; }));
    report(side, "nil-locale", raised(^{ [props setLocale:nil]; }));
    [props setCalendar:[NSCalendar calendarWithIdentifier:NSCalendarIdentifierBuddhist]];
    report(side, "set-calendar", [[props calendar] calendarIdentifier]);
    [props setTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Tokyo"]];
    report(side, "set-time-zone", [[props timeZone] name]);
    [props setTimeZone:nil];
    report(side, "clear-time-zone", [props timeZone] ? @"set" : @"nil");
    [props setFontDesign:@"NSCTFontUIFontDesignRounded"];
    report(side, "set-font-design", [props fontDesign]);
    [props setFontDesign:nil];
    report(side, "clear-font-design", [props fontDesign] ? @"set" : @"nil");
    [props setWantsDateDecorations:NO];
    report(side, "wants-decorations-off", yes_no([props wantsDateDecorations]));
    [props setLocale:[NSLocale localeWithLocaleIdentifier:@"fr_FR"]];
    report(side, "set-locale", [[props locale] localeIdentifier]);

    [props reloadDecorationsForDateComponents:@[month(2024, 5)] animated:YES];
    report(side, "reload-decorations-ok", @"yes");

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(280, 304), NO, 1);
    [props drawRect:CGRectMake(0, 0, 280, 304)];
    UIGraphicsEndImageContext();
    report(side, "drawn-without-window", @"yes");

    id moved = [[cls alloc] initWithFrame:CGRectMake(0, 0, 280, 304)];
    [moved setAvailableDateRange:[[NSDateInterval alloc] initWithStartDate:utc(1970, 1, 1) duration:86400 * 10]];
    report(side, "calendar-change-outside-range", raised(^{ [moved setCalendar:[NSCalendar calendarWithIdentifier:NSCalendarIdentifierBuddhist]]; }));
}

static void runPortOnly(void)
{
    RevenantCalendarProbeDelegate *probe = [[RevenantCalendarProbeDelegate alloc] init];
    UICalendarView *view = [[UICalendarView alloc] initWithFrame:CGRectMake(0, 0, 280, 304)];
    view.delegate = probe;
    [view setVisibleDateComponents:month(2024, 5) animated:NO];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(280, 304), NO, 1);
    [view drawRect:CGRectMake(0, 0, 280, 304)];
    UIGraphicsEndImageContext();
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *firstParts = [month(2024, 5) copy];
    firstParts.day = 1;
    NSDate *firstOfMay = [calendar dateFromComponents:firstParts];
    NSInteger expectedCalls = [calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:firstOfMay].length;
    report("only", "decoration-calls-for-each-day", yes_no(probe.decorationCalls == expectedCalls));

    NSInteger weekday = [calendar components:NSCalendarUnitWeekday fromDate:firstOfMay].weekday;
    NSInteger column = (weekday - calendar.firstWeekday + 7) % 7;
    CGPoint firstDay = CGPointMake(column * 40 + 20, 64 + 20);
    NSDateComponents *hit = [(id)view revenant_dateAtPoint:firstDay];
    report("only", "tap-first-day-of-may", [NSString stringWithFormat:@"%@", components_text(hit)]);
    report("only", "tap-first-day-is-the-first", yes_no(hit && hit.day == 1 && hit.month == 5 && hit.year == 2024));
    report("only", "tap-blank-before-first-day", yes_no(column == 0 || [(id)view revenant_dateAtPoint:CGPointMake(20, 84)] == nil));
    report("only", "tap-header-is-nothing", yes_no([(id)view revenant_dateAtPoint:CGPointMake(100, 10)] == nil));
    report("only", "tap-weekday-row-is-nothing", yes_no([(id)view revenant_dateAtPoint:CGPointMake(100, 50)] == nil));

    [view setAvailableDateRange:[[NSDateInterval alloc] initWithStartDate:utc(2024, 5, 10) endDate:utc(2024, 5, 31)]];
    report("only", "tap-day-outside-range-is-nothing", yes_no([(id)view revenant_dateAtPoint:firstDay] == nil));
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NSClassFromString(@"UICalendarView"));
        run("port", [UICalendarView class]);
        runPortOnly();
    }
    return 0;
}
