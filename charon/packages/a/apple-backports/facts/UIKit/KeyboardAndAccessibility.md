# Key commands, custom accessibility actions and the accessibility settings, iOS 7 to 9

Source: the host's own UIKit, recorded for the constant values, the defaults, the copies and the archive, and held against the
port by the checks of `tests/backports/device/uikit2.m`.

## Key commands (iOS 7)

`UIKeyCommand` is made with `+keyCommandWithInput:modifierFlags:action:` (iOS 9 added a discoverability title, which is
kept) and answers its input, modifier flags and action. A command made with `init` has no input and the action `_nop`, as the
system's does; a copy is another command with the same fields; two commands with the same input, flags and action are equal;
the class supports secure coding. The five arrow and escape inputs (iOS 7) and the page inputs (iOS 8) are the names of
their constants. `UIResponder.keyCommands` answers `nil` unless the application overrides it.

iOS 6 does not ask a responder for its key commands: a hardware keyboard reaches an application as text through the
first responder, and nothing calls a key command. The class and the property are `inert`. The properties iOS 13 added to the
class - the title, the image, the property list, the attributes, the state and the alternates - are carried with the class becoming a
`UICommand` (`UICommand.md`); iOS 15's are in `UIKeyCommandPriority.md`.

## Custom accessibility actions (iOS 8)

`accessibilityCustomActions` is a read-write property of `NSObject`, `nil` by default, that keeps a copy of what it is
given. The SDK declares it for iOS 8. `UIAccessibilityCustomAction` is not a class of the release (measured below).

Measured on the 6.1.3 guest (iPhone4,1, 10B329) by `tests/backports/emulate/nsobject-custom-actions` (`probe.m`,
`xmake emulate ... run /usr/libexec/nsoprobe` and `nsoprobe-category`, 2026-10-16):

- The release alone, with UIKit loaded: `UIAccessibilityCustomAction` answers no, and `NSObject` has no
  `accessibilityCustomActions` and no `setAccessibilityCustomActions:`. The release's cache holds a getter, and the probe
  finds it only after a framework that UIKit does not load is opened: `UIAccessibility.framework` answers it, and the
  setter is still absent. The getter of a fresh object answers `nil`. So the release's own answer is read-only, and
  the release does not behave as the API is declared to.
- The port's `UIKit/UIAccessibilityCustomAction.m` in the same process, before any framework is opened: set then get
  answers the same array, another object answers `nil`, and setting `nil` answers `nil`.
- With the port's category and no re-assert, the release's getter attaches in front of the port's when
  `UIAccessibility.framework` is opened: set then get answers `nil`. A dyld add-image hook is too early for this: it
  runs before objc attaches the release's category (measured: the port's getter was still in front inside the hook).
  6.1.3 has no hook after the attach.
- So the port's setter puts its two accessors back in front whenever the visible getter is not its own, and then
  stores. Measured after `dlopen` of `UIAccessibility.framework`, on the same guest: set then get answers the same
  array (`same-object=1`), another object answers `nil`, and setting `nil` answers `nil`.
- The residual, measured in the same run, is closed by a queued put-back. `_dyld_register_func_for_add_image` is
  called for `UIAccessibility.framework` before objc attaches the release's category, so the put-back is queued on the
  main queue and runs after the attach. Measured: a value stored before the dlopen reads back as `nil` straight after
  the dlopen (the release's getter still answers until the main queue turns), and as the same object after the main
  queue has turned (`same-object=1`). A caller that reads straight after the dlopen, on the same thread, still sees the
  release's getter; the window closes when the main queue runs.

So the port answers the property's get and set after the release opens `UIAccessibility.framework`, once the main queue
has turned, and a set re-installs the port's accessors as well. VoiceOver of iOS 6 lists no custom actions and does not
read the values, which is not measured here.

`accessibilityElements` and `accessibilityNavigationStyle` are not decided by this section: the port builds them as
stand-ins in the same file, and their rows stay `owed` until they are measured.

## The attributed name of a custom action (iOS 11)

`UIAccessibilityCustomAction.attributedName` and
`-[UIAccessibilityCustomAction initWithAttributedName:target:selector:]` were registered `absent` with the reason
"this release's VoiceOver never asks the question the member answers", which is the reason every member of this
class carries, including the four that were already undecided, so it was a reason that could never decide anything.
Both are `implemented`, in `UIKit/UIAccessibilityCustomAction+AttributedName11.m`.

**What it is: the name, styled.** The plain name is the string and this file keeps the style, so the two are one
name in two spellings and neither is a second source of truth for the other. That arrangement is what makes
`-setName:` work without this file touching the class's own setter, and it is not a choice: a category cannot
override the method the class itself implements, so moving the string across in both directions from here would
either lose the plain write or call the plain setter in a loop. Deriving the string from the plain name is the
third arrangement and the only one that has neither defect.

Recorded from the host's own UIKit under Mac Catalyst by `tests/backports/host/uikitconst`, over the ten cases
added to `device/uikitconst-cases.m`, which the device test reads out of `device/UIKitConstants-expectations.h`:

| the host's answer | key |
|---|---|
| an action made with a plain name ALREADY has an attributed name, and its string is that name | `action.attributedNameString` |
| setting the attributed one sets the plain name | `action.nameAfterAttributedNameSet` |
| the plain setter leaves the attributed name describing the same action, keeping the style | `action.attributedInitStringAfterNameSet` |
| `initWithAttributedName:target:selector:` keeps the attributes it was given | `action.attributedInitKeepsAttributes` |
| and the target it was passed | `action.attributedInitTargetIsSame` |
| an action made with a nil name still has an attributed name, and it is not nil | `action.attributedNameWhenUnset` |

That last one is the case the first version of this got wrong, and it is why the case exists. The getter
answered `nil` when the plain name was `nil`, on the reasoning that there was no string to describe. Measured
on the host, an action from `-initWithName:nil target: nil selector: NULL` answers a `name` of length 0 and
an `attributedName` that is set and whose string is empty -- the system's own substitutes the empty string
where the port substituted nil. The getter now answers an empty string over that name, which is what the host
answers.

Whether `-name` itself is `nil` for that action is the 8.0 class's own question, its row is `inert` in
base.json, and this series does not touch it; the case above therefore records only what the 11.0 member
answers. A separate measurement of the class's own name is a question for whoever owns that row.

**What has not been run.** The host half ran: `tests/backports/host/uikitconst` records all ten, and the
regenerated `device/UIKitConstants-expectations.h` is the tracked file plus exactly those ten keys — 81 entries
where the file held 71, none removed and none of the 71 changed. The device half did **not** run, and no verdict
is claimed for it: it is the device test that holds this port to those answers, and a reviewer should not read
this section as a device result.

What did run for the port is the logic, which is a weaker claim and is stated as one. The port's class
re-implements a class the SDK declares, so on this host the framework's own class wins and the port's category
would never be called — a probe under the real name measures the SDK, not the port. So
`.agent-work/runs/uikit11/probe/probe.m` runs the port's base class and the port's new category verbatim under
another name and checks they produce the recorded answers: ten of ten agree, exit 0. Its negative control is the
defect this arrangement exists to prevent — a getter that stops reading the plain name, which is one line, and
which the probe turns into two failures and exit 1.

## Accessibility settings (iOS 8, 9)

iOS 6 has none of bold text, grayscale, reduce motion, reduce transparency, darker system colours, speak screen, speak
selection and switch control, so the functions that ask about them answer `NO`, and the notifications that would say
they changed are carried and never posted. Shake to undo is always on in iOS 6, so `UIAccessibilityIsShakeToUndoEnabled()`
answers `YES`, as the host does; and there is no element with an assistive technology's focus, so
`UIAccessibilityFocusedElement()` answers `nil`. The values of the constants, and of the two numbers that pause and resume
an assistive technology (1033 and 1034), are the host's.

## The URL of the settings of an application (iOS 8)

`UIApplicationOpenSettingsURLString` is `app-settings:`. iOS 6 has no settings page for an application and no handler
for that scheme, so `-openURL:` on it answers `NO`, which an application that checks `-canOpenURL:` first already handles.

`UIApplicationOpenNotificationSettingsURLString` (15.4) is `app-settings:notifications` (`UIKit/UIApplicationConstants15_4.m`), the
string UIKitCore exports in the 16.0 cache (`tools/corpus/cache-value.lua` on the 16.0 cache, `UIApplicationOpenSettingsURLString`
read as `app-settings:` beside it as the control); 12.0 exports neither this nor anything of that name (`tools/corpus/cache-value.lua` on the 12.0 cache). It is the same
scheme, so `-openURL:` answers `NO` for it too: iOS 6 has no notification settings of an application to open.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked `UIApplicationOpenNotificationSettingsURLString` read through the library's export: `app-settings:notifications`.
