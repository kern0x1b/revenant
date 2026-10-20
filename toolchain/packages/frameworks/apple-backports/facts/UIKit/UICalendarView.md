# UICalendarView, UICalendarViewDecoration and UICalendarViewDelegate, iOS 16.0

Introduced in iOS 16.0: a month calendar that an app shows, with a visible month, days that can be chosen through a selection behaviour, and
decorations (an image, a colour, or a view) at a day's foot. The delegate supplies the decorations, and from iOS 16.2 is told when the
visible month changes.

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=16.0`). The header
marks the view and the decoration unavailable on watchOS and tvOS. The delegate's `calendarView:didChangeVisibleDateComponentsFrom:` is from
iOS 16.2 and the rest from 16.0.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/calendar-view`, which compiles the port's
view and decoration beside the host's classes in one process. 35 shared checks print the same values for both; 7 port-only checks cover the
drawn grid. The 6.1.3 cache holds none of the three names (`tools/corpus/objc-inventory.lua`, 11378 classes, 1171 protocols).

## As UIKit does (measured without a window)

- A new view has no delegate and no selection behaviour, the current locale and calendar, no time zone, the default font design
  `NSCTFontUIFontDesignDefault`, decorations wanted, and the current month visible.
- The default available range is the years 1 to 4001 in the Gregorian calendar, in UTC.
- The visible month is kept as a year and a month with the day undefined; the era is the calendar's.
- Setting the visible components copies them. A month outside the available range raises
  `NSInternalInconsistencyException` with "Unable to set a visible month that is before the minimum or after the maximum date."
- A missing year or month in the components is read as 1 (setting only a day leaves the view at year 1, month 1).
- A nil set of components raises "Invalid parameter not satisfying: date".
- Setting an available range moves the visible month to the nearer end month of the range when the visible month is outside it.
- A nil range raises "Invalid parameter not satisfying: date". A nil calendar raises "Invalid parameter not satisfying: calendar", and so
  does a nil locale (the host's message for the locale is the calendar's condition text).
- A calendar change keeps the instant of the visible month: May 2024 Gregorian reads as May 2567 Buddhist.
- A nil time zone, font design or selection behaviour is stored as nil.
- Decorations are wanted by default and can be turned off.
- The selection behaviour's day and selection answers are measured on the selection classes (`facts/UIKit/UICalendarSelection.md`).

## What the port does

- `UIKit/UICalendarView.m`: the view keeps the state above and gives the same answers and messages. The grid is drawn by the port with the
  backport's string drawing (`NSString+Drawing7.m`), from the locale's title (`dateFormatFromTemplate:` "MMMM y"), the calendar's short weekday
  names starting at its first weekday, and the day numbers. A day outside the available range is grey and cannot be chosen. A tap on the
  header's arrows steps a month (only where the month is in range), a tap on a day goes to the selection behaviour, and a left or right swipe
  steps a month.
- `UIKit/UICalendarViewDecoration.m`: the decoration keeps an image, a colour, both (the image tinted with the colour), or a provider of a
  view; it has no getters, as the release's. The view draws it at the foot of the day's cell.
- `UIKit/RevenantCalendar.h`: the methods the calendar's parts share, which the release does not have.
- The delegate protocol is kept in the image by a function the object keeps (`__attribute__((used))`) that returns `@protocol(...)`. Read from
  the armv7 object of `UICalendarView.m` compiled for 6.1.3 against the 16.4 SDK: `__OBJC_LABEL_PROTOCOL_$_UICalendarViewDelegate` is in
  `__DATA,__objc_protolist`. The 16.2 method is called through its implementation, so the port's build needs no newer availability.

## Named differences and port-only choices

- A calendar change on a view that was refused a nil range once has been seen to raise on the host, in a sequence the test does not repeat;
  the port does not raise there. Not asserted: it is not reproduced in a clean view.
- The port's grid and its decorations are drawn by the port. The host's drawing is not reachable windowless, so the grid's look is not measured
  against the release; the port-only checks assert the geometry (the first day of May 2024 in its weekday column, a blank cell, the header and
  the weekday row giving nothing, a day outside the range giving nothing) and that the delegate is asked once for each day drawn.
- The release animates a month change; this view changes at once, whatever `animated:` says.
- The 6.1.3 system font has one design, so the drawn text does not change with the font design; the design is kept as given.
- The decoration sizes (small 4, medium 6, large 8 points for a disc; 10, 14, 18 for an image) and the decorationWithImage: default size (small)
  are the port's own, not measured: a decoration is only seen in a drawn calendar.
- The day numbers are drawn in ASCII digits.
- A tap on a selected day is handed to the selection behaviour as any tap is; what the release does then is in the selection's facts.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The state and the messages are the host's; the drawing and the
  taps are the port's, checked by the port-only checks and by reading the code.
