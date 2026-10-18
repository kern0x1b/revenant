# The animation pair of CGAnimateImage...WithBlock, on a release whose ImageIO has no animation call

`CGAnimateImageAtURLWithBlock` and `CGAnimateImageDataWithBlock` arrived in iOS 13. Every release this port
deploys has an ImageIO that can open a file and decode a frame of it, and none of them has these two calls,
so they are carried in `Graphics/ImageIOAnimation134.m` over the release's own `CGImageSource`.

## Which release this object is, and why not 13.0

`tools/cache-index/first-rung.lua` puts `_CGAnimateImageAtURLWithBlock` and `_CGAnimateImageDataWithBlock` at
**13.4**, and on no rung below it. `--rungs` over the 54 held rungs (re-measured 2026-10-18) gives 13.4, 16.0, 18.0
for each: the held rungs at or above 12.0 are 12.0 (absent), 13.4, 16.0 and 18.0. The SDK annotates the pair
`IMAGEIO_AVAILABLE_STARTING(10.15, 13.0)`, but no held cache sits between 12.0 and 13.4, so 13.4 is the measured
boundary and the annotation is not used. The three data symbols `_kCGImageAnimationDelayTime`,
`_kCGImageAnimationLoopCount` and `_kCGImageAnimationStartIndex` are also first held at 13.4.

Retracted: the 2026-10-03 text said `kCGImageAnimationStartIndex` is in no held rung. That was the name without
its leading underscore, which is not the data symbol; the symbol `_kCGImageAnimationStartIndex` is answered at 13.4.

The object was 16.0 on 2026-10-03, placed when the ladder had no rung between 13.0 and 16.0. It is now
`Graphics/ImageIOAnimation134.m`, with its registry rows at 13.4. The BC names were moved to a 13.4 band the same
way (`ImageIONames134.m`). The three animation constants stay in `Graphics/ImageIONames130.m`: all 22 names of that
file are first held at 13.4 (measured 2026-10-18, the same `first-rung.lua` run), so its 13.0 band label is wrong
too. Moving that file touches its 22 registry rows, this facts file, `Metadata.md` and the imageio-names harness, so
it is a separate decision, left open. An object holds the API of the release that first exports it, measured from
the held caches and not from the annotation.

It is a new object of a family GraphicsBackports already carries twenty-eight objects of, and it is not a
split of anything: nothing else in the tree defines either function.

## What the host answers, measured

`tests/backports/host/imageio-animate/` is the differential, and it exists because nothing in this tree
compared these two functions with anything before it. `cases.m` is compiled twice, once against the host's
own ImageIO and once against this object, and `run.sh` compares the outputs line by line over one set of
fixture files that `write-gifs.m` writes once, before both builds:

    COMPARED: 397 records, 0 differ, 0 declared in known-differences.txt
    GREEN: every record answers what the host answers
    TIMING: the five gaps of two loops are the delays the file declares (0.10, 0.30, 0.50, 0.10, 0.30) in 20ms buckets, and the first frame is drawn at once
    imageio-animate: 397 records compared, 0 declared differences, mutation RED

The fixture is a three-frame GIF whose frames declare **different** delays - 0.1, 0.3 and 0.5 seconds - plus
a one-frame GIF, a PNG and a three-page TIFF. Everything below is what the run compares.

| what | measured on the host |
| --- | --- |
| the call returns before the first frame is drawn | for a two- and a three-frame file the host answers 0 with **no call at all**, and the first call arrives within a millisecond of that return |
| a ONE-frame file | the frame is drawn **inside** the call, and a `kCGImageAnimationLoopCount` of 3 still draws it **once** |
| frame order | the file's own, wrapping: 0, 1, 2, 0, 1, ... |
| the frame handed to the block | the frame the release's own decoder gives at that index (the harness compares the first pixel's three bytes, not the index) |
| the delay between two calls | **the delay the frame just drawn declares**, read out of that frame's own `{GIF}` dictionary: 0.104, 0.301, 0.507 measured for a file declaring 0.1, 0.3, 0.5 |
| which delay key | `kCGImagePropertyGIFDelayTime` and not `UnclampedDelayTime`: a file written with 0.005 answers DelayTime 0.1 and UnclampedDelayTime 0.01 and is drawn at 0.104 |
| a frame with no delay of its own | the release's own dictionary answers 0.1, which is ImageIO's default and needs nothing invented |
| looping | forever, unless `kCGImageAnimationLoopCount` says otherwise: one loop of a three-frame file is exactly three calls, two loops are exactly six |
| the file's own `kCGImagePropertyGIFLoopCount` | **not read**. A file that says "forever" and a file that says "one loop" both animate forever with no option given |
| `kCGImageAnimationStartIndex` | read: 1 on a three-frame file draws 1, 2, 0, 1. A negative index draws from 0 |
| `kCGImageAnimationDelayTime` | **read out and not used**: the host ignores it. The same file with the option at 0.02 and at 2.0 gives 0.104 / 0.301 / 0.507 both times |
| `*stop` | ends the animation: set on the second of three calls, the third never comes |
| a PNG, a JPEG, a **three-page TIFF** | `-22141` (`kCGImageAnimationStatus_CorruptInputImage`) with no call at all, so a frame count is **not** what decides it |
| a one-frame GIF | 0, drawn once |
| NULL data or NULL url | `-50` (paramErr) |
| an empty options dictionary | no loop count, so the file wraps |

## Two cases the host does not survive, and why they are PORTONLY records

A **NULL block** is answered 0 and then the host **dies** when the run loop turns (measured 2026-10-03:
"returned 0", no spin printed, SIGSEGV). A **`kCGImageAnimationStartIndex` at or past the frame count** is
answered 0 and then the host **traps** (SIGTRAP, exit 133; measured for index 2 on a two-frame file and for
index 9 on a three-frame one).

Neither is a behaviour to carry - a crash is not an answer - and neither can be compared, because the host
build has to survive the run for there to be a comparison at all. So both are `PORTONLY` records in
`cases.m`: the port answers 0 and draws nothing, the harness records the port's own answer, and the host's
is named beside it. That is why `known-differences.txt` for this harness has no case in it and says why.

## The timing is compared in buckets, and why

A run loop that fires a timer early or late is not ImageIO's behaviour, and a gap printed to the microsecond
would compare the scheduler. So each case prints its gaps **rounded to 20 ms**, and `run.sh` then requires
that the five gaps of the two-loop case are 0.10, 0.30, 0.50, 0.10, 0.30 - the delays the file declares -
and that the gap before the first frame is "first", because that frame is drawn at once. A delay that was
read from the wrong frame, or not read at all, falls out of those buckets.

## The two mutations

`run.sh` plants two changes in the port's own source and fails if the comparison does not move:

1. `_index = index;` instead of `_index = index + 1;` - an animation that draws the same frame for ever.
2. the delay read from frame 0 for every frame - which is the mistake that a table or a name would hide,
   because the frame order and the count still come out right.

## What this cannot do

An **APNG**. The header names GIF and APNG as the supported formats, and a release whose ImageIO carries no
APNG decoder cannot decode one, so the frame this object draws is whatever the release's own source hands
back; a file the release cannot read is the `-22141` above. The object says so rather than pretending the
format is covered.

## The port's own class, registered

`CharonImageAnimation` holds the source, the block, the frame index and the timer of one animation. No SDK
header declares it, so it carries one registry row of its own - `registry/ImageIO/animate134.json`, status
`owed`, the shape `registry/Metal/ios80classes.json` uses for a class of the port's own, because the ledger is an SDK
ledger and nothing is claimed about SDK behaviour with a name no SDK header declares. The class's methods are built in
`Graphics/ImageIOAnimation134.m`, but on the gate's 6.1.3 build the class symbol is local (`s`, not `S` in the dylib's
nm), and the registry check counts only exported class symbols, so the row stays owed until that symbol is exported. The two
functions' rows are in `absent_ImageIO.json`, where they already were.