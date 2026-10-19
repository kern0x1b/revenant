#import <UIKit/UIKit.h>
#import "CharonCalendar.h"

// Several days chosen at once. A tap on a day that is not chosen chooses it when the delegate allows, and tells the delegate; a tap on a
// chosen day takes it back when the delegate allows that, and tells the delegate. Setting the selected dates changes them at once and tells
// nobody, which is what the host does (tests/backports/host/calendar-multidate). The dates are kept in the order they were chosen.
//
// The delegate protocol is kept in the image by a function the object keeps, as the other calendar parts' protocols are.
static Protocol *charon_multiDateSelectionDelegateProtocol(void) __attribute__((used));
static Protocol *charon_multiDateSelectionDelegateProtocol(void)
{
    return @protocol(UICalendarSelectionMultiDateDelegate);
}

// Two days are the same day when their years, months and days are.
static BOOL charon_sameMultiDay(NSDateComponents *first, NSDateComponents *second)
{
    return first && second && first.year == second.year && first.month == second.month && first.day == second.day;
}

@implementation UICalendarSelectionMultiDate {
@private
    __weak id<UICalendarSelectionMultiDateDelegate> _delegate;
    NSArray<NSDateComponents *> *_selectedDates;
}

// The host starts with no days chosen, an empty array.
- (instancetype)initWithDelegate:(id<UICalendarSelectionMultiDateDelegate>)delegate
{
    if ((self = [self charon_init])) {
        _delegate = delegate;
        _selectedDates = [NSArray array];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithDelegate:nil];
}

- (id<UICalendarSelectionMultiDateDelegate>)delegate
{
    return _delegate;
}

- (NSArray<NSDateComponents *> *)selectedDates
{
    return [_selectedDates copy];
}

- (void)setSelectedDates:(NSArray<NSDateComponents *> *)selectedDates
{
    _selectedDates = [selectedDates copy];
    [self charon_redraw];
}

// The release's animated change is the same change at once; the port does not animate the selection.
- (void)setSelectedDates:(NSArray<NSDateComponents *> *)selectedDates animated:(BOOL)animated
{
    [self setSelectedDates:selectedDates];
}

- (BOOL)charon_isSelected:(NSDateComponents *)day
{
    for (NSDateComponents *chosen in _selectedDates) {
        if (charon_sameMultiDay(chosen, day))
            return YES;
    }
    return NO;
}

// Asks a delegate method about a day, which is allowed when there is no delegate or the method is not implemented.
- (BOOL)charon_delegateAllows:(SEL)question day:(NSDateComponents *)day
{
    if (![_delegate respondsToSelector:question])
        return YES;
    BOOL (*answer)(id, SEL, id, id) = (BOOL (*)(id, SEL, id, id))[(NSObject *)_delegate methodForSelector:question];
    return answer(_delegate, question, self, day);
}

- (BOOL)charon_canSelect:(NSDateComponents *)day
{
    return [self charon_delegateAllows:@selector(multiDateSelection:canSelectDate:) day:day];
}

// A chosen day is taken back, and an unchosen one is added, each when the delegate allows it, and the delegate is told which.
- (void)charon_didTapDay:(NSDateComponents *)day
{
    if ([self charon_isSelected:day]) {
        if (![self charon_delegateAllows:@selector(multiDateSelection:canDeselectDate:) day:day])
            return;
        NSMutableArray *kept = [NSMutableArray array];
        for (NSDateComponents *chosen in _selectedDates) {
            if (!charon_sameMultiDay(chosen, day))
                [kept addObject:chosen];
        }
        _selectedDates = [kept copy];
        [self charon_redraw];
        [_delegate multiDateSelection:self didDeselectDate:day];
        return;
    }
    if (![self charon_canSelect:day])
        return;
    _selectedDates = [[_selectedDates arrayByAddingObject:[day copy]] copy];
    [self charon_redraw];
    [_delegate multiDateSelection:self didSelectDate:day];
}

@end
