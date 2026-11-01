# Driving a React Native host by touch

A phone on iOS 6 has no XCUITest, and a synthesized `UIEvent` sent through `-[UIApplication sendEvent:]` faults inside UIKit
because the event has no `GSEvent` behind it. `frameworks/ReactNative/host/RNHostTouch.m` is the injector that gets around
that, and `frameworks/ReactNative/tools/touch.lua` is the command line for it.

## How it works

Link `RNHostTouch.m` into the host application. Its `+load` waits for `UIApplicationDidFinishLaunchingNotification` and then
polls `/var/tmp/rnhost.cmd` every 0.3 seconds. It reads one command, empties the file (the folder is sticky and owned by
root, so the file cannot be removed) and appends the answer to `/var/tmp/rnhost.cmd.out`.

The injector does not go through `sendEvent:`. It builds a `UITouch` with the private setters of iOS 6
(`_setLocationInWindow:resetPrevious:`, `setView:`, `setWindow:`, `setTapCount:`, `setIsTap:`, `_setIsFirstTouchForView:`)
and calls `touchesBegan`, `touchesMoved` and `touchesEnded` on the enabled gesture recognizers of the views under the point
whose class name starts with `RCT` or `RNG`. That reaches React Native's own touch handler and the gesture handler, not a
native `UIScrollView` pan or a `UIControl`.

## Commands

| Command | Does |
| --- | --- |
| `tap X Y` | a tap at the point, in points of the 320 by 480 screen |
| `swipe X1 Y1 X2 Y2 [MS]` | a drag from one point to the other |
| `scroll X Y DY` | moves the content offset of the scroll view under the point |
| `taptext LABEL` | taps the view whose `accessibilityLabel` is LABEL |
| `text STRING` | inserts the text into the focused input |
| `key delete` | deletes one character |
| `methods CLASS` | lists the methods of a class, for finding private selectors |

## Running it

With the phone claimed:

```
./xmakew l frameworks/ReactNative/tools/touch.lua --before before.png --after after.png taptext "Direct connection"
```

`--before` and `--after` take a screenshot of the phone before the command and after `--wait` seconds (4 by default). The
tool prints what the injector answered. A command with a wrong verb, a wrong number of arguments, a non-number coordinate or
a quote in the text is refused before anything is sent.

## Limits

The injector uses private API of iOS 6.1.3 and is for a test phone only. Taps on native controls (`UIButton`, a native
`UIScrollView`) are not delivered; React Native components are.
