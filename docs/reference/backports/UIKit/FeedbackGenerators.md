# UIKit feedback generators on iOS 6

`UIFeedbackGenerator` and its three subclasses (`UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`,
`UISelectionFeedbackGenerator`) are iOS 10 API. Their Swift members are lowered for an iOS 6 target
(`frameworks/Backports/tools/lowered-members.txt` lists the classes), and their Objective-C implementations are in
`frameworks/Backports/src/UIKit/`. iOS 6 has no Taptic Engine and no haptic engine: the shims vibrate through the
vibrator the phone already has, and do nothing where it is absent. Everything here is read from the source; nothing has
been run on a device.

## Motor

`revenant_feedback_motor_present` (`UIFeedbackGenerator.m`) loads `FigVibratorIsVibratorAvailable` from CoreMedia with
`dlsym` and caches the answer. If the symbol is missing or reports no vibrator, no call plays. The iPhone 4S has the
vibrator; the iPad 2 has none, so its feedback is silent.

## Playback

A call that plays goes through `AudioServicesPlaySystemSoundWithVibration` (AudioToolbox, `dlsym`) with sound ID
`0xFFF` (`kSystemSoundID_Vibrate`), a `VibePattern` array of millisecond durations that alternate on and off and start
with on, and an `Intensity` value. Whether iOS 6 uses the `Intensity` key is not measured.

## What each call does

| Call | Pattern (on and off in ms) | Intensity |
|---|---|---|
| Impact, style light | on 40 | 0.45 |
| Impact, style medium | on 65 | 0.70 |
| Impact, style heavy | on 100 | 1.00 |
| Impact, style soft | on 60 | 0.30 |
| Impact, style rigid | on 30 | 1.00 |
| Impact, `impactOccurred(withIntensity:)` | the style's pattern | the style's intensity times the given value, clamped to 1; nothing at 0 or less |
| Notification, success | on 55, off 90, on 55 | 0.55 |
| Notification, warning | on 55, off 90, on 110 | 0.75 |
| Notification, error | on 70, off 70, on 70, off 70, on 70 | 1.00 |
| Selection, `selectionChanged` | nothing | |
| `prepare` on any generator | nothing | |

The location variants (`impactOccurred(at:)`, `selectionChanged(at:)`, `notificationOccurred(_:at:)`) ignore the
location and call the plain method. An unknown impact style plays nothing.

## Where the Expo module uses them

`expo-haptics` (`packages/e/expo-haptics`) calls `impactAsync` and `notificationAsync` on these generators, so an impact
or notification vibrates and a selection does nothing. Its status and what it is missing are in
[the React Native coverage table](../../react-native/coverage.md).

## Not measured

- Whether iOS 6 honours the `Intensity` key, so whether light and heavy feel different or only last for different times.
- Whether each pattern is felt on the phone, and whether a vibration is cut short when another one starts.
