#import <UIKit/UIKit.h>
#import "RevenantCalendar.h"

@implementation UICalendarSelection {
@private
    __weak UICalendarView *_view;
}

- (instancetype)revenant_init
{
    return [super init];
}

- (void)updateSelectableDates
{
    [self revenant_redraw];
}

- (void)revenant_attachToView:(UICalendarView *)view
{
    _view = view;
}

- (void)revenant_redraw
{
    [_view setNeedsDisplay];
}

- (BOOL)revenant_isSelected:(NSDateComponents *)day
{
    return NO;
}

- (BOOL)revenant_canSelect:(NSDateComponents *)day
{
    return YES;
}

- (void)revenant_didTapDay:(NSDateComponents *)day
{
}

@end
