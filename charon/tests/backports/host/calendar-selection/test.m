#import <UIKit/UIKit.h>
#include <stdio.h>
#include "CharonCalendar.h"

typedef id (*PlainFn)(id, SEL);

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSDateComponents *day(NSInteger year, NSInteger monthNumber, NSInteger dayNumber)
{
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year = year;
    c.month = monthNumber;
    c.day = dayNumber;
    return c;
}

static NSString *day_text(NSDateComponents *c)
{
    if (!c)
        return @"nil";
    return [NSString stringWithFormat:@"%ld/%ld/%ld", (long)c.year, (long)c.month, (long)c.day];
}

@interface CharonSingleProbe : NSObject <UICalendarSelectionSingleDateDelegate>
@property (nonatomic) NSInteger selectedCalls;
@property (nonatomic) NSInteger refusedDay;
@end

@implementation CharonSingleProbe
- (void)dateSelection:(UICalendarSelectionSingleDate *)selection didSelectDate:(NSDateComponents *)dateComponents
{
    self.selectedCalls++;
}

- (BOOL)dateSelection:(UICalendarSelectionSingleDate *)selection canSelectDate:(NSDateComponents *)dateComponents
{
    return dateComponents.day != self.refusedDay;
}
@end

static id plain_init(id object)
{
    SEL initSelector = @selector(init);
    return ((PlainFn)[object methodForSelector:initSelector])(object, initSelector);
}

static void run(const char *side, Class baseClass, Class singleClass)
{
    report(side, "base-superclass", NSStringFromClass([baseClass superclass]));
    report(side, "base-made", plain_init([baseClass alloc]) ? @"yes" : @"no");
    id base = plain_init([baseClass alloc]);
    [base updateSelectableDates];
    report(side, "base-update-without-view", @"yes");

    report(side, "single-superclass-is-base", yes_no([singleClass superclass] == baseClass));
    CharonSingleProbe *probe = [[CharonSingleProbe alloc] init];
    id single = [[singleClass alloc] initWithDelegate:probe];
    report(side, "single-delegate-reads-back", [single delegate] == probe ? @"yes" : @"no");
    report(side, "single-default-selected", [single selectedDate] ? @"set" : @"nil");

    NSDateComponents *mutable = day(2024, 5, 6);
    [single setSelectedDate:mutable];
    mutable.day = 9;
    report(side, "single-set-copies-argument", day_text([single selectedDate]));
    report(side, "single-set-not-same-object", yes_no([single selectedDate] != mutable));
    [single setSelectedDate:day(2024, 5, 12) animated:YES];
    report(side, "single-set-animated", day_text([single selectedDate]));
    [single setSelectedDate:nil];
    report(side, "single-clear", [single selectedDate] ? @"set" : @"nil");

    report(side, "single-set-calls-no-delegate", yes_no(probe.selectedCalls == 0));
    [single updateSelectableDates];
    report(side, "single-update-calls-no-delegate", yes_no(probe.selectedCalls == 0));
    report(side, "single-setDelegate-absent", [singleClass instancesRespondToSelector:NSSelectorFromString(@"setDelegate:")] ? @"no" : @"yes");
    report(side, "single-copy-absent", [singleClass instancesRespondToSelector:@selector(copyWithZone:)] ? @"no" : @"yes");
}

static void runPortOnly(void)
{
    CharonSingleProbe *probe = [[CharonSingleProbe alloc] init];
    probe.refusedDay = 7;
    UICalendarSelectionSingleDate *single = [[UICalendarSelectionSingleDate alloc] initWithDelegate:probe];

    [single charon_didTapDay:day(2024, 5, 6)];
    report("only", "tap-chooses-allowed-day", yes_no([single selectedDate].day == 6 && probe.selectedCalls == 1));
    report("only", "tap-same-day-changes-nothing", yes_no(^{
        [single charon_didTapDay:day(2024, 5, 6)];
        return [single selectedDate].day == 6 && probe.selectedCalls == 1;
    }()));
    report("only", "tap-refused-day-changes-nothing", yes_no(^{
        [single charon_didTapDay:day(2024, 5, 7)];
        return [single selectedDate].day == 6 && probe.selectedCalls == 1;
    }()));
    report("only", "is-selected-the-chosen-day", yes_no([single charon_isSelected:day(2024, 5, 6)] && ![single charon_isSelected:day(2024, 5, 8)]));
    report("only", "tap-without-delegate-chooses", yes_no(^{
        UICalendarSelectionSingleDate *bare = [[UICalendarSelectionSingleDate alloc] initWithDelegate:nil];
        [bare charon_didTapDay:day(2024, 5, 20)];
        return [bare selectedDate].day == 20;
    }()));
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NSClassFromString(@"UICalendarSelection"), NSClassFromString(@"UICalendarSelectionSingleDate"));
        run("port", [UICalendarSelection class], [UICalendarSelectionSingleDate class]);
        runPortOnly();
    }
    return 0;
}
