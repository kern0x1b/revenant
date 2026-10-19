# UICalendarSelection and UICalendarSelectionSingleDate, iOS 16.0

Introduced in iOS 16.0: the way a calendar view lets the user choose days. The base class, `UICalendarSelection`, has one method,
`updateSelectableDates`, which asks the attached calendar view to show the days again. The subclass `UICalendarSelectionSingleDate` chooses one
day at a time, and tells its delegate (`UICalendarSelectionSingleDateDelegate`) of a day the user taps and whether a day can be chosen.
`UICalendarSelectionMultiDate` (several days) is a separate feature group, not in this file.

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=16.0`). The header
marks the classes unavailable on watchOS and tvOS. The base class's `init` and `new` are unavailable in the header.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/calendar-selection`, which compiles the port's
classes beside the host's in one process. 14 shared checks print the same values for both; 5 port-only checks cover the tap path. The 6.1.3
cache holds none of the names (`tools/corpus/objc-inventory.lua`).

## As UIKit does (measured without a window)

- The base class is instantiable at run time (its `init` answers an object, although the header marks it unavailable).
- The base's `updateSelectableDates`, with no calendar view attached, asks no delegate anything.
- A single-date selection's delegate is weak and reads back as given.
- The selected date is kept as a copy: changing the argument afterwards does not change the selection.
- Setting the selected date (with or without `animated:`), and setting it to nil, tell the delegate nothing, and neither does
  `updateSelectableDates` with no view attached.
- A nil selected date is stored as nil.
- `setDelegate:` and `copyWithZone:` are absent: the delegate is given at creation only, and the selection is not copyable.

## What the port does

- `UIKit/UICalendarSelection.m`: the base class keeps the calendar view it is attached to, as a weak reference, set by the view when the
  behaviour is assigned to it. `updateSelectableDates` asks that view to draw again; with no view it does nothing. The base chooses no day:
  its answers are "not selected", "can be selected" and nothing on a tap, the release's base answers.
- `UIKit/UICalendarSelectionSingleDate.m`: the selected date is a copy. A tap on a day chooses it when the delegate's
  `dateSelection:canSelectDate:` allows it (it allows a day when the delegate does not implement the method) and the day is not already chosen;
  then the delegate's `dateSelection:didSelectDate:` is called with that day. Setting the date changes the selection at once and calls nothing.
- The base's `init` is NSObject's. The SDK marks the base class's `init` unavailable, so the subclass starts from `charon_init`, which the base
  implements as `[super init]`.
- The delegate protocol is kept in the image by a function the object keeps (`__attribute__((used))`) that returns `@protocol(...)`. Read from the
  armv7 object of `UICalendarSelectionSingleDate.m` compiled for 6.1.3 against the 16.4 SDK: `__OBJC_LABEL_PROTOCOL_$_UICalendarSelectionSingleDateDelegate`
  is in `__DATA,__objc_protolist`.

## Port-only choices

- A tap on the day already chosen changes nothing and tells nobody. The release's behaviour on that tap is not measured: a tap needs a window,
  and the port's rule is the one the test asserts.
- The release's animated selection change is the same change at once; the port does not animate the selection.
- A refused day (the delegate's `canSelect` answer is NO) is not chosen and the delegate is not told of it.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The state, the copy and the programmatic calls are the host's;
  the tap is the port's, checked by its port-only checks.
