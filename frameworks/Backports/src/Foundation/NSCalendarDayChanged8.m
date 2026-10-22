#import <Foundation/Foundation.h>

NSNotificationName const NSCalendarDayChangedNotification = @"NSCalendarDayChangedNotification";

static const NSCalendarUnit RevenantDayUnits = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;

__attribute__((visibility("hidden")))
@interface RevenantCalendarDayMonitor : NSObject {
    NSDateComponents *_day;
    NSTimer *_timer;
}
- (void)checkAtDate:(NSDate *)date;
@end

@implementation RevenantCalendarDayMonitor

- (NSDate *)nextMidnightAfter:(NSDate *)date
{
    NSDate *start = nil;
    NSTimeInterval interval = 0;
    if (![[NSCalendar currentCalendar] rangeOfUnit:NSCalendarUnitDay startDate:&start interval:&interval forDate:date])
        return [date dateByAddingTimeInterval:86400];
    return [start dateByAddingTimeInterval:interval];
}

- (void)schedule:(NSDate *)now
{
    NSDate *fire = [self nextMidnightAfter:now];
    if ([fire timeIntervalSinceDate:now] < 0.05)
        fire = [now dateByAddingTimeInterval:0.05];
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:fire interval:0 target:self selector:@selector(timerFired:) userInfo:nil repeats:NO];
    NSTimer *previous;
    @synchronized (self) {
        previous = _timer;
        _timer = timer;
    }
    [previous invalidate];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)timerFired:(NSTimer *)timer
{
    [self checkAtDate:[NSDate date]];
}

- (void)checkAtDate:(NSDate *)date
{
    NSDateComponents *today = [[NSCalendar currentCalendar] components:RevenantDayUnits fromDate:date];
    BOOL changed = NO;
    @synchronized (self) {
        if (!_day) {
            _day = today;
        } else if (![_day isEqual:today]) {
            _day = today;
            changed = YES;
        }
    }
    if (changed)
        [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:nil];
    [self schedule:date];
}

- (void)start
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    for (NSString *name in @[@"UIApplicationSignificantTimeChangeNotification", NSSystemClockDidChangeNotification, NSSystemTimeZoneDidChangeNotification, NSCurrentLocaleDidChangeNotification])
        [center addObserver:self selector:@selector(timeChanged:) name:name object:nil];
    [self checkAtDate:[NSDate date]];
}

- (void)timeChanged:(NSNotification *)notification
{
    [self checkAtDate:[NSDate date]];
}

@end

static RevenantCalendarDayMonitor *revenant_calendar_day_monitor(void)
{
    static RevenantCalendarDayMonitor *monitor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        monitor = [[RevenantCalendarDayMonitor alloc] init];
        [monitor start];
    });
    return monitor;
}

void revenant_calendar_day_check(NSDate *date);

void revenant_calendar_day_check(NSDate *date)
{
    [revenant_calendar_day_monitor() checkAtDate:date];
}

__attribute__((constructor)) static void revenant_calendar_day_start(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        revenant_calendar_day_monitor();
    });
}
