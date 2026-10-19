#import <UIKit/UIKit.h>
#import "CharonCalendar.h"

@implementation UICalendarSelection {
@private
    __weak UICalendarView *_view;
}

- (instancetype)charon_init
{
    return [super init];
}

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
