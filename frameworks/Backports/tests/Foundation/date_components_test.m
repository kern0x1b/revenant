#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSDateComponents *components = [[NSDateComponents alloc] init];
    revenant_check([components valueForComponent:NSCalendarUnitMonth] == NSDateComponentUndefined, "an unset component reads as undefined",
                   [NSString stringWithFormat:@"%ld", (long)[components valueForComponent:NSCalendarUnitMonth]]);
    [components setValue:2015 forComponent:NSCalendarUnitYear];
    revenant_check(components.year == 2015, "setValue sets the property", [NSString stringWithFormat:@"%ld", (long)components.year]);
    NSInteger expected = revenant_negative ? 2016 : 2015;
    revenant_check([components valueForComponent:NSCalendarUnitYear] == expected, "valueForComponent reads the property",
                   [NSString stringWithFormat:@"%ld", (long)[components valueForComponent:NSCalendarUnitYear]]);
    [components setValue:3 forComponent:NSCalendarUnitQuarter];
    [components setValue:7 forComponent:NSCalendarUnitWeekdayOrdinal];
    [components setValue:500 forComponent:NSCalendarUnitNanosecond];
    revenant_check(components.quarter == 3 && components.weekdayOrdinal == 7 && components.nanosecond == 500, "each unit sets its own property",
                   [NSString stringWithFormat:@"%ld %ld %ld", (long)components.quarter, (long)components.weekdayOrdinal, (long)components.nanosecond]);
    BOOL raised = NO;
    @try {
        [components setValue:1 forComponent:NSCalendarUnitCalendar];
    } @catch (NSException *exception) {
        raised = [exception.name isEqualToString:NSInvalidArgumentException];
    }
    revenant_check(raised, "a unit the method cannot set raises NSInvalidArgumentException", @"no exception");
    return revenant_finish();
}
