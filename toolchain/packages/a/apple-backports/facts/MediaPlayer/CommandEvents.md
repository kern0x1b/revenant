# The command events iOS 6.1.3 has no name for

`facts/MediaPlayer/MPMediaItem.md` records what this port carries of `MPMediaItem`. This file records the
seven command-event rows of the MediaPlayer queue that were filed `absent` on the ground that "the class
arrived in iOS 7.1 / iOS 8.0", and what they answer instead.

## What the release has, measured

Read with the deleted mach32 reader from the armv7 shared cache of 6.1.3
(`~/.charon/dyld/6.1.3/dyld_shared_cache_armv7`, the MediaPlayer image at `0x31fe3000`), the same read
whose controls are the deleted mach32 test:

- **236 classes** in `__objc_classlist` and **41** in `__objc_catlist`.
- **No class whose name holds `CommandEvent`** is among the 236, and none of the 41 categories adds one.
  `MPRemoteCommandCenter`, `MPRemoteCommand`, `MPRemoteCommandEvent` and every `*Command` are absent too -
  which is why `MPRemoteCommandCenter71.m` bridges them onto iOS 6's `UIEventTypeRemoteControl` by hand.
- **None of the 236 declares `isNegative`, `repeatType`, `shuffleType`, `preservesRepeatMode`,
  `preservesShuffleMode` or `negative`** - every class in the image was read and each of those six names
  is absent from every own instance list and every own class list.
- `-aSelectorNoFrameworkHas` is absent, so the reader answers NO to a name that is not there.

The whole-cache selector universe of the same release (`~/.charon/dyld/6.1.3/selectors_armv7.txt`,
113981 lines) is a list of **distinct names**, not a count per class: `dealloc` is on one line, not 433,
and `valueForProperty:` is on one line, not 26. Read that way it says something this family needs said and
nothing more: `isNegative`, `repeatType` and `shuffleType` are each on **one** line, so those three names
**do** occur somewhere in the 6.1.3 cache - on some other framework's class - while
`preservesRepeatMode` and `preservesShuffleMode` are on **none**. `prepareToPlay` is on one line and
`aSelectorNoFrameworkHas` on none, which are the controls that say the list is read and not guessed at.

That is exactly the trap `facts/MediaPlayer/MPMediaItem.md:105` records: a name in the per-cache list is
necessary and not sufficient, `albumTrackNumber` is declared by `MPAVItem` and `MPMediaQueryNowPlayingItem`
in the same image and is not an `MPMediaItem` accessor. The **per-class** read is what decides a member,
and it is the one above: within the MediaPlayer image all six names are absent, so every one of these
members is the port's to carry.

So every one of these classes is new code that cannot shadow anything. `absent` is for a member whose
answer needs hardware the device lacks; none of these needs any. They are carried.

## What these three are, at their real size

**They are not wired to anything, and the first draft of this page claimed they were.** It said the
port's bridge "builds every command event lazily by class, so carrying the event is what makes the
command reach a handler", and that `MPFeedbackCommandEvent` closed a link missing from the ancestor
chain four carried events walk. Both are false, and here is the measurement that says so.

**Apple publishes no API that hands a command an event, so there is nothing to wire.** That is the
question the reviewer's finding turns on, and it is settled by the headers, not by this tree:

| question | answer | how it was read |
| --- | --- | --- |
| any public API that delivers an event to a command? | **none** | `grep -rn 'deliverEvent\|sendEvent' .../MediaPlayer.framework/Headers` -> no file in SDK 26.2, no file in 16.4 |
| what does `MPRemoteCommand` publish? | `enabled`, `addTarget:action:`, `removeTarget:action:`, `removeTarget:`, `addTargetWithHandler:` | `MPRemoteCommand.h`, both SDKs, byte-identical |
| so who invokes a handler? | **only the system** | an application sets a handler and has no way to call it |
| where does `deliverEvent:` live? | `MPRemoteCommandCenter`, **private**, declared by no header | hence on no line of the 6.1.3 universe either - the 236 classes hold no `MPRemoteCommand` to declare it; controls `prepareToPlay` 1, `aSelectorNoFrameworkHas` 0 |
| what does the port use instead? | its own `-charon_dispatch:` | `MPRemoteCommandCenter71.m:133` |
| who calls it? | **one place**, the subtype switch | `MPRemoteCommandCenter71.m:250-275` |
| what does that switch map? | ten cases: Play, Pause, Stop, TogglePlayPause, NextTrack, PreviousTrack, BeginSeekingForward, EndSeekingForward, BeginSeekingBackward, EndSeekingBackward | read from the switch |
| could any iOS send more? | **no** - `UIEvent.h` in SDK **26.2 and 16.4** declares exactly those ten, `100` through `109`, with no repeat-mode, shuffle-mode, rating, playback-rate or feedback case at any availability | both SDK headers, read |

So there is no delivery path on any iOS, and a port that invented one would be inventing the event
source itself - the failure this port exists to avoid, and a private-API trick where the public mechanism
does not exist. That is why these three are carried as addressable objects and not wired, and it is the
same answer `MPChangePlaybackPositionCommandEvent` has carried since it landed.

**And the line that produced the false claim is still in the tree, because it is true.**
`MPRemoteCommandCenter71.m:33` says `charon_command()` "creates them lazily by class regardless of which
object file defines them, since they all share the same `MPRemoteCommand.initCharon` this file defines".
"They" is the **command** objects - `MPRemoteCommand` and its subclasses - which is exactly what
`charon_command()` allocates. Read as covering the *events*, it looks like the wiring that does not exist,
and that is the misreading this page and two of its rows made. Nothing here changes that line; the next
reader now has the sentence above it.

**And the ancestor chain does not exist.** The first draft said the port's four carried events walk
through `MPFeedbackCommandEvent`. `MPRemoteCommandEvent.h` at 26.2 declares `MPRatingCommandEvent`,
`MPSkipIntervalCommandEvent`, `MPChangePlaybackRateCommandEvent` and
`MPChangeLanguageOptionCommandEvent` all as `: MPRemoteCommandEvent` - flat - and

```
grep -n "@interface.*: MPFeedbackCommandEvent" .../MediaPlayer.framework/Headers/*.h
```

finds **0 in 26.2 and 0 in 16.4**. No class Apple publishes derives from it. The port followed 26.2 when
it declared its siblings over `MPRemoteCommandEvent`, which is the right call, and then this page claimed a
chain the SDK does not have.

## What the three are therefore carried as

Real, addressable objects: a caller may construct one, set its properties, and hand it to its own
handler. Before these commits `NSClassFromString(@"MPFeedbackCommandEvent")` answered nil,
`[MPChangeRepeatModeCommandEvent new]` messaged nil, and the corpus's blanket "the class arrived in
iOS 7.1 / 8.0" stood in for both. They are never messaged by this port's own bridge.

That is the posture every sibling row in this family has carried since it landed -
`ios71remotecommand.json` writes of `MPRatingCommand` "never messaged by this port's own bridge, since
no old-style rating gesture exists", of `MPSkipIntervalCommand` the same for skipping, and of
`MPChangePlaybackPositionCommandEvent` "the event type MPChangePlaybackPositionCommand would deliver
**if this release had a scrubbing gesture to source it from**". These three now say the same about
themselves instead of claiming a wire-up.

## What each answers

`MPRemoteCommandEvent.h` at SDK 26.2, quoted, is the whole contract:

```
@property (nonatomic, readonly, getter = isNegative) BOOL negative;                 // 7.1
@property (nonatomic, readonly) MPRepeatType repeatType;                            // 8.0
@property (nonatomic, readonly) BOOL preservesRepeatMode;                           // 8.0
@property (nonatomic, readonly) MPShuffleType shuffleType;                          // 8.0
@property (nonatomic, readonly) BOOL preservesShuffleMode;                          // 8.0
```

- **`-isNegative` is the selector, and `negative` is not one.** The header writes `getter = isNegative`,
  so the property name is not a selector on any platform. The port declares `-isNegative` and nothing
  named `negative`, and the registry row is `MPFeedbackCommandEvent.isNegative` - the same spelling
  `MPMediaItem.isCompilation` and `MPMediaItem.hasProtectedAsset` already use
  (`facts/MediaPlayer/MPMediaItem.md:61,79`). A probe that asked for `negative` would have learned
  nothing about this family.
- **`NO` is what an event that set nothing answers**, and it is the declared zero of `BOOL`. The subject
  is a **caller-constructed** event: nothing in this tree builds one for a repeat-mode, shuffle-mode or
  feedback change, and the section above is the measurement for that.
- **`MPRepeatType` has no "unknown" case** - `MPRemoteControlTypes.h:17` gives `MPRepeatTypeOff`,
  `MPRepeatTypeOne`, `MPRepeatTypeAll` - and `MPShuffleType` has none either
  (`MPRemoteControlTypes.h:11`: `MPShuffleTypeOff`, `MPShuffleTypeItems`, `MPShuffleTypeCollections`).
  An event that set nothing therefore answers `MPRepeatTypeOff` / `MPShuffleTypeOff`, which is the value
  for "no repeat" and "do not shuffle". A stand-in that added an `Unknown` case would have let the port
  compile against a type the SDK does not declare; `MPMediaItemStandin.h` spells the three cases out for
  that reason.
- **Readwrite in the port, readonly in the header.** Every event the port builds has to be able to carry
  the value it is an event *about*, and a new class shadows nothing. The accessors the header declares are
  what a caller reads, and they read what the port set. The accessors are written out rather than left to
  the synthesiser, so removing `@synthesize` is not a change of behaviour - ARC would synthesise exactly
  the same accessor - and a caller reads the port's own code.

One object per release, per `band()`'s own rule: `MPFeedbackCommandEvent.m` holds the 7.1 class and
nothing else, `MPChangeRepeatModeCommandEvent80.m` the 8.0 repeat event and not the 8.0 shuffle one, and
`MPChangeShuffleModeCommandEvent80.m` the 8.0 shuffle event. Three releases of one family, three objects.