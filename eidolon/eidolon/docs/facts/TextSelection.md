# `TextSelection` on iOS 6, and the one range the release can carry

`TextSelection` is the value SwiftUI 26.2 puts in `EnvironmentValues.textSelection`: an `Indices`
(`selection(Range<String.Index>)` or `multiSelection(RangeSet<String.Index>)`), an `affinity`, and
`isInsertion`. The port declares Apple's shape exactly
(`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:20146`) and hands the selection to the
`UITextView` of the editor node.

**The release carries one range.** The 26.2 UIKit header says so in its own words
(`iPhoneOS26.2.sdk/System/Library/Frameworks/UIKit.framework/Headers/UITextView.h:227-232`):

```objc
/// A union of all the `selectedRanges`.
@property(nonatomic) NSRange selectedRange API_DEPRECATED_WITH_REPLACEMENT("selectedRanges", ios(2.0, API_TO_BE_DEPRECATED));
@property(nonatomic, copy, nonnull) NSArray<NSValue *> *selectedRanges API_AVAILABLE(ios(26.0), tvos(26.0), visionos(26.0), watchos(26.0));
```

`selectedRange` is the whole selection from iOS 2.0, and the first API that holds more than one range
is `selectedRanges` in **iOS 26.0**. iOS 6.1.3 predates that by twenty years, so a `TextSelection` with
several ranges is stored, handed out and read back as **the lowest of them**: `TextSelection.nsRange(in:)`
walks `RangeSet.ranges` and takes the range with the smallest `lowerBound`, and
`TextSelection.init(nsRange:in:)` puts the text view's one range back as a `TextSelection` (a range the
text does not have comes back as a caret at its end). Both are the port's own and are internal, since
they are not 26.2 API.

There is no device measurement here: `run-emu.sh` and `snapshots.sh` both need the emulator, which is
`emulate-launch`'s `xmake emulate` and not on this machine. What is measured is the SDK's own
availability annotation, quoted above, and the port's own header for the 6.1.3 toolchain
(`eidolon/bridge/fw/`, the interface of iOS 16.4), which likewise has no multi-range selection on
`UITextView`.
