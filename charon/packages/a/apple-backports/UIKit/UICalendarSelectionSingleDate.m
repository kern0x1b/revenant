#import <UIKit/UIKit.h>
#import "CharonCalendar.h"

static Protocol *charon_singleDateSelectionDelegateProtocol(void) __attribute__((used));
static Protocol *charon_singleDateSelectionDelegateProtocol(void)
{
    return @protocol(UICalendarSelectionSingleDateDelegate);
}

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

- (void)setSelectedDate:(NSDateComponents *)selectedDate animated:(BOOL)animated
{
    [self setSelectedDate:selectedDate];
}

- (BOOL)charon_isSelected:(NSDateComponents *)day
{
    return charon_sameDay(_selectedDate, day);
}

- (BOOL)charon_canSelect:(NSDateComponents *)day
{
    SEL canSelect = @selector(dateSelection:canSelectDate:);
    if (![_delegate respondsToSelector:canSelect])
        return YES;
    BOOL (*answer)(id, SEL, id, id) = (BOOL (*)(id, SEL, id, id))[(NSObject *)_delegate methodForSelector:canSelect];
    return answer(_delegate, canSelect, self, day);
}

- (void)charon_didTapDay:(NSDateComponents *)day
{
    if (charon_sameDay(_selectedDate, day) || ![self charon_canSelect:day])
        return;
    _selectedDate = [day copy];
    [self charon_redraw];
    [_delegate dateSelection:self didSelectDate:day];
}

@end
