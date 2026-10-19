# UICalendarSelectionMultiDate and UICalendarSelectionMultiDateDelegate, iOS 16.0

Introduced in iOS 16.0: the calendar selection that chooses several days at once. A tap on a day that is not chosen chooses it, when the
delegate allows (`multiDateSelection:canSelectDate:`, optional), and tells the delegate (`multiDateSelection:didSelectDate:`); a tap on a
chosen day takes it back, when the delegate allows (`multiDateSelection:canDeselectDate:`, optional), and tells the delegate
(`multiDateSelection:didDeselectDate:`). The base class and its update are in `facts/UIKit/UICalendarSelection.md`.

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=16.0`). The header
marks the class unavailable on watchOS and tvOS, and its `init` and `new` are unavailable in the header. The delegate's two day methods are
required; the two answers are optional.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/calendar-multidate`, which compiles the
port's classes beside the host's in one process. 12 shared checks print the same values for both; 7 port-only checks cover the tap path. The
6.1.3 cache holds neither name (`tools/corpus/objc-inventory.lua`).

## As UIKit does (measured without a window)

- A new selection has no days chosen: its `selectedDates` is an empty array, and an instance made with `init` has an array as well.
- The selected dates are a copy of the array given: adding to the array afterwards does not change the selection. The day objects in the
  copy are the ones given (the same objects come back).
- Setting the dates, with or without `animated:`, and setting nil (which is stored as nil), tell the delegate nothing; neither does
  `updateSelectableDates` with no view attached.
- The delegate is weak and reads back as given. `setDelegate:` and `copyWithZone:` are absent.

## What the port does

- `UIKit/UICalendarSelectionMultiDate.m`: the days are kept in the order they were chosen. `init` is the designated initialiser with no
  delegate, so both start with an empty array. A tap on a chosen day removes every day that is that day, when the delegate allows; a tap on
  an unchosen day appends a copy of it, when the delegate allows. The tap then tells the delegate which day it was.
- The delegate protocol is kept in the image by a function the object keeps (`__attribute__((used))`) that returns `@protocol(...)`. Read from
  the armv7 object of `UICalendarSelectionMultiDate.m` compiled for 6.1.3 against the 16.4 SDK: `__OBJC_LABEL_PROTOCOL_$_UICalendarSelectionMultiDateDelegate`
  is in `__DATA,__objc_protolist`.

## Port-only choices

- The release's answer to a tap while the delegate refuses the deselection is not measured: a tap needs a window. The port leaves the day
  chosen and tells nobody, which the port-only check asserts.
- The release animates a change of the dates; the port changes them at once.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The state, the copy and the programmatic calls are the host's;
  the tap is the port's, checked by its port-only checks.
