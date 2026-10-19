# UICollectionViewCompositionalLayout, iOS 13.0

Introduced in iOS 13.0: a collection view layout that is described, not computed by the application - a section is a
group, a group holds items, and the layout works out where every cell, supplementary view and decoration view goes.
`UICollectionViewCompositionalLayout` is a `UICollectionViewLayout` subclass, and iOS 6 has `UICollectionViewLayout` since
6.0, so the port writes the whole thing: the frames come from the description, and the collection view of the release asks
for them through the calls it has always made (`-prepareLayout`, `-collectionViewContentSize`,
`-layoutAttributesForElementsInRect:`, the three `-layoutAttributesFor...AtIndexPath:` ones and
`-shouldInvalidateLayoutForBoundsChange:`).

Source: the host's own UIKit under Mac Catalyst (macOS 27.0). Nothing of UIKit's code or bytes is read: every rule below was
**measured** - the same description was given to the host's layout and to the port's, in a collection view in a real window, and
the frames, content sizes, element lists and index paths were compared - and the port was made to agree. The differential is
`tests/backports/host/uikit2/compositionallayout_test.m` (the `compositionallayout` group): 182 fixed layouts compared exactly,
whose answers become `tests/backports/device/compositional-expectations.h`, and random ones. The device test is
`tests/backports/device/compositional.m`, run at the scale the numbers were recorded at (2).

## What the port does as UIKit does

Sizes and rounding.

- A layout is solved for the size of the collection view's bounds. A fraction is a fraction of the width, or of the height, of
  the box its item is laid out in, and the answer is rounded **down** to a pixel of the screen (half a point at scale 2), where
  a value that is a hair below a pixel counts as on it. Positions are rounded to the **nearest** pixel. An absolute length is
  kept as it is and an estimated one is its estimate until the cell has been measured (Self-sizing, below).
- A section is laid out in the size of the collection view less its content insets. A group of a section is sized in the
  section's width less the insets and the **whole** height when the layout scrolls down, and in the whole width and the height
  less the insets when it scrolls sideways: the size along the scroll axis is not cleared of the insets. A group of a group is
  sized in the inner size of its parent, less the group's own content insets. A fraction of the width used for a height is a
  fraction of the width all the same.
- An item's frame is its slot less its content insets. An inset larger than the slot makes a frame of the difference, taken
  positive, so an item 9.5 wide with 7 points on each side is 4.5 wide.

What a group holds.

- A horizontal group puts its subitems in a row, and a vertical one in a column, repeating the list from the start for as many
  items as the section has, and starts a new group when the next one does not fit. **How many fit** is decided against the
  size less the spacing between the items, so the fractions are not fractions of the whole size but of what is left of it once the
  spacings are taken off. When the items of a row take their height as a fraction of the height (or as a length), the count *n*
  is the largest for which *n* items, sized in the size less *n - 1* spacings, and the spacings between them, still fit. When
  some item takes its height as a fraction of the width, the count is first the number of items that fit in the whole size with no
  spacing at all, the fractions are resolved in the size less one spacing fewer than that count, and the row takes as many items
  as then fit with the spacing between them. A group made for a count takes exactly that many, each one over the count of the size
  less the spacings. (Both rules were fitted to a few hundred rows; the second was found by reading the heights of the items.)
- The spacing between items is fixed, or flexible, which is a minimum: what is left of the row is shared out between the
  flexible spacings, the ones between items and the flexible edge spacings of items alike. The share is allowed to be negative, so
  a group wider than its section with a flexible leading edge is pushed left by the difference. An item smaller than its row across
  sits at the start of it, unless its edge spacing is flexible.
- An item's edge spacing lies outside the item: a fixed edge takes room, and a flexible one takes what is left over, the way the
  flexible spacing between items does. A group's own edge spacing does the same in its section, and its top and bottom (leading and
  trailing when scrolling sideways) are room between groups.
- A group of which even the first item is larger than the group along the group's own axis lays out **nothing**: the section
  behaves as one with no items, and has no size unless it has boundary items. The port says so once in the log. An item larger across
  the axis is placed and sticks out.
- The last group of a section that has fewer items than a whole group is **trimmed** along the scroll axis: measured from the group's
  inner corner, it is as long as the items in it reach (to the far edge of their frames, the item's own insets taken off) plus what
  a whole group leaves over after its last item. The group's own insets are not added back. A group trimmed to less than nothing
  makes a section of no height, which is left out of every list of elements. A group that holds a nested group that is partly
  filled is trimmed by the nested group's items in the same way.
- A custom group asks its item provider once for each section, with a container the size of the group resolved in the
  **whole** size of the collection view (not in the section's), its content insets and the size less them; the frames it answers are
  relative to the group's own outer corner, and the group is repeated for the items that are left. An estimated size in a custom
  group says no content insets, as UIKit's does.
- When a group's height is estimated and its items are not, the group is as tall as its tallest item.
- A group whose size **along its own axis** is estimated holds exactly one run of its subitems, each once, however much room the
  estimate leaves, and is as long as what it holds (a vertical group of two subitems of 30 in an estimate of 100 is 65 long, with
  the spacing); a group of a fixed count holds that count and is as long as what it holds, the count's items each taking their
  share of the estimate. The last group, with fewer items, is as long as those it has.

Sections and the layout.

- Sections are stacked along the scroll axis, with the layout's inter-section spacing between every two, empty ones included. A
  section with no items has no size unless it has boundary supplementary items, and then it is the size of its two content insets
  and what its boundary items need. The content size is the sum along the axis, and across it the width of the collection view or
  of the widest group if that is wider.
- Boundary supplementary items sit at an edge of a section (of the layout, for the layout's). The item takes the size of its
  `layoutSize` in the section's width, cleared of the insets when the section follows them, and the whole height; the alignment
  names the corner or edge, the item is centred on the axis it does not name, and the offset moves it. An item that extends the
  boundary lies *outside* the section along the scroll axis and the section grows to hold it, on either side it sticks out on; one
  that does not lies inside. An item aligned to the sides of a section that scrolls down (top and bottom when scrolling sideways) is
  centred along the section; when it extends the boundary and is taller than the section, the section grows to it and the item is
  placed at its start, and when it does not extend it, the item is centred and sticks out on both sides. Items of the same side do
  not stack: each is placed against the section's edge. A section with no items is as large as what its extending items need.
- Pinned boundary items stay in the visible bounds (less the adjusted content inset) while their section is in view, and are stopped
  at the far edge of the section or of the layout, the room the extending items took not counted for the far side. They have a z
  index of a billion plus their own while they are in the visible bounds. A change of the bounds invalidates the layout only when
  there is a pinned item; the port then keeps the solved frames and re-pins.
- Supplementary items tied to an item are placed from its frame, those tied to a group from the group's frame, resolved in the size
  the group is laid out in. The container anchor names a point of the frame; the item anchor, which defaults to the same edges, a
  point of the view; the view is put where its point falls on the container's, and offsets add: an absolute offset in points, a
  fractional one in fractions of **the supplementary view's** own size.
- Decoration items are the size of their section, boundary items included, less their insets, and are not made for a section with no
  size. Cells of a section that has decoration items have z index 1.
- Index paths. A cell is its item's, in the section. A boundary item is item 0 of its section, the layout's is item `NSIntegerMax` of
  section 0. Supplementary items tied to items and to groups count from 0 for each element kind **in each section**, in the order
  they are laid out; a decoration item is its number in the section's array.
- Asking. `-layoutAttributesForElementsInRect:` clips the rectangle to the content: nothing comes back outside it, and a rectangle
  with no area gets the decoration views alone. What belongs to a group is handed out only when the **group** meets the rectangle
  (an item that sticks out of its group is answered for the part of it in the group, and one wholly outside its group is never
  answered, though `-layoutAttributesForItemAtIndexPath:` gives its frame), and decoration views by whether their section's frame
  meets or touches it. A section with no size answers nothing.
- The section provider is called once for each section on every solve, with an environment whose container is the size of the
  collection view (no insets), and the view's trait collection. A nil section for a section with items raises
  `Invalid section definition. Please specify a valid section definition when content is to be rendered for a section.
  This is a client error.`

## Orthogonal scrolling

Measured against the host's private scroll view of the section (`_UICollectionViewOrthogonalScrollView`), by moving it to the
offsets of the differential test (`tests/backports/host/uikit2/orthogonal_test.m`: every behavior, four kinds of group and spacing, a header,
seven offsets each) and comparing the cells that are shown and what the handler is told, with no tolerance.

- A section with a behavior other than none has its groups laid out along the X axis in a row as tall as its tallest group (the
  section's groups run sideways, sized as in a layout that scrolls sideways), its insets around the row, and boundary items around
  them that do not scroll. It is as tall as the row, and its offset is the distance the row has moved.
- The offset runs from zero to the row's width less the viewport's (the collection view's width less the section's insets, but
  see Group paging centered), and a row that fits does not scroll. An offset set beyond it is clamped; the port's
  hidden `charon_scrollSection:toOffset:settle:` (used by the tests) is the setter.
- Continuous: any offset. Continuous group leading boundary and group paging: an offset at rest is a group's leading edge (clamped).
  Paging: a multiple of the viewport's width, the nearest one, and the end of the row if the offset is at or past it. Group paging
  centered: a group centered in the viewport, the row's ends given that much room.
- What a finger does is **not** measured against the host, whose scroll view only takes a real touch: it is the port's own, made to
  feel as a scroll view does. The offset follows the finger; a drag ends where the finger's speed carries it (a deceleration of
  0.998 for each millisecond, a scroll view's normal rate) and, for the paging behaviors, settles on the next stop in the drag's
  direction (a single group or page at most, by a spring); past an end the offset gives with a scroll view's rubber band and returns. A
  drag begins only in the section, moving more along the row than across it, and the collection view's own scrolling waits for
  that to be decided; the device test drags with real touches.
- The handler is called when the layout is solved (for the last section first) and at every change of the offset, with the visible
  items (cells first, in the order the host gives them, then the supplementary items, then the rest), the offset (only `x` is held to the
  host) and the section's environment. A visible item has its `frame`, `bounds`, `center`, `alpha`, `zIndex`, `hidden`, `transform`
  (which is `transform3D`'s two dimensional part, and setting one sets the other), `name` (nil), `indexPath` and its element
  category and kind. What the handler sets is kept and shown, and is on the same object the next call: the frame follows the
  center.
- Nothing is solved again when the offset changes.

## Self-sizing

Measured the same way, with cells of these kinds (`compositional-cases.m`): one of constraints (a label of any number of lines), one
of frames that answers `sizeThatFits:`, one that cannot size itself, one whose only subview has a fixed intrinsic content size, one
whose `-preferredLayoutAttributesFittingAttributes:` sets the height, and one that adds to what its superclass answers.

- An item whose dimension is estimated is as large as the cell asks for on that axis, in the size the layout gives the other:
  a cell of constraints by fitting its content view compressed to that size (with the labels wrapping to the width they have been
  given), a cell of frames by `-sizeThatFits:` asked in the slot's size, and a cell that implements
  `-preferredLayoutAttributesFittingAttributes:` by what it answers. A cell that cannot size itself keeps the estimate.
- The item's insets are not taken from the estimated axis. A group's cross axis grows to its tallest item, whose neighbors keep
  their own heights. A fixed group keeps its size, and its items are measured all the same.
- Only what is in sight is measured, from the top of the visible items downward, each change of size moving the rest, so an item the
  measured ones push off screen is not measured; the rest is the estimate; a measured size stays until the layout is invalidated
  from outside (a reload, a change of the layout's size) or is measured at another width.
- The count-fixed vertical group divides its estimate among its items and does not measure them.
- A view is measured on the same steps as a cell of a self-sizing flow layout (`UICollectionViewSelfSizing.md`): the view is asked
  for `-preferredLayoutAttributesFittingAttributes:` with the attributes the layout returned, the layout is asked
  `-shouldInvalidateLayoutForPreferredLayoutAttributes:withOriginalAttributes:`, and the size is kept and the layout invalidated
  with the context `-invalidationContextForPreferredLayoutAttributes:withOriginalAttributes:` builds. The default of the cell
  (`-preferredLayoutAttributesFittingAttributes:` without an override) fits its content view with the estimated axes free and the
  others held at the size the layout gave, so a cell that overrides it and calls the superclass gets the same. The views are those
  the layout returned and are measured after the collection view has placed them (a hook on the collection view's own layout pass,
  which is run again, and one turn of the run loop after the layout); no cell is hooked. A header or footer the same way, in its
  kind and index path. What is waiting for a turn of the run loop holds the layout weakly, so a layout that is released first
  is not measured.

## A device-only hang, found and fixed 2026-09-23

`tests/backports/device/compositional.m`'s `useDragView:1` (orthogonal scrolling, self-sizing) ran
to completion on the iPad - nine checkpoints through the method, including one right after
`[drag_view layoutIfNeeded]` returns - but the next step, queued separately with
`dispatch_after`/`dispatch_get_main_queue()`, never ran: no crash, no uncaught exception. Band
11-12 localised this to between the two steps and excluded a hang inside the port's own
`charon_offsetOfSection:` (the stdout log is line-buffered and flushed after every write, so a
checkpoint at the entry of the next step would have appeared even if that step's body never
returned; it never appeared at all, meaning the step's block itself was never delivered). None of
the 26 checks that measured this layout on real hardware before this one exercised self-sizing
inside a live, drawn window - self-sizing needs a real view to measure, which the host oracle and
the build gate cannot provide - so nothing before this device run could have caught it.

What was found reading the port's own code, not measured on the device (the device is held by
11-12's own port work), and re-checked once more against a coordinator's reading of the same code
before this section was written: the two changes below are not two independent gaps, one primary
and one defensive - they are one mechanism, an unbounded reschedule of the settle pass, made into a
live lock by the run loop primitive `charon_note:` used to reschedule with.

**The loop, traced through `charon_settleMeasurements` (`UICollectionViewCompositionalLayout.m`).**
`_pending = nil;` runs unconditionally at the very top of the method, before anything is measured.
Nothing in the method - or in `charon_note:`, the only place that ever sets `_pending` again -
tracks how many times a settle round has already run for the same content. So any `charon_note:`
call that results from this round's own work, however it is triggered, finds `_pending` empty and
immediately calls `charon_layout_perform` to schedule another round: the batch this round is
processing is not exempt from re-triggering the next one. Two calls inside the method can trigger
it before the method even returns: `[self charon_solveView:view]`, called mid-loop for every
changed measurement but one, recomputes the full solved-section state unguarded by `_measuring` -
it does not call `charon_note:` itself, but leaves the layout in a state where the next attribute
query will, through `layoutAttributesForElementsInRect:`, for any element still short of its
estimate. `invalidateLayoutWithContext:`, called at the end for every accumulated preferred-size
context, *is* wrapped in `_measuring = YES` here, which blocks `charon_note:` for any query UIKit
answers synchronously while that context is being applied - one of the two paths is guarded, the
other is not.

Whether UIKit answers that mid-loop's pending query synchronously (closing the loop within this
one call to `charon_settleMeasurements`) or on its own next layout pass (closing it one run-loop
turn later, across two calls to `charon_layout_perform`) was not settled by reading source alone -
that is Apple's own `UICollectionView` internals answering, not this file. What *is* settled by
reading source alone: nothing bounds how many times this can repeat, on either timing, as long as
an orthogonal section's fixed measuring dimension keeps changing round over round. With
`CFRunLoopPerformBlock`/`CFRunLoopWakeUp` - the primitive `charon_layout_perform` used before this
patch - each reschedule forces the very next run loop pass to service it ahead of whatever else
that pass already had queued, which is exactly what turns an unbounded-but-eventually-terminating
retry into a live lock: a chain of rounds that keeps forcing itself to the front never lets the run
loop reach the point where it services a plain `dispatch_after`-queued GCD block, however many
passes go by. No crash and no exception is expected from this, and none was seen - the thread is
never blocked waiting on anything, it is continuously, successfully doing rescheduled work.

**Both changes are needed, and neither is the whole fix alone.** `_settleRounds`, reset on every
fresh `prepareLayout` and capped at 12, is what actually guarantees the chain ends - without it, a
configuration whose fixed dimension never converges reschedules forever regardless of which
primitive it reschedules with. Replacing `CFRunLoopPerformBlock`/`CFRunLoopWakeUp` with
`dispatch_async(dispatch_get_main_queue(), ...)` - the idiom every other deferred-to-main-thread
spot in this package already used, twenty of them, before this one - is what keeps every round,
bounded or not, from cutting in front of other main-queue work while it runs: even mid-chain,
before the twelfth round is reached, a `dispatch_after` block queued around the same measurement
now takes its fair turn on the same queue instead of being forced to wait for a pass that keeps
finding new work to service first. Twelve was chosen generously against every self-sizing
configuration this band has seen settle in one or two rounds, not measured against a real
non-converging case, since none was reproduced; `_settleRounds` logs once through
`charon_layout_say_once` if the cap is ever reached, so a configuration that genuinely cannot
converge is recorded rather than silently accepted as done.

Neither fix has been confirmed against the actual hang on hardware - the device is currently held
by band 11-12's own port work. This is reasoned from reading the code against the reported
symptom, not measured; band 11-12 should re-run `compositional`'s `useDragView:1` through
`runGestures:` once the device is free to confirm the tenth checkpoint now appears.

**Measured 2026-09-23, and it refutes half of the above.** Band 11-12 rebuilt `compositional` with
the same ten checkpoints, installed the canon carrying this patch, and ran it on the 4S. The
self-sizing path is genuinely fixed: what used to hang silently now runs to completion and reports
a real `FAIL` on a real size mismatch, not silence - `dispatch_async` demonstrably changes
behaviour there. But `DIAG 9: layoutIfNeeded returned` was again the last line logged; `DIAG 10`,
the entry into the next `gesture_step` after `useDragView:1`, never appeared, across two runs and
20+ seconds of waiting each time. **The `dispatch_async`/`_settleRounds` fix above closes the
self-sizing hang and does not touch the orthogonal-scrolling hang** - they are two different
mechanisms, not one, and the earlier "one mechanism" framing in this section was wrong about that.
`useDragView:1`'s own section (`HG(AB(200), AB(100), @[IT(FW(1), FH(1))])`) uses no estimated
dimension at all, so `charon_note:`/`charon_settleMeasurements`/`charon_layout_perform` - the
entire self-sizing settle chain discussed above - is never even entered for it; whatever stalls
this path is somewhere else in the port's own code, not there. Band 11-12 also flagged that its own
measurement is not airtight: the `printf`+`fflush` per checkpoint adds delay each pass, which could
have been enough for the self-sizing case's async round to land inside a narrow
`runUntilDate:0.01` × 6 polling window - "the self-sizing path is independent of the
instrumentation" is not proven, only "it now completes instead of hanging under this harness."

## What looked like a second hang, orthogonal scrolling, was the stand crashing (2026-09-23)

After `useDragView:1`, `DIAG 9` was the last line and the next queued step never ran. That was
not a hang, and not the port. Measured on the 4S: a sampler thread that writes with a raw
`write(2)` and calls nothing but mach functions fell silent at the same moment as one calling
`CFRunLoopCopyCurrentMode` and one calling `printf`, and the process was gone about ten seconds
after launch. A handler on an alternate stack caught SIGSEGV on the main thread in
`objc_msgSend`, called from the test's own `run_next` (`device/gesture.m`) as the first
`dispatch_after` step ran. The stand had been built through `@addon/charon/app` without
`-fobjc-arc`, so `gesture.m`'s static `queue`, an autoreleased array, dangled once the pool
drained. Such a death leaves no crash report on this stand, which is why three runs read it as a
hang. Built with ARC, the gesture phase runs to its end: `checks=46 failures=10`, real
differences, each followed up on its own.

This retracts the reentrancy hypothesis: that adding the section's pan recognizer from inside the
collection view's first `-layoutSubviews` stalled the run loop. The `dispatch_async` deferral
written for it and its three `CHARON-DIAG` lines are gone, and the recognizer is set up
synchronously again. Measured on the 4S with the ARC-built stand, one
band's `libUIKitBackports.dylib` from the same tree swapped in each way: deferred and synchronous
give the same 36 passing checks and the same 10 failures, detail for detail, and neither process
takes a signal.

It also qualifies the section above. The self-sizing hang was measured on the same stand, built
the same way, so how much of it was the port's is open until it is measured again with ARC; the
two changes made for it are kept, since each is right on its own reading.

**`_settleRounds` was unreachable by construction - fixed.** The cap was reset in `-prepareLayout`,
which runs on every genuine solve - including the one the settle pass's own
`-invalidateLayoutWithContext:` triggers (it sets `_solved = NO` when `_applyingPreferred` is set,
which is exactly what makes the next `-prepareLayout` take the "real solve" branch that used to
reset the counter). A cap that resets itself every time the thing it is capping runs again never
fires. Moved the reset to the plain `-invalidateLayout` override instead - the path a reload, a
bounds change or a configuration change takes, never the one the settle pass's own
`-invalidateLayoutWithContext:` takes - so the round count now actually accumulates across a chain
of settle rounds instead of restarting at zero on each one. This is the same class of defect this
band already found once in this same file (an unbounded reschedule with no way to terminate),
found while reading for the stand's crash and real on its own.

**`NSLog` does not reach ASL from a process launched through `sblaunch`** after `uicache -p`
registration: the live store (`/var/log/DiagnosticMessages/<date>.asl`, not the empty
`/var/log/asl/`) had entries from other processes in the same minutes and none from this one. A
device stand reports through `printf` into its redirected `stdout`.

## The device run held to the recording (2026-09-23)

With the stand built with ARC, `device/compositional.m` on the 4S failed 10 checks. Five were the
test's own (fixed in the test); the rest came to three causes, each measured on the 4S.

**iOS 6 loses an element whose frame spans the rectangle it checks - the layout works around it by answering it twice.** iOS 6's
collection view asks its private `UICollectionViewData` which elements its bounds show; that object asks the
layout for `_validLayoutRect` (the bounds cut to the content, the rectangle `-layoutAttributesForElementsInRect:`
receives) and files each answer under the pages of its frame's four corners (`_screenPageForPoint:`, a corner
outside the rectangle has no page), so an element reaching past both ends of that rectangle is under no page inside
it and never gets a view. A plain `UICollectionViewLayout` subclass shows it with iOS 6's own code: with content 244
in a 320 x 480 view, frames {234,-1,160,246} and {10,-10,100,260} get no cell, {234,-1,160,240} and {234,3,160,242}
do; with content 480, {10,-10,100,500} gets none. The transform plays no part: 0.3 of "modified at 250", turned by
0.3 rad, has the bounding frame {202.7,-15.4,222.6,272.7}, and the same frame with no transform is lost too, while a
smaller turn or scale is shown. The system's layout shows it.

**This is a workaround, not a repair, and it is a crutch on record** (`coordination/crutches.md`, "charon: compositional layout
answers an element spanning the bounds twice on iOS 6"). It rests on the private object keeping the last attributes it was
given for an index path (`[attributes copy]` in an array of its own by the element's index; the pages hold only which indexes
to look at). No document of Apple's names that order; it was measured, not specified. The layout therefore gives an element
that reaches past both ends of the rectangle a second attributes first: the same element, its frame cut to the rectangle
(`CGRectIntersection` with the bounds cut to the content), which has corners inside and files the index, and then the attributes
with its own frame, which the object keeps. The cause, the page filing by frame corners, is not repaired: a plain
`UICollectionViewLayout` still loses the element in the same process, and the layout's public answer is wrong on purpose. A
caller on iOS 6 that asks the layout for the rectangle itself sees that element twice, the cut one first and the element's own
last. Only cells (category 0) are given one: supplementary and decoration attributes are not filed under pages.

Why there is no other public way. The filing is inside Apple's object, which the workspace does not own, and the two things a
layout hands it are the attributes and the content size. The rectangle is the bounds cut to the content and the frames are the
true frames, so changing either changes what the user sees; a size, centre or transform compensation would give the cell cut
bounds and lay its content out wrong (reasoned, not measured). PSTCollectionView's `PSTCollectionViewData` (MIT) has no page
filing and answers what the layout answers, which is the semantics iOS 6 lacks, but it replaces the collection view: an app's own
`UICollectionView` cannot be given that path, and the only ways to put it under `UICollectionView` are the replaced private method
(the earlier repair, removed) or a class swap. A measurement that would overturn this is a public knob that reaches the filing
with the true frames; none is known.

Measured on an iPad 2 (6.1.3) with a plain layout and the release's UIKit alone (`device/cvpages.m`, run 2026-09-26 and
`.agent-work/runs/cvdata/probe`, `probe-x`): with the true attributes only, the four frames above give two cells; with the cut
one first, all four, each at its own frame; with the cut one last, four cells at the cut frames, which is the last-wins storage.
The same holds along x (content 244 in a 480 x 320 view, the four frames transposed: two cells, four at their own frames, four
at the cut frames), so both branches of `charon_spans` are measured. Not measured: iOS 6.0 and 7 to 10 (no such device; the
iPad 2 and the 4S both run 6.1.3, and the release check `NSFoundationVersionNumber <= 6.1` cannot tell 6.0 or 5.x from it). The
workaround is done for iOS 6 only; the class has the same selectors and ivars in every armv7 cache to 9.3.6, but whether the
object loses the element on 7 to 10, and whether it keeps the last attributes there, is open, and a second attributes on a release
whose storage was not verified could show two cells, so the gate is not widened.
`device/cvpages.m` holds it on the compositional layout (17 checks, iPad 2), and the `compositional.m` stand gives the same
43 checks with the same two failures with this layout as with the one that repaired the answer of the private object.

**The recording's font is not the device's.** `compositional-sized-expectations.h` was written on the
host, where the system and the port measure a label in the same font (SF). The device's is
Helvetica. At label width 272 (item and section insets) Helvetica 15 sets the two long texts in lines
270 and 271 pt wide, 2 and 3 lines; SF at the recording's 0.77 scale wraps them at 279 and 281 and
so has 3 and 4 - the only font of those tried that fits all five recorded widths (304, 284, 272,
224, 141.5). The port measures the label at 272, the width the cell gets. Helvetica Bold 17 has a
21 pt line where the recording has 20 (the header and footer case). The test now takes, for a list
of label cells, the height the device's font gives each text at the width the system laid it out at,
moves what lies below by the difference, and prints a `note` naming each changed height.

**armv7's `CGFloat` is a float.** The orthogonal lines are the host's doubles printed with `%g`; the
device's cos(0.3) prints 0.955337 against 0.955336. Those lines are compared to one unit in the
sixth significant digit.

With the three, the stand answers `ok checks=43 failures=0` on the 4S (canon `0.8.10+e302673e`, this
tree's one-band `libUIKitBackports.dylib` swapped in); with the canon's own library the same stand
still fails "modified at 250".

## What the port cannot do

- **Nested scrolling is done, and is the port's own.** iOS 6 has no scroll view to nest in a section, so the port moves the section itself: a pan
  recognizer on the collection view drives an offset for each such section (see Orthogonal scrolling, below). Where it differs from
  the host: the cells are children of the collection view and not of a scroll view of the section's own, so a cell is not clipped
  to the section's frame, and one the handler moves entirely off the collection view's bounds is not shown (the host shows it,
  outside its scroll view's bounds, where nothing can be seen anyway); the offset `y` and the container the handler is given while
  the section scrolls are the host's scroll view's own (the section's position and a container of its own size), the port gives
  `(offset, 0)` and the collection view's container; a list of visible items may hold, as the host's does, an item that has just
  scrolled out, and the port's holds only what is in sight; there is no scroll indicator, and no `orthogonalScrollingProperties`
  (17.0).
- **Self-sizing is done by measuring displayed views** and, of the estimates, only those of items and of the boundary supplementary
  items (headers and footers) are measured: an estimate on a supplementary item of an item or of a group stays its estimate. A
  view is measured only after the collection view has laid it out, once for each width (or height) it was measured at.
- The layout runs left to right: leading is left, and `flipsHorizontallyInOtherLayoutDirection` is not carried.
- iOS 6's collection view has no invalidation contexts of its own (`UICollectionViewInvalidation.md`): a bounds change is
  answered by `-shouldInvalidateLayoutForBoundsChange:` and `-invalidateLayout`, and the context of a measured view is applied with
  `-invalidateLayoutWithContext:`, which solves the layout again.
- The port does not supply the attributes for appearing and disappearing items that the host's layout does; the base class answers.
- `visualDescription`, and the members of later releases, are absent (`NSCollectionLayoutItem.md`).

## Where the port differs, measured

The random layouts of the differential test (`CHARON_FUZZ_ROUNDS`) put a description together from the features above and compare the
two answers. With one feature at a time, from about one layout in twenty to none differs; with all of them at once about three in ten
do, nearly all in the situations below, which the fixed layouts do not reach:

- A row that mixes lengths and fractions of the width, while some item takes its height as a fraction of the width, can be packed by
  one item differently, and a row whose items disagree about the axis they are measured along in the direction of the row is not held
  to the host.
- A nested group whose first item does not fit in it: the port leaves the nested group empty; the host's answer varies.
- A layout with boundary items whose sections are all empty, and boundary items given offsets in a section with no room.
- An item whose insets exceed its slot on both sides in a very narrow slot.
- The host keeps the pinned positions of sections that are out of sight from the last time they were in sight; the port computes
  them all. Nothing in sight differs, and the differential test only compares what is in sight.
