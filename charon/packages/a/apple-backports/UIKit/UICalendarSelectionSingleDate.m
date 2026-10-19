#import <UIKit/UIKit.h>
#import "CharonCalendar.h"

// One day chosen at a time. Setting the selected date changes it at once and tells nobody: the delegate hears of a day the user taps, and
// is asked whether a tapped day can be chosen, as the host's behaviour is measured to be (tests/backports/host/calendar-selection). A tap on
// the day already chosen changes nothing and tells nobody.
//
// The delegate protocol is kept in the image by a function the object keeps, as the calendar view's is.
static Protocol *charon_singleDateSelectionDelegateProtocol(void) __attribute__((used));
static Protocol *charon_singleDateSelectionDelegateProtocol(void)
{
    return @protocol(UICalendarSelectionSingleDateDelegate);
}

// Two days are the same day when their years, months and days are.
static BOOL charon_sameDay(NSDateComponents *first, NSDateComponents *second)
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
    if ((self = [self charon_init])) {
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
    [self charon_redraw];
}

// The release's animated change is the same change at once; the port does not animate the selection.
- (void)setSelectedDate:(NSDateComponents *)selectedDate animated:(BOOL)animated
{
    [self setSelectedDate:selectedDate];
}

- (BOOL)charon_isSelected:(NSDateComponents *)day
{
    return charon_sameDay(_selectedDate, day);
}

// The delegate's answer on whether the day can be chosen; without a delegate, or without the method, a day can be chosen.
- (BOOL)charon_canSelect:(NSDateComponents *)day
{
    SEL canSelect = @selector(dateSelection:canSelectDate:);
    if (![_delegate respondsToSelector:canSelect])
        return YES;
    BOOL (*answer)(id, SEL, id, id) = (BOOL (*)(id, SEL, id, id))[(NSObject *)_delegate methodForSelector:canSelect];
    return answer(_delegate, canSelect, self, day);
}

// A tap chooses the day when the delegate allows it and the day is not already chosen, and then tells the delegate which day it is.
- (void)charon_didTapDay:(NSDateComponents *)day
{
    if (charon_sameDay(_selectedDate, day) || ![self charon_canSelect:day])
        return;
    _selectedDate = [day copy];
    [self charon_redraw];
    [_delegate dateSelection:self didSelectDate:day];
}

@end
