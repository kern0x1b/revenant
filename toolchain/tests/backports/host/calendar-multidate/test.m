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

static NSString *days_text(NSArray *days)
{
    if (!days)
        return @"nil";
    NSMutableArray *parts = [NSMutableArray array];
    for (NSDateComponents *c in days)
        [parts addObject:[NSString stringWithFormat:@"%ld", (long)c.day]];
    return [parts componentsJoinedByString:@","];
}

@interface CharonMultiProbe : NSObject <UICalendarSelectionMultiDateDelegate>
@property (nonatomic) NSInteger selectedCalls;
@property (nonatomic) NSInteger deselectedCalls;
@property (nonatomic) NSInteger refusedSelectDay;
@property (nonatomic) NSInteger refusedDeselectDay;
@end

@implementation CharonMultiProbe
- (void)multiDateSelection:(UICalendarSelectionMultiDate *)selection didSelectDate:(NSDateComponents *)dateComponents
{
    self.selectedCalls++;
}

- (void)multiDateSelection:(UICalendarSelectionMultiDate *)selection didDeselectDate:(NSDateComponents *)dateComponents
{
    self.deselectedCalls++;
}

- (BOOL)multiDateSelection:(UICalendarSelectionMultiDate *)selection canSelectDate:(NSDateComponents *)dateComponents
{
    return dateComponents.day != self.refusedSelectDay;
}

- (BOOL)multiDateSelection:(UICalendarSelectionMultiDate *)selection canDeselectDate:(NSDateComponents *)dateComponents
{
    return dateComponents.day != self.refusedDeselectDay;
}
@end

static id plain_init(id object)
{
    SEL initSelector = @selector(init);
    return ((PlainFn)[object methodForSelector:initSelector])(object, initSelector);
}

static void run(const char *side, Class baseClass, Class multiClass)
{
    report(side, "multi-superclass-is-base", yes_no([multiClass superclass] == baseClass));
    CharonMultiProbe *probe = [[CharonMultiProbe alloc] init];
    id multi = [[multiClass alloc] initWithDelegate:probe];
    report(side, "multi-delegate-reads-back", [multi delegate] == probe ? @"yes" : @"no");
    report(side, "multi-default-count", [NSString stringWithFormat:@"%lu", (unsigned long)[[multi selectedDates] count]]);

    NSMutableArray *given = [NSMutableArray arrayWithObject:day(2024, 5, 6)];
    [multi setSelectedDates:given];
    [given addObject:day(2024, 5, 9)];
    report(side, "multi-set-copies-argument", [NSString stringWithFormat:@"%lu", (unsigned long)[[multi selectedDates] count]]);
    report(side, "multi-set-keeps-element-object", yes_no([[multi selectedDates] firstObject] == [given firstObject]));
    [multi setSelectedDates:@[day(2024, 5, 6), day(2024, 5, 12)] animated:YES];
    report(side, "multi-set-animated", days_text([multi selectedDates]));
    [multi setSelectedDates:nil];
    report(side, "multi-clear", [multi selectedDates] ? @"set" : @"nil");

    report(side, "multi-set-calls-no-delegate", yes_no(probe.selectedCalls == 0 && probe.deselectedCalls == 0));
    [multi updateSelectableDates];
    report(side, "multi-update-calls-no-delegate", yes_no(probe.selectedCalls == 0 && probe.deselectedCalls == 0));
    report(side, "multi-setDelegate-absent", [multiClass instancesRespondToSelector:NSSelectorFromString(@"setDelegate:")] ? @"no" : @"yes");
    report(side, "multi-copy-absent", [multiClass instancesRespondToSelector:@selector(copyWithZone:)] ? @"no" : @"yes");
    report(side, "multi-plain-init-selected", [plain_init([multiClass alloc]) selectedDates] ? @"set" : @"nil");
}

static void runPortOnly(void)
{
    CharonMultiProbe *probe = [[CharonMultiProbe alloc] init];
    probe.refusedSelectDay = 7;
    UICalendarSelectionMultiDate *multi = [[UICalendarSelectionMultiDate alloc] initWithDelegate:probe];

    [multi charon_didTapDay:day(2024, 5, 6)];
    report("only", "tap-adds-allowed-day", yes_no([multi selectedDates].count == 1 && probe.selectedCalls == 1));
    [multi charon_didTapDay:day(2024, 5, 8)];
    report("only", "tap-keeps-order-of-days", yes_no([days_text([multi selectedDates]) isEqualToString:@"6,8"]));
    [multi charon_didTapDay:day(2024, 5, 7)];
    report("only", "tap-refused-day-not-added", yes_no([multi selectedDates].count == 2 && probe.selectedCalls == 2));
    report("only", "is-selected-the-chosen-days", yes_no([multi charon_isSelected:day(2024, 5, 8)] && ![multi charon_isSelected:day(2024, 5, 7)]));

    [multi charon_didTapDay:day(2024, 5, 6)];
    report("only", "tap-takes-chosen-day-out", yes_no([days_text([multi selectedDates]) isEqualToString:@"8"] && probe.deselectedCalls == 1));

    probe.refusedDeselectDay = 8;
    [multi charon_didTapDay:day(2024, 5, 8)];
    report("only", "refused-deselect-keeps-day", yes_no([multi selectedDates].count == 1 && probe.deselectedCalls == 1));

    UICalendarSelectionMultiDate *bare = [[UICalendarSelectionMultiDate alloc] initWithDelegate:nil];
    [bare charon_didTapDay:day(2024, 5, 20)];
    report("only", "tap-without-delegate-adds", yes_no([bare selectedDates].count == 1));
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NSClassFromString(@"UICalendarSelection"), NSClassFromString(@"UICalendarSelectionMultiDate"));
        run("port", [UICalendarSelection class], [UICalendarSelectionMultiDate class]);
        runPortOnly();
    }
    return 0;
}
