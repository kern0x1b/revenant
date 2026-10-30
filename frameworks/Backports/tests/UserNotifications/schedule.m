#import <Foundation/Foundation.h>
#import "RevenantUserNotifications.h"

static int failures;

static void expect(BOOL condition, const char *what)
{
    if (!condition) {
        fprintf(stderr, "failed: %s\n", what);
        failures++;
    }
}

int main(void)
{
    @autoreleasepool {
        NSCalendar *utc = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        utc.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        NSDateComponents *nine = [[NSDateComponents alloc] init];
        nine.hour = 9;
        nine.minute = 30;
        NSDate *morning = [NSDate dateWithTimeIntervalSince1970:1767261600];
        NSDate *nextDay = [NSDate dateWithTimeIntervalSince1970:1767346200];
        expect([revenant_next_date_matching(utc, nine, morning) isEqualToDate:nextDay],
               "the next 09:30 after 10:00 on 2026-01-01 UTC is 09:30 on 2026-01-02");

        NSDate *before = [NSDate dateWithTimeIntervalSince1970:1767232800];
        NSDate *today = [NSDate dateWithTimeIntervalSince1970:1767259800];
        expect([revenant_next_date_matching(utc, nine, before) isEqualToDate:today],
               "the next 09:30 after 02:00 on 2026-01-01 UTC is 09:30 that day");

        NSDateComponents *missing = [[NSDateComponents alloc] init];
        missing.month = 2;
        missing.day = 30;
        missing.hour = 9;
        missing.minute = 30;
        NSDate *firstOfMarch = [NSDate dateWithTimeIntervalSince1970:1772357400];
        expect([revenant_next_date_matching(utc, missing, morning) isEqualToDate:firstOfMarch],
               "February 30 at 09:30 fires on 1 March 2026 at 09:30 UTC, the day after the month ends");

        UNCalendarNotificationTrigger *calendar = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:nine repeats:NO];
        expect(calendar.repeats == NO, "a calendar trigger keeps its repeats flag");

        UNTimeIntervalNotificationTrigger *interval = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:60 repeats:NO];
        expect(interval.timeInterval == 60, "an interval trigger keeps its time interval");

        if (failures > 0) {
            return 1;
        }
        printf("schedule ok\n");
    }
    return 0;
}
