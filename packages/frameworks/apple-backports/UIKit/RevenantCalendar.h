#import <UIKit/UIKit.h>

@interface UICalendarView (RevenantParts)
- (NSCalendar *)revenant_calendarForDates;
- (NSDateComponents *)revenant_dateAtPoint:(CGPoint)point;
@end

@interface UICalendarViewDecoration (RevenantParts)
- (void)revenant_drawInRect:(CGRect)rect;
@end

@interface UICalendarSelection (RevenantParts)
- (void)revenant_attachToView:(UICalendarView *)view;
- (void)revenant_redraw;
- (instancetype)revenant_init;
- (BOOL)revenant_isSelected:(NSDateComponents *)day;
- (BOOL)revenant_canSelect:(NSDateComponents *)day;
- (void)revenant_didTapDay:(NSDateComponents *)day;
@end
