#import "check.h"

void revenant_calendar_day_check(NSDate *date);

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    __block int posted = 0;
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        posted++;
    }];
    revenant_expect_string("the notification has its documented name", NSCalendarDayChangedNotification, @"NSCalendarDayChangedNotification");
    NSDate *now = [NSDate date];
    revenant_calendar_day_check(now);
    revenant_calendar_day_check(now);
    revenant_check(posted == 0, "a check within the same day posts nothing", [NSString stringWithFormat:@"%d", posted]);
    NSDate *later = [now dateByAddingTimeInterval:2 * 86400];
    revenant_calendar_day_check(later);
    revenant_check(posted == (revenant_negative ? 2 : 1), "a check on another day posts once", [NSString stringWithFormat:@"%d", posted]);
    revenant_calendar_day_check(later);
    revenant_check(posted == 1, "a second check on that day posts nothing more", [NSString stringWithFormat:@"%d", posted]);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UIApplicationSignificantTimeChangeNotification" object:nil];
    revenant_check(posted == 2, "a significant time change back to the real day posts again", [NSString stringWithFormat:@"%d", posted]);
    return revenant_finish();
}
