#import <UIKit/UIKit.h>
#import "CharonCalendar.h"

// A month calendar: a title with arrows for the months before and after, a row of weekday names, and the days of the visible month in a
// grid of up to six weeks. The release draws the grid itself; this view draws it with the port's own text and paths, so the picture is
// the port's and not the release's. What the view does is the release's: the visible month is kept within the available range (a month
// set outside it raises, and a range that moves past the visible month pulls it to the nearest end), the locale, calendar and time zone
// decide the names and the first weekday, and days are chosen through the selection behaviour the app attaches.
//
// Animation: a visible-month change with `animated:YES` takes effect at once here; the release animates it, which this view does not.
//
// The view declares the delegate protocol through a function the image keeps, so the release's name for it answers in the image.
static Protocol *charon_calendarViewDelegateProtocol(void) __attribute__((used));
static Protocol *charon_calendarViewDelegateProtocol(void)
{
    return @protocol(UICalendarViewDelegate);
}

// The release's default font design, as its string value on the host.
static NSString *const CharonDefaultFontDesign = @"NSCTFontUIFontDesignDefault";

static const CGFloat CharonHeaderHeight = 44;
static const CGFloat CharonWeekdayHeight = 20;
static const CGFloat CharonGridTop = 64;
static const CGFloat CharonArrowInset = 44;

// Raises the way the host raises a parameter it refuses, with the same condition text.
static void charon_needs(BOOL held, NSString *condition)
{
    if (!held)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: %@", condition];
}

// The first instant of the month that holds the date, in the calendar.
static NSDate *charon_monthStart(NSCalendar *calendar, NSDate *date)
{
    NSDateComponents *parts = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    parts.day = 1;
    return [calendar dateFromComponents:parts];
}

// The first instant of the month the visible components name; a missing year or month is read as 1, as the host reads it.
static NSDate *charon_firstOfMonth(NSCalendar *calendar, NSDateComponents *components)
{
    NSDateComponents *parts = [[NSDateComponents alloc] init];
    parts.year = components.year == NSUndefinedDateComponent ? 1 : components.year;
    parts.month = components.month == NSUndefinedDateComponent ? 1 : components.month;
    parts.day = 1;
    return [calendar dateFromComponents:parts];
}

// Visible components for a month: its year and month, with the day undefined, as the host answers.
static NSDateComponents *charon_monthComponents(NSCalendar *calendar, NSDate *monthStart)
{
    NSDateComponents *parts = [calendar components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth fromDate:monthStart];
    parts.day = NSUndefinedDateComponent;
    parts.calendar = calendar;
    return parts;
}

static NSDate *charon_shiftMonths(NSCalendar *calendar, NSDate *date, NSInteger months)
{
    NSDateComponents *step = [[NSDateComponents alloc] init];
    step.month = months;
    return [calendar dateByAddingComponents:step toDate:date options:0];
}

// The release's default range: the years 1 to 4001 in the Gregorian calendar, in UTC.
static NSDateInterval *charon_defaultRange(void)
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
        [self charon_setUp];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self charon_setUp];
    }
    return self;
}

// The release's starting state: the current locale and calendar, the default font design and range, the current month visible, and the
// decorations wanted. Taps select days, and swipes and the arrows move between months.
- (void)charon_setUp
{
    _locale = [NSLocale currentLocale];
    _calendar = [NSCalendar currentCalendar];
    _fontDesign = [CharonDefaultFontDesign copy];
    _availableDateRange = charon_defaultRange();
    _wantsDateDecorations = YES;
    _visibleDateComponents = charon_monthComponents(_calendar, charon_monthStart(_calendar, [NSDate date]));

    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(charon_tapped:)]];
    UISwipeGestureRecognizer *toNext = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(charon_swipedToNext:)];
    toNext.direction = UISwipeGestureRecognizerDirectionLeft;
    [self addGestureRecognizer:toNext];
    UISwipeGestureRecognizer *toPrevious = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(charon_swipedToPrevious:)];
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

// The behaviour that was attached is told it has left, and the new one that it is in this view; a nil removes the selection.
- (void)setSelectionBehavior:(UICalendarSelection *)selectionBehavior
{
    UICalendarSelection *previous = _selectionBehavior;
    _selectionBehavior = selectionBehavior;
    [previous charon_attachToView:nil];
    [selectionBehavior charon_attachToView:self];
    [self setNeedsDisplay];
}

- (NSLocale *)locale
{
    return _locale;
}

// The host refuses a nil locale with the calendar's condition text, and the port says the same.
- (void)setLocale:(NSLocale *)locale
{
    charon_needs(locale != nil, @"calendar");
    _locale = [locale copy];
    [self setNeedsDisplay];
}

- (NSCalendar *)calendar
{
    return _calendar;
}

// A new calendar keeps the month the view shows: the same first day of that month, in the new calendar's own years.
- (void)setCalendar:(NSCalendar *)calendar
{
    charon_needs(calendar != nil, @"calendar");
    NSDate *first = charon_firstOfMonth(_calendar, _visibleDateComponents);
    _calendar = [calendar copy];
    _visibleDateComponents = charon_monthComponents(_calendar, charon_monthStart(_calendar, first));
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

// The design is kept as the app gives it. The 6.1.3 system font has one design, so the drawn text does not change with it.
- (void)setFontDesign:(NSString *)fontDesign
{
    _fontDesign = [fontDesign copy];
    [self setNeedsDisplay];
}

- (NSDateInterval *)availableDateRange
{
    return _availableDateRange;
}

// A range that no longer holds the visible month moves the view to the nearer end of the range, as the host does.
- (void)setAvailableDateRange:(NSDateInterval *)availableDateRange
{
    charon_needs(availableDateRange != nil, @"date");
    _availableDateRange = [availableDateRange copy];
    NSCalendar *calendar = [self charon_calendarForDates];
    NSDate *visible = charon_firstOfMonth(calendar, _visibleDateComponents);
    NSDate *first = charon_monthStart(calendar, _availableDateRange.startDate);
    NSDate *last = charon_monthStart(calendar, _availableDateRange.endDate);
    if ([visible compare:first] == NSOrderedAscending)
        [self charon_showMonthStartingAt:first];
    else if ([visible compare:last] == NSOrderedDescending)
        [self charon_showMonthStartingAt:last];
}

- (NSDateComponents *)visibleDateComponents
{
    return [_visibleDateComponents copy];
}

// The month the components name is shown; a month outside the available range raises, as the host raises it.
- (void)setVisibleDateComponents:(NSDateComponents *)dateComponents animated:(BOOL)animated
{
    charon_needs(dateComponents != nil, @"date");
    NSCalendar *calendar = [self charon_calendarForDates];
    NSDate *monthStart = charon_firstOfMonth(calendar, dateComponents);
    if (![self charon_containsMonthStarting:monthStart])
        [NSException raise:NSInternalInconsistencyException format:@"Unable to set a visible month that is before the minimum or after the maximum date."];
    [self charon_showMonthStartingAt:monthStart];
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

// The decorations are asked of the delegate again on the next drawing, for the whole visible month; the dates named are drawn with the rest.
- (void)reloadDecorationsForDateComponents:(NSArray<NSDateComponents *> *)dates animated:(BOOL)animated
{
    [self setNeedsDisplay];
}

- (NSCalendar *)charon_calendarForDates
{
    if (!_timeZone)
        return _calendar;
    NSCalendar *calendar = [_calendar copy];
    calendar.timeZone = _timeZone;
    return calendar;
}

- (BOOL)charon_containsMonthStarting:(NSDate *)monthStart
{
    NSCalendar *calendar = [self charon_calendarForDates];
    NSDate *first = charon_monthStart(calendar, _availableDateRange.startDate);
    NSDate *last = charon_monthStart(calendar, _availableDateRange.endDate);
    return [monthStart compare:first] != NSOrderedAscending && [monthStart compare:last] != NSOrderedDescending;
}

// Makes the month the visible one, and tells the delegate what it was when the month really changes.
- (void)charon_showMonthStartingAt:(NSDate *)monthStart
{
    NSDateComponents *previous = _visibleDateComponents;
    NSDateComponents *next = charon_monthComponents([self charon_calendarForDates], monthStart);
    next.calendar = _calendar;
    if (previous.year == next.year && previous.month == next.month)
        return;
    _visibleDateComponents = next;
    [self setNeedsDisplay];
    // The method is the release's from iOS 16.2; it is called through its implementation so the port's build, which targets 6.1.3, does
    // not need the newer availability to compile.
    SEL changed = @selector(calendarView:didChangeVisibleDateComponentsFrom:);
    if ([_delegate respondsToSelector:changed]) {
        void (*notify)(id, SEL, id, id) = (void (*)(id, SEL, id, id))[(NSObject *)_delegate methodForSelector:changed];
        notify(_delegate, changed, self, previous);
    }
}

- (void)charon_stepMonths:(NSInteger)months
{
    NSCalendar *calendar = [self charon_calendarForDates];
    NSDate *target = charon_shiftMonths(calendar, charon_firstOfMonth(calendar, _visibleDateComponents), months);
    if ([self charon_containsMonthStarting:target])
        [self charon_showMonthStartingAt:target];
}

- (void)charon_swipedToNext:(UISwipeGestureRecognizer *)swipe
{
    [self charon_stepMonths:1];
}

- (void)charon_swipedToPrevious:(UISwipeGestureRecognizer *)swipe
{
    [self charon_stepMonths:-1];
}

// The header's arrows step a month; a tap on the grid is a day, which the selection behaviour decides on.
- (void)charon_tapped:(UITapGestureRecognizer *)tap
{
    CGPoint point = [tap locationInView:self];
    if (point.y < CharonHeaderHeight) {
        if (point.x < CharonArrowInset)
            [self charon_stepMonths:-1];
        else if (point.x > CGRectGetWidth(self.bounds) - CharonArrowInset)
            [self charon_stepMonths:1];
        return;
    }
    NSDateComponents *day = [self charon_dateAtPoint:point];
    if (day && _selectionBehavior)
        [_selectionBehavior charon_didTapDay:day];
}

// The number of days in the visible month, and the blank cells before the first of them in the grid.
- (NSInteger)charon_daysInVisibleMonth:(NSDate *)first calendar:(NSCalendar *)calendar
{
    return [calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:first].length;
}

- (NSInteger)charon_leadingBlanks:(NSDate *)first calendar:(NSCalendar *)calendar
{
    NSInteger weekday = [calendar components:NSCalendarUnitWeekday fromDate:first].weekday;
    return (weekday - calendar.firstWeekday + 7) % 7;
}

- (CGRect)charon_cellAtIndex:(NSInteger)index
{
    CGFloat cellWidth = floor(CGRectGetWidth(self.bounds) / 7.0);
    CGFloat cellHeight = floor((CGRectGetHeight(self.bounds) - CharonGridTop) / 6.0);
    return CGRectMake((index % 7) * cellWidth, CharonGridTop + (index / 7) * cellHeight, cellWidth, cellHeight);
}

- (NSDateComponents *)charon_dayComponents:(NSInteger)day
{
    NSDateComponents *parts = [[NSDateComponents alloc] init];
    parts.year = _visibleDateComponents.year;
    parts.month = _visibleDateComponents.month;
    parts.day = day;
    parts.calendar = _calendar;
    return parts;
}

- (NSDateComponents *)charon_dateAtPoint:(CGPoint)point
{
    if (point.y < CharonGridTop)
        return nil;
    NSCalendar *calendar = [self charon_calendarForDates];
    NSDate *first = charon_firstOfMonth(calendar, _visibleDateComponents);
    CGFloat cellWidth = floor(CGRectGetWidth(self.bounds) / 7.0);
    CGFloat cellHeight = floor((CGRectGetHeight(self.bounds) - CharonGridTop) / 6.0);
    NSInteger column = (NSInteger)(point.x / cellWidth);
    NSInteger row = (NSInteger)((point.y - CharonGridTop) / cellHeight);
    if (column < 0 || column > 6 || row < 0 || row > 5)
        return nil;
    NSInteger day = row * 7 + column - [self charon_leadingBlanks:first calendar:calendar] + 1;
    if (day < 1 || day > [self charon_daysInVisibleMonth:first calendar:calendar])
        return nil;
    NSDateComponents *components = [self charon_dayComponents:day];
    if (![_availableDateRange containsDate:[calendar dateFromComponents:components]])
        return nil;
    return components;
}

- (void)drawRect:(CGRect)rect
{
    NSCalendar *calendar = [self charon_calendarForDates];
    NSDate *first = charon_firstOfMonth(calendar, _visibleDateComponents);
    NSInteger days = [self charon_daysInVisibleMonth:first calendar:calendar];
    NSInteger leading = [self charon_leadingBlanks:first calendar:calendar];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = _locale;
    formatter.calendar = calendar;
    formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MMMM y" options:0 locale:_locale] ?: @"MMMM y";
    [self charon_drawHeader:[formatter stringFromDate:first] calendar:calendar];
    [self charon_drawWeekdaysWithFormatter:formatter calendar:calendar];

    for (NSInteger index = 0; index < 42; index++) {
        NSInteger day = index - leading + 1;
        if (day >= 1 && day <= days)
            [self charon_drawDay:day inCell:[self charon_cellAtIndex:index] calendar:calendar];
    }
}

- (void)charon_drawHeader:(NSString *)title calendar:(NSCalendar *)calendar
{
    CGFloat width = CGRectGetWidth(self.bounds);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:17], NSForegroundColorAttributeName: [UIColor blackColor]};
    CGSize size = [title sizeWithAttributes:attributes];
    [title drawAtPoint:CGPointMake((width - size.width) / 2.0, (CharonHeaderHeight - size.height) / 2.0) withAttributes:attributes];

    BOOL canPrevious = [self charon_containsMonthStarting:charon_shiftMonths(calendar, charon_firstOfMonth(calendar, _visibleDateComponents), -1)];
    BOOL canNext = [self charon_containsMonthStarting:charon_shiftMonths(calendar, charon_firstOfMonth(calendar, _visibleDateComponents), 1)];
    [self charon_drawArrowAtX:CharonArrowInset / 2.0 pointingLeft:YES enabled:canPrevious];
    [self charon_drawArrowAtX:width - CharonArrowInset / 2.0 pointingLeft:NO enabled:canNext];
}

- (void)charon_drawArrowAtX:(CGFloat)x pointingLeft:(BOOL)left enabled:(BOOL)enabled
{
    CGFloat y = CharonHeaderHeight / 2.0;
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

- (void)charon_drawWeekdaysWithFormatter:(NSDateFormatter *)formatter calendar:(NSCalendar *)calendar
{
    NSArray *symbols = formatter.shortWeekdaySymbols;
    CGFloat cellWidth = floor(CGRectGetWidth(self.bounds) / 7.0);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:12], NSForegroundColorAttributeName: [UIColor grayColor]};
    for (NSInteger column = 0; column < 7; column++) {
        NSString *name = symbols[(calendar.firstWeekday - 1 + column) % 7];
        CGSize size = [name sizeWithAttributes:attributes];
        CGFloat x = column * cellWidth + (cellWidth - size.width) / 2.0;
        [name drawAtPoint:CGPointMake(x, CharonHeaderHeight + (CharonWeekdayHeight - size.height) / 2.0) withAttributes:attributes];
    }
}

// A day: its number in the cell's upper part, a disc behind it when it is selected, grey when it cannot be chosen, and the decoration the
// delegate gives for it at the cell's foot.
- (void)charon_drawDay:(NSInteger)day inCell:(CGRect)cell calendar:(NSCalendar *)calendar
{
    NSDateComponents *components = [self charon_dayComponents:day];
    BOOL inRange = [_availableDateRange containsDate:[calendar dateFromComponents:components]];
    BOOL selected = _selectionBehavior && [_selectionBehavior charon_isSelected:components];
    BOOL enabled = inRange && (selected || !_selectionBehavior || [_selectionBehavior charon_canSelect:components]);

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
        [decoration charon_drawInRect:cell];
    }
}

@end
