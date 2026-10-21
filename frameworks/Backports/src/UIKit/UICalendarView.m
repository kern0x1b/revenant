#import <UIKit/UIKit.h>
#import "RevenantCalendar.h"

static Protocol *revenant_calendarViewDelegateProtocol(void) __attribute__((used));
static Protocol *revenant_calendarViewDelegateProtocol(void)
{
    return @protocol(UICalendarViewDelegate);
}

static NSString *const RevenantDefaultFontDesign = @"NSCTFontUIFontDesignDefault";

static const CGFloat RevenantHeaderHeight = 44;
static const CGFloat RevenantWeekdayHeight = 20;
static const CGFloat RevenantGridTop = 64;
static const CGFloat RevenantArrowInset = 44;

static void revenant_needs(BOOL held, NSString *condition)
{
    if (!held)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: %@", condition];
}

static NSDate *revenant_monthStart(NSCalendar *calendar, NSDate *date)
{
    NSDateComponents *parts = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    parts.day = 1;
    return [calendar dateFromComponents:parts];
}

static NSDate *revenant_firstOfMonth(NSCalendar *calendar, NSDateComponents *components)
{
    NSDateComponents *parts = [[NSDateComponents alloc] init];
    parts.year = components.year == NSUndefinedDateComponent ? 1 : components.year;
    parts.month = components.month == NSUndefinedDateComponent ? 1 : components.month;
    parts.day = 1;
    return [calendar dateFromComponents:parts];
}

static NSDateComponents *revenant_monthComponents(NSCalendar *calendar, NSDate *monthStart)
{
    NSDateComponents *parts = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth fromDate:monthStart];
    parts.day = NSUndefinedDateComponent;
    parts.calendar = calendar;
    return parts;
}

static NSDate *revenant_shiftMonths(NSCalendar *calendar, NSDate *date, NSInteger months)
{
    NSDateComponents *step = [[NSDateComponents alloc] init];
    step.month = months;
    return [calendar dateByAddingComponents:step toDate:date options:0];
}

static NSDateInterval *revenant_defaultRange(void)
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    gregorian.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDateComponents *first = [[NSDateComponents alloc] init];
    first.year = 1;
    first.month = 1;
    first.day = 1;
    NSDateComponents *last = [[NSDateComponents alloc] init];
    last.year = 4001;
    last.month = 1;
    last.day = 1;
    return [[NSDateInterval alloc] initWithStartDate:[gregorian dateFromComponents:first] endDate:[gregorian dateFromComponents:last]];
}

@implementation UICalendarView {
@private
    __weak id<UICalendarViewDelegate> _delegate;
    UICalendarSelection *_selectionBehavior;
    NSLocale *_locale;
    NSCalendar *_calendar;
    NSTimeZone *_timeZone;
    NSString *_fontDesign;
    NSDateInterval *_availableDateRange;
    NSDateComponents *_visibleDateComponents;
    BOOL _wantsDateDecorations;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        [self revenant_setUp];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self revenant_setUp];
    }
    return self;
}

- (void)revenant_setUp
{
    _locale = [NSLocale currentLocale];
    _calendar = [NSCalendar currentCalendar];
    _fontDesign = [RevenantDefaultFontDesign copy];
    _availableDateRange = revenant_defaultRange();
    _wantsDateDecorations = YES;
    _visibleDateComponents = revenant_monthComponents(_calendar, revenant_monthStart(_calendar, [NSDate date]));

    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_tapped:)]];
    UISwipeGestureRecognizer *toNext = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_swipedToNext:)];
    toNext.direction = UISwipeGestureRecognizerDirectionLeft;
    [self addGestureRecognizer:toNext];
    UISwipeGestureRecognizer *toPrevious = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_swipedToPrevious:)];
    toPrevious.direction = UISwipeGestureRecognizerDirectionRight;
    [self addGestureRecognizer:toPrevious];
}

- (id<UICalendarViewDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UICalendarViewDelegate>)delegate
{
    _delegate = delegate;
}

- (UICalendarSelection *)selectionBehavior
{
    return _selectionBehavior;
}

- (void)setSelectionBehavior:(UICalendarSelection *)selectionBehavior
{
    UICalendarSelection *previous = _selectionBehavior;
    _selectionBehavior = selectionBehavior;
    [previous revenant_attachToView:nil];
    [selectionBehavior revenant_attachToView:self];
    [self setNeedsDisplay];
}

- (NSLocale *)locale
{
    return _locale;
}

- (void)setLocale:(NSLocale *)locale
{
    revenant_needs(locale != nil, @"calendar");
    _locale = [locale copy];
    [self setNeedsDisplay];
}

- (NSCalendar *)calendar
{
    return _calendar;
}

- (void)setCalendar:(NSCalendar *)calendar
{
    revenant_needs(calendar != nil, @"calendar");
    NSDate *first = revenant_firstOfMonth(_calendar, _visibleDateComponents);
    _calendar = [calendar copy];
    _visibleDateComponents = revenant_monthComponents(_calendar, revenant_monthStart(_calendar, first));
    [self setNeedsDisplay];
}

- (NSTimeZone *)timeZone
{
    return _timeZone;
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    _timeZone = [timeZone copy];
    [self setNeedsDisplay];
}

- (NSString *)fontDesign
{
    return _fontDesign;
}

- (void)setFontDesign:(NSString *)fontDesign
{
    _fontDesign = [fontDesign copy];
    [self setNeedsDisplay];
}

- (NSDateInterval *)availableDateRange
{
    return _availableDateRange;
}

- (void)setAvailableDateRange:(NSDateInterval *)availableDateRange
{
    revenant_needs(availableDateRange != nil, @"date");
    _availableDateRange = [availableDateRange copy];
    NSCalendar *calendar = [self revenant_calendarForDates];
    NSDate *visible = revenant_firstOfMonth(calendar, _visibleDateComponents);
    NSDate *first = revenant_monthStart(calendar, _availableDateRange.startDate);
    NSDate *last = revenant_monthStart(calendar, _availableDateRange.endDate);
    if ([visible compare:first] == NSOrderedAscending)
        [self revenant_showMonthStartingAt:first];
    else if ([visible compare:last] == NSOrderedDescending)
        [self revenant_showMonthStartingAt:last];
}

- (NSDateComponents *)visibleDateComponents
{
    return [_visibleDateComponents copy];
}

- (void)setVisibleDateComponents:(NSDateComponents *)dateComponents animated:(BOOL)animated
{
    revenant_needs(dateComponents != nil, @"date");
    NSCalendar *calendar = [self revenant_calendarForDates];
    NSDate *monthStart = revenant_firstOfMonth(calendar, dateComponents);
    if (![self revenant_containsMonthStarting:monthStart])
        [NSException raise:NSInternalInconsistencyException format:@"Unable to set a visible month that is before the minimum or after the maximum date."];
    [self revenant_showMonthStartingAt:monthStart];
}

- (BOOL)wantsDateDecorations
{
    return _wantsDateDecorations;
}

- (void)setWantsDateDecorations:(BOOL)wantsDateDecorations
{
    _wantsDateDecorations = wantsDateDecorations;
    [self setNeedsDisplay];
}

- (void)reloadDecorationsForDateComponents:(NSArray<NSDateComponents *> *)dates animated:(BOOL)animated
{
    [self setNeedsDisplay];
}

- (NSCalendar *)revenant_calendarForDates
{
    if (!_timeZone)
        return _calendar;
    NSCalendar *calendar = [_calendar copy];
    calendar.timeZone = _timeZone;
    return calendar;
}

- (BOOL)revenant_containsMonthStarting:(NSDate *)monthStart
{
    NSCalendar *calendar = [self revenant_calendarForDates];
    NSDate *first = revenant_monthStart(calendar, _availableDateRange.startDate);
    NSDate *last = revenant_monthStart(calendar, _availableDateRange.endDate);
    return [monthStart compare:first] != NSOrderedAscending && [monthStart compare:last] != NSOrderedDescending;
}

- (void)revenant_showMonthStartingAt:(NSDate *)monthStart
{
    NSDateComponents *previous = _visibleDateComponents;
    NSDateComponents *next = revenant_monthComponents([self revenant_calendarForDates], monthStart);
    next.calendar = _calendar;
    if (previous.year == next.year && previous.month == next.month)
        return;
    _visibleDateComponents = next;
    [self setNeedsDisplay];
    SEL changed = @selector(calendarView:didChangeVisibleDateComponentsFrom:);
    if ([_delegate respondsToSelector:changed]) {
        void (*notify)(id, SEL, id, id) = (void (*)(id, SEL, id, id))[(NSObject *)_delegate methodForSelector:changed];
        notify(_delegate, changed, self, previous);
    }
}

- (void)revenant_stepMonths:(NSInteger)months
{
    NSCalendar *calendar = [self revenant_calendarForDates];
    NSDate *target = revenant_shiftMonths(calendar, revenant_firstOfMonth(calendar, _visibleDateComponents), months);
    if ([self revenant_containsMonthStarting:target])
        [self revenant_showMonthStartingAt:target];
}

- (void)revenant_swipedToNext:(UISwipeGestureRecognizer *)swipe
{
    [self revenant_stepMonths:1];
}

- (void)revenant_swipedToPrevious:(UISwipeGestureRecognizer *)swipe
{
    [self revenant_stepMonths:-1];
}

- (void)revenant_tapped:(UITapGestureRecognizer *)tap
{
    CGPoint point = [tap locationInView:self];
    if (point.y < RevenantHeaderHeight) {
        if (point.x < RevenantArrowInset)
            [self revenant_stepMonths:-1];
        else if (point.x > CGRectGetWidth(self.bounds) - RevenantArrowInset)
            [self revenant_stepMonths:1];
        return;
    }
    NSDateComponents *day = [self revenant_dateAtPoint:point];
    if (day && _selectionBehavior)
        [_selectionBehavior revenant_didTapDay:day];
}

- (NSInteger)revenant_daysInVisibleMonth:(NSDate *)first calendar:(NSCalendar *)calendar
{
    return [calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:first].length;
}

- (NSInteger)revenant_leadingBlanks:(NSDate *)first calendar:(NSCalendar *)calendar
{
    NSInteger weekday = [calendar components:NSCalendarUnitWeekday fromDate:first].weekday;
    return (weekday - calendar.firstWeekday + 7) % 7;
}

- (CGRect)revenant_cellAtIndex:(NSInteger)index
{
    CGFloat cellWidth = floor(CGRectGetWidth(self.bounds) / 7.0);
    CGFloat cellHeight = floor((CGRectGetHeight(self.bounds) - RevenantGridTop) / 6.0);
    return CGRectMake((index % 7) * cellWidth, RevenantGridTop + (index / 7) * cellHeight, cellWidth, cellHeight);
}

- (NSDateComponents *)revenant_dayComponents:(NSInteger)day
{
    NSDateComponents *parts = [[NSDateComponents alloc] init];
    parts.year = _visibleDateComponents.year;
    parts.month = _visibleDateComponents.month;
    parts.day = day;
    parts.calendar = _calendar;
    return parts;
}

- (NSDateComponents *)revenant_dateAtPoint:(CGPoint)point
{
    if (point.y < RevenantGridTop)
        return nil;
    NSCalendar *calendar = [self revenant_calendarForDates];
    NSDate *first = revenant_firstOfMonth(calendar, _visibleDateComponents);
    CGFloat cellWidth = floor(CGRectGetWidth(self.bounds) / 7.0);
    CGFloat cellHeight = floor((CGRectGetHeight(self.bounds) - RevenantGridTop) / 6.0);
    NSInteger column = (NSInteger)(point.x / cellWidth);
    NSInteger row = (NSInteger)((point.y - RevenantGridTop) / cellHeight);
    if (column < 0 || column > 6 || row < 0 || row > 5)
        return nil;
    NSInteger day = row * 7 + column - [self revenant_leadingBlanks:first calendar:calendar] + 1;
    if (day < 1 || day > [self revenant_daysInVisibleMonth:first calendar:calendar])
        return nil;
    NSDateComponents *components = [self revenant_dayComponents:day];
    if (![_availableDateRange containsDate:[calendar dateFromComponents:components]])
        return nil;
    return components;
}

- (void)drawRect:(CGRect)rect
{
    NSCalendar *calendar = [self revenant_calendarForDates];
    NSDate *first = revenant_firstOfMonth(calendar, _visibleDateComponents);
    NSInteger days = [self revenant_daysInVisibleMonth:first calendar:calendar];
    NSInteger leading = [self revenant_leadingBlanks:first calendar:calendar];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = _locale;
    formatter.calendar = calendar;
    formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MMMM y" options:0 locale:_locale] ?: @"MMMM y";
    [self revenant_drawHeader:[formatter stringFromDate:first] calendar:calendar];
    [self revenant_drawWeekdaysWithFormatter:formatter calendar:calendar];

    for (NSInteger index = 0; index < 42; index++) {
        NSInteger day = index - leading + 1;
        if (day >= 1 && day <= days)
            [self revenant_drawDay:day inCell:[self revenant_cellAtIndex:index] calendar:calendar];
    }
}

- (void)revenant_drawHeader:(NSString *)title calendar:(NSCalendar *)calendar
{
    CGFloat width = CGRectGetWidth(self.bounds);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:17], NSForegroundColorAttributeName: [UIColor blackColor]};
    CGSize size = [title sizeWithAttributes:attributes];
    [title drawAtPoint:CGPointMake((width - size.width) / 2.0, (RevenantHeaderHeight - size.height) / 2.0) withAttributes:attributes];

    BOOL canPrevious = [self revenant_containsMonthStarting:revenant_shiftMonths(calendar, revenant_firstOfMonth(calendar, _visibleDateComponents), -1)];
    BOOL canNext = [self revenant_containsMonthStarting:revenant_shiftMonths(calendar, revenant_firstOfMonth(calendar, _visibleDateComponents), 1)];
    [self revenant_drawArrowAtX:RevenantArrowInset / 2.0 pointingLeft:YES enabled:canPrevious];
    [self revenant_drawArrowAtX:width - RevenantArrowInset / 2.0 pointingLeft:NO enabled:canNext];
}

- (void)revenant_drawArrowAtX:(CGFloat)x pointingLeft:(BOOL)left enabled:(BOOL)enabled
{
    CGFloat y = RevenantHeaderHeight / 2.0;
    CGFloat tip = left ? x - 5 : x + 5;
    CGFloat back = left ? x + 5 : x - 5;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetStrokeColorWithColor(context, (enabled ? [UIColor blackColor] : [UIColor lightGrayColor]).CGColor);
    CGContextSetLineWidth(context, 2);
    CGContextMoveToPoint(context, back, y - 7);
    CGContextAddLineToPoint(context, tip, y);
    CGContextAddLineToPoint(context, back, y + 7);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

- (void)revenant_drawWeekdaysWithFormatter:(NSDateFormatter *)formatter calendar:(NSCalendar *)calendar
{
    NSArray *symbols = formatter.shortWeekdaySymbols;
    CGFloat cellWidth = floor(CGRectGetWidth(self.bounds) / 7.0);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:12], NSForegroundColorAttributeName: [UIColor grayColor]};
    for (NSInteger column = 0; column < 7; column++) {
        NSString *name = symbols[(calendar.firstWeekday - 1 + column) % 7];
        CGSize size = [name sizeWithAttributes:attributes];
        CGFloat x = column * cellWidth + (cellWidth - size.width) / 2.0;
        [name drawAtPoint:CGPointMake(x, RevenantHeaderHeight + (RevenantWeekdayHeight - size.height) / 2.0) withAttributes:attributes];
    }
}

- (void)revenant_drawDay:(NSInteger)day inCell:(CGRect)cell calendar:(NSCalendar *)calendar
{
    NSDateComponents *components = [self revenant_dayComponents:day];
    BOOL inRange = [_availableDateRange containsDate:[calendar dateFromComponents:components]];
    BOOL selected = _selectionBehavior && [_selectionBehavior revenant_isSelected:components];
    BOOL enabled = inRange && (selected || !_selectionBehavior || [_selectionBehavior revenant_canSelect:components]);

    CGPoint centre = CGPointMake(CGRectGetMidX(cell), CGRectGetMinY(cell) + CGRectGetHeight(cell) * 0.4);
    if (selected) {
        CGFloat radius = MIN(CGRectGetWidth(cell), CGRectGetHeight(cell)) * 0.36;
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0 green:0.478 blue:1 alpha:1].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(centre.x - radius, centre.y - radius, radius * 2, radius * 2));
    }
    UIColor *colour = selected ? [UIColor whiteColor] : (enabled ? [UIColor blackColor] : [UIColor lightGrayColor]);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:16], NSForegroundColorAttributeName: colour};
    NSString *text = [NSString stringWithFormat:@"%ld", (long)day];
    CGSize size = [text sizeWithAttributes:attributes];
    [text drawAtPoint:CGPointMake(centre.x - size.width / 2.0, centre.y - size.height / 2.0) withAttributes:attributes];

    if (_wantsDateDecorations && [_delegate respondsToSelector:@selector(calendarView:decorationForDateComponents:)]) {
        UICalendarViewDecoration *decoration = [_delegate calendarView:self decorationForDateComponents:components];
        [decoration revenant_drawInRect:cell];
    }
}

@end
