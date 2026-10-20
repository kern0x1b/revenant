#import <UIKit/UIKit.h>
#import "RevenantCalendar.h"

static Protocol *revenant_singleDateSelectionDelegateProtocol(void) __attribute__((used));
static Protocol *revenant_singleDateSelectionDelegateProtocol(void)
{
    return @protocol(UICalendarSelectionSingleDateDelegate);
}

static BOOL revenant_sameDay(NSDateComponents *first, NSDateComponents *second)
{
    return first && second && first.year == second.year && first.month == second.month && first.day == second.day;
}

@implementation UICalendarSelectionSingleDate {
@private
    __weak id<UICalendarSelectionSingleDateDelegate> _delegate;
    NSDateComponents *_selectedDate;
}

- (instancetype)initWithDelegate:(id<UICalendarSelectionSingleDateDelegate>)delegate
{
    if ((self = [self revenant_init])) {
        _delegate = delegate;
    }
    return self;
}

- (id<UICalendarSelectionSingleDateDelegate>)delegate
{
    return _delegate;
}

- (NSDateComponents *)selectedDate
{
    return [_selectedDate copy];
}

- (void)setSelectedDate:(NSDateComponents *)selectedDate
{
    _selectedDate = [selectedDate copy];
    [self revenant_redraw];
}

- (void)setSelectedDate:(NSDateComponents *)selectedDate animated:(BOOL)animated
{
    [self setSelectedDate:selectedDate];
}

- (BOOL)revenant_isSelected:(NSDateComponents *)day
{
    return revenant_sameDay(_selectedDate, day);
}

- (BOOL)revenant_canSelect:(NSDateComponents *)day
{
    SEL canSelect = @selector(dateSelection:canSelectDate:);
    if (![_delegate respondsToSelector:canSelect])
        return YES;
    BOOL (*answer)(id, SEL, id, id) = (BOOL (*)(id, SEL, id, id))[(NSObject *)_delegate methodForSelector:canSelect];
    return answer(_delegate, canSelect, self, day);
}

- (void)revenant_didTapDay:(NSDateComponents *)day
{
    if (revenant_sameDay(_selectedDate, day) || ![self revenant_canSelect:day])
        return;
    _selectedDate = [day copy];
    [self revenant_redraw];
    [_delegate dateSelection:self didSelectDate:day];
}

@end
