# The voice control: a program's own states, and a template that draws them

**Eleven rows, and every one of them is a measurement rather than a hardware absence.** The two
classes are present in Apple's own CarPlay with no head unit attached, they are the program's own
objects, and every one of their answers was read off Apple's object before the port's was written.
`CPVoiceControlTemplate.h` says so in its own words: "Your app may initialize the voice control
template with one or more states, and you may call `activateVoiceControlState:` to switch between
states you've defined." A car adds a screen to show the result on and nothing else; there is none
here, so the port draws the result in the release's own UI, which is what every other CarPlay
template in this library does.

## What Apple's object answers with no head unit, and what the port has to answer identically

From `tests/backports/host/carplay/run.sh`, which builds `headunit-probe.m` against Apple's CarPlay on
this Mac and the port's own sources under `charonHost_` names, prints `label<TAB>answer` from each and
**diffs the labels both carry**. The run is green at `checks=33 failures=0` for Apple's side,
`checks=20 failures=0` for the port's, `compared 15 answers, all identical`, and both mutants are red
— the host's five-state limit read as six, and the port's own limit read as six. A green run that
cannot fail would decide nothing, so each half carries a plant that makes it fail.

The fifteen answers they share, and what each one decided:

| answer | what it decided |
| --- | --- |
| the template keeps **5 of 6** states | the header's "maximum of 5 … only the first 5 will be available" is enforced, on both sides |
| the first state given is the active one | "By default, the Voice Control template will begin on the first state specified" |
| activating with **no car and no presentation switches the state** | the header's `@warning` that activation "will have no effect" before presentation is about what a car then shows, not about the object's own state. Measured on Apple's object, and the port matches it |
| an identifier **no state carries** still becomes the active one | Apple's object does not validate the identifier, so neither does the port's. Drawing then has no state to draw, and nothing is drawn |
| **12 of 12** activations in a tight loop take effect | the header's rate limit ("will ignore voice control state changes that occur too rapidly") is about the presentation too. There is no interval in the object and none is invented |
| a nil array of states answers nil for both | a `?: @[]` would be a quiet different answer: Apple's object answers nil, and so does the port's |
| an empty array keeps an empty array and no active state | an empty array and a nil array are two different answers and the port keeps them apart |
| an image over 150 points comes back **150 by 150** | the header's "Voice Control state images may be a maximum of 150 by 150 points" is enforced by the framework, so the port enforces it too: a larger image is redrawn at the limit, keeping its shape |
| `titleVariants` answers **nil** when it was given nil | the header declares it `nullable, copy` |
| the state survives an NSSecureCoding round trip with its identifier | `+supportsSecureCoding` is YES on both sides, and the value decodes |

Four of those are answers the header's prose does not give, and two of them (`12 of 12`, the
unvalidated identifier) contradict a reading of the warning. That is the point of measuring: the
rows say what the framework does, not what the prose suggests.

## What the port draws, and where

`CarPlay/CarPlayVoiceControl12.m`, one object for the 12.0 rows, with the tree's own conventions: the
template's view controller is asked for through `charon_viewControllerForInterfaceController:`, the
same hook `CarPlayTemplatesView12.m` and `CarPlayTemplatesMore12.m` use, and every helper is
`Charon`-prefixed so `internal_symbol()` keeps all of it out of the library's exports — the gate
counts 20 exported names for this object and none of them is a `Charon` one.

- **the state's image**, at its own shape inside the template's width, animated while the state is
  active. The cycle is UIKit's own rule for a multi-frame image (its `UIImageView.animationDuration`
  default of "number of images \* 1/30th of a second"), held inside the two bounds the header names,
  0.3 and 5.0 seconds, and repeated for as long as `repeats` is YES and once when it is NO.
- **the state's title**, chosen the header's way: "The Voice Control template will select the longest
  variant that fits your specified content" — the variants are tried longest first and the first that
  fits is drawn. The header says nothing about a template narrower than its shortest variant, so the
  shortest is drawn and the label truncates it, which is an answer rather than an empty label. The
  harness checks both branches: at 800 points the long variant is drawn, and at 220 the short one is.
- **one plate per state**, which is where the program's own input is: a tap on a plate calls
  `activateVoiceControlStateWithIdentifier:` with that state's identifier, the same mechanism the
  alert's own actions use in `CarPlayTemplatesMore12.m`. The harness does not take this on trust — it
  reads the plate's **registered** target and action back off the control and fails if either is
  missing, and then sends that action, because `UIControl`'s own dispatch needs a window and a
  Catalyst process has none. A plate drawn with no handler is exactly the defect the old CarPlay
  review found (C9), so the check exists to catch it.

The first draw happens in `viewDidLayoutSubviews` and not in the hook, because at the moment the
interface controller asks for the template the controller has no view yet: an earlier version of this
file drew there and pushed an empty screen, which is what the harness caught. A layout pass over the
same size draws nothing, so the plates a touch is halfway into are not thrown away.

## What puts these at 12.0, and how to read a selector out of this file

`CPVoiceControlState.h` is in no SDK on this machine, in either: the class is declared inside
`CPVoiceControlTemplate.h` in both the build SDK (16.4) and the one this port targets (26.2), and a
reader looking for a file of its own will not find one. So the class's `introduced` is read from
`coordination/corpus/sdk-26.2-surface.tsv`, which the queue header names as the registry's own source
for a row's `introduced`, and it is measured present in the 16.0 and 18.0 arm64e caches:

```
class  CPVoiceControlState  introduced=12.0        (sdk-26.2-surface.tsv)
class  CPVoiceControlTemplate  introduced=12.0
method -[CPVoiceControlState initWithIdentifier:titleVariants:image:repeats:]  introduced=12.0
method -[CPVoiceControlTemplate initWithVoiceControlStates:]  introduced=12.0
```

**A method whose signature spans four lines is one selector, and a grep of one line reads it as a
shorter one.** A review of this file took `CPVoiceControlVoiceControl12.m:67` for a one-argument
`-initWithIdentifier:` and looked for Apple's own one-argument form, and the SDK line it compared
against is the same trap: `CPVoiceControlTemplate.h:36` reads
`- (instancetype)initWithIdentifier:(NSString *)identifier` and continues on three more lines with
`titleVariants:image:repeats:`. All fifteen SDK copies on this machine say the same, so there is no
one-argument `initWithIdentifier:` on any CarPlay class in either SDK and nothing collides with
anything. What settles it is the object's own method list, which is what a selector question should be
asked of:

```
$ xcrun clang -target armv7-apple-ios6.1.3 -isysroot <iOS16.4 SDK> -fobjc-arc -Os -g0 -Wall \
      -Werror=objc-missing-property-synthesis -c packages/a/apple-backports/CarPlay/CarPlayVoiceControl12.m \
      -o CarPlayVoiceControl12.o
$ otool -oV CarPlayVoiceControl12.o | grep name        # every method the class defines
    initWithIdentifier:titleVariants:image:repeats:
    encodeWithCoder:   initWithCoder:   identifier   titleVariants   image   repeats
    .cxx_destruct      (ivars)          supportsSecureCoding   charon_imageLimitedToPoints:
```

One selector, one registry row, and the only names on the class without a row are `encodeWithCoder:`,
`initWithCoder:` and `+supportsSecureCoding`, which are NSCoding and NSSecureCoding conformance and are
named as such by the header the class conforms to.

## The rows

| row | what a caller gets |
| --- | --- |
| `CPVoiceControlState`, `.identifier` | the identifier the initialiser was given, nil for nil |
| `.titleVariants` | the array it was given, copied; nil in, nil out |
| `.image` | the image it was given, redrawn at most 150 by 150 points; nil in, nil out |
| `.repeats` | as given: an animated image repeats while the state is active and runs once when it is NO, on a cycle inside 0.3 and 5.0 seconds |
| `-[CPVoiceControlState initWithIdentifier:titleVariants:image:repeats:]` | the header's own initialiser, with both of its nullable arguments honoured as nullable |
| `CPVoiceControlTemplate`, `.voiceControlStates` | the first five of the states it was given; nil in, nil out |
| `.activeStateIdentifier` | the first state's identifier, nil when it has no states, and after an activation the identifier that was activated |
| `-[CPVoiceControlTemplate activateVoiceControlStateWithIdentifier:]` | switches the active state every time, with no interval in the object; a car would show the result and there is none |
| `-[CPVoiceControlTemplate initWithVoiceControlStates:]` | keeps five at most, begins on the first |

## What is still the wall

The screen. A voice control template in a car is shown on the car's display, and the identification
of what the driver said is the car's own: nothing in this library reaches a head unit, so the states
are the program's, the switch is the program's call, and the drawing is in the release's own UI. The
`facts/CarPlay/CarPlay.md` census and `facts/CarPlay/Scenes.md` carry the same wall for the scenes,
and the two pages agree on which side of it each class is.
