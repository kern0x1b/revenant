#import <UIKit/UIKit.h>

@interface UICalendarView (CharonParts)
- (NSCalendar *)charon_calendarForDates;
- (NSDateComponents *)charon_dateAtPoint:(CGPoint)point;
@end

@interface UICalendarViewDecoration (CharonParts)
- (void)charon_drawInRect:(CGRect)rect;
@end

@interface UICalendarSelection (CharonParts)
- (void)charon_attachToView:(UICalendarView *)view;
- (void)charon_redraw;
- (instancetype)charon_init;
- (BOOL)charon_isSelected:(NSDateComponents *)day;
- (BOOL)charon_canSelect:(NSDateComponents *)day;
- (void)charon_didTapDay:(NSDateComponents *)day;
@end
