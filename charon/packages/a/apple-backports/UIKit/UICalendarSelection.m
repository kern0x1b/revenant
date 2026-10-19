#import <UIKit/UIKit.h>
#import "CharonCalendar.h"

// The base of the calendar's selection behaviours. On its own it chooses nothing: the release's base answers no selection, and its one
// method, updateSelectableDates, asks the calendar view it is attached to to show the days again. The two behaviours the release makes,
// a single date and several dates, are the subclasses, which decide the days.
//
// The base is instantiable on the host, and so it is here: an instance has no selection and takes no tap.
@implementation UICalendarSelection {
@private
    __weak UICalendarView *_view;
}

// The base's own initialiser is NSObject's; the subclasses reach it here, since the SDK marks the base's init unavailable.
- (instancetype)charon_init
{
    return [super init];
}

// The calendar view asks the day again on its next drawing, so a view that is drawn again has the selectable days the delegate now gives.
- (void)updateSelectableDates
{
    [self charon_redraw];
}

- (void)charon_attachToView:(UICalendarView *)view
{
    _view = view;
}

- (void)charon_redraw
{
    [_view setNeedsDisplay];
}

- (BOOL)charon_isSelected:(NSDateComponents *)day
{
    return NO;
}

- (BOOL)charon_canSelect:(NSDateComponents *)day
{
    return YES;
}

- (void)charon_didTapDay:(NSDateComponents *)day
{
}

@end
