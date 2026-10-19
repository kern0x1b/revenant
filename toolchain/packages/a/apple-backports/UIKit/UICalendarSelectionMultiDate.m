#import <UIKit/UIKit.h>
#import "RevenantCalendar.h"

static Protocol *revenant_multiDateSelectionDelegateProtocol(void) __attribute__((used));
static Protocol *revenant_multiDateSelectionDelegateProtocol(void)
{
    return @protocol(UICalendarSelectionMultiDateDelegate);
}

static BOOL revenant_sameMultiDay(NSDateComponents *first, NSDateComponents *second)
{
    return first && second && first.year == second.year && first.month == second.month && first.day == second.day;
}

@implementation UICalendarSelectionMultiDate {
@private
    __weak id<UICalendarSelectionMultiDateDelegate> _delegate;
    NSArray<NSDateComponents *> *_selectedDates;
}

- (instancetype)initWithDelegate:(id<UICalendarSelectionMultiDateDelegate>)delegate
{
    if ((self = [self revenant_init])) {
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
    [self revenant_redraw];
}

- (void)setSelectedDates:(NSArray<NSDateComponents *> *)selectedDates animated:(BOOL)animated
{
    [self setSelectedDates:selectedDates];
}

- (BOOL)revenant_isSelected:(NSDateComponents *)day
{
    for (NSDateComponents *chosen in _selectedDates) {
        if (revenant_sameMultiDay(chosen, day))
            return YES;
    }
    return NO;
}

- (BOOL)revenant_delegateAllows:(SEL)question day:(NSDateComponents *)day
{
    if (![_delegate respondsToSelector:question])
        return YES;
    BOOL (*answer)(id, SEL, id, id) = (BOOL (*)(id, SEL, id, id))[(NSObject *)_delegate methodForSelector:question];
    return answer(_delegate, question, self, day);
}

- (BOOL)revenant_canSelect:(NSDateComponents *)day
{
    return [self revenant_delegateAllows:@selector(multiDateSelection:canSelectDate:) day:day];
}

- (void)revenant_didTapDay:(NSDateComponents *)day
{
    if ([self revenant_isSelected:day]) {
        if (![self revenant_delegateAllows:@selector(multiDateSelection:canDeselectDate:) day:day])
            return;
        NSMutableArray *kept = [NSMutableArray array];
        for (NSDateComponents *chosen in _selectedDates) {
            if (!revenant_sameMultiDay(chosen, day))
                [kept addObject:chosen];
        }
        _selectedDates = [kept copy];
        [self revenant_redraw];
        [_delegate multiDateSelection:self didDeselectDate:day];
        return;
    }
    if (![self revenant_canSelect:day])
        return;
    _selectedDates = [[_selectedDates arrayByAddingObject:[day copy]] copy];
    [self revenant_redraw];
    [_delegate multiDateSelection:self didSelectDate:day];
}

@end
