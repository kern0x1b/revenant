# `UIPencilInteraction`, iOS 12.1 — an interaction with no pencil to hear

The class is carried because an application in the corpus **strong-imports its class symbol**, and
`COORDINATION.md` §2 forbids `absent` for one of those: a strong import of a name nothing exports is
dyld killing the application at launch. What the interaction would react to — a tap on the side of an
Apple Pencil - no device this package runs on can produce, so the class is made, kept, added
to a view and removed like any other interaction, and never called back. That is the implementation: a stylus this device has no part for makes no tap, and the interaction answers as the system does without one.

## The import that made this a class and not a row

`nm -m` over the arm64 `Aidoku` binary of the corpus
(`coordination/corpus/aidoku/extracted/Payload/Aidoku.app/Aidoku`):

```
                 (undefined) external _OBJC_CLASS_$_UIPencilInteraction (from UIKit)
```

`external`, not `weak external`, and the same line for `_OBJC_CLASS_$_UIApplication` beside it: this
is a strong import against `UIKit`, the framework the port's `libUIKitBackports.dylib` is loaded to
answer. The corpus store records the same three apps and marks which of them the symbol is weak in
(`coordination/corpus/store.json`): `aidoku` `weak: false`, `telegram` and `utm` `weak: true`. One
strong importer is enough for the class to have to exist.

`tools/corpus/crash-demand.py` ranks it 54th, `LOAD-FAIL`, 3 apps, 1 of them a crash, and the same
tool's own note is the reason it is a *link-time* symbol rather than a call: a strong import binds at
load, so the absence of the class is a launch failure and not a crash on use.

The delegate's side of it is `registry/UIKit/ios11.json`'s `UIPencilInteractionDelegate` row, already
`ignored` and unchanged by this band: an application that conforms compiles, its metadata is in its
own image, and no message of the protocol is ever sent.

## Why the class property answers `Ignore` and not a stored preference

`+preferredTapAction` is the action to perform when the user taps the pencil's side. Two facts decide
the answer and neither of them is a guess:

- **There is no pencil, so there is no tap.** `UIPencilPreferredActionIgnore` is `0` and the SDK
  16.4 header says of it: *"No action, or the user has disabled pencil interactions in Accessibility
  settings"*. With no pencil there is no action to perform, which is what `Ignore` says.
- **There is nothing to read.** iOS 6 has no Settings pane for a pencil tap action, so no preference
  exists to be read; answering a number copied off another machine would be the quiet difference the
  repository rules call the most dangerous outcome there is.

## The host, asked rather than assumed

`tools/corpus/host-probe.c`'s shape, compiled for Mac Catalyst against the SDK the tree resolves
(`xcrun --show-sdk-path`, `-iframework $sdk/System/iOSSupport/System/Library/Frameworks`) and run on
this machine. Source and binary: `.agent-work/runs/pencil/probe.m`. Output:

```
host UIPencilInteraction class: present
host _OBJC_CLASS_$_UIPencilInteraction exported: no
+preferredTapAction: 1
+prefersPencilOnlyDrawing: NO
fresh -isEnabled: YES
after setEnabled:NO -isEnabled: NO
respondsToSelector:@selector(view): YES
after addInteraction: view==v: YES, count=1
```

Three answers are the port's, and each is the honest one for a device with no pencil:

| host says | the port answers | why the difference is the truth |
|---|---|---|
| `+prefersPencilOnlyDrawing` NO | NO | the same: nothing can draw with a pencil |
| fresh `-isEnabled` YES, and `NO` sticks after `setEnabled:NO` | the same | plain storage; the host's is measured, not assumed |
| `+preferredTapAction` **1** (`SwitchEraser`) | `Ignore` (0) | the host is a Mac that can be paired with an iPad and has a preference set; this device has no pencil and no preference to read |

`+preferredTapAction` is the only answer the port does not copy, and the difference is the point: the
same enum value would be a lie here.

## What the release itself carries, measured

Neither deployment band end carries the class, which is why this is a port object and not a
re-export. `CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua UI 6.1.3 4.3 11.0 12.0`, and
`tools/cache-index/first-rung.lua`:

```
NAME                             4.3 6.1.3 7.0 9.0 11.0 12.0
UIPencilInteraction              0     0    0    0    0    0
control (per release): 661 / 796 / 997 / 1484 / 2039 / 2130 names beginning UI
```

Every control is a real count, so the zero is the release's and not the reader's.
`first-rung.lua --rungs UIPencilInteraction` answers `16.0,18.0`: the 12.1 release that introduced it
is not held (the ladder jumps 12.0 → 16.0), and the class symbol first appears on the rungs this
machine holds from 16.0 on. That is the same hole the 16.0 absence page records, read from the other
side: the SDK's `12.1` is not contradicted by the caches, it is simply not among them.

The member selectors were read class-scoped, which is what `backports.lua:1612`
(`carried_by_release`) reads, over `tools/corpus/objc-inventory.lua` of both armv7 band ends:

```
== .agent-work/runs/inv-6.1.3.tsv classes 11378
  control UIView -setFrame: True     control UITableView -reloadData: True
  control UINavigationItem -title: True   control UIView -isHidden: True
  control UISearchBar -text: True    control UIBarButtonItem -tintColor: True
  owner present: UIPencilInteraction False   proto#: False
== .agent-work/runs/inv-4.3.tsv classes 7187
  (the same five controls present; UIBarButtonItem -tintColor: is absent, correctly —
   tintColor arrived in iOS 7 and this is the 4.3 cache)
  owner present: UIPencilInteraction False   proto#: False
```

Six controls, six answers, and the one negative control (`-tintColor` on 4.3) is negative because the
release really lacks it, which is what makes the other five worth reading.

## The same shape as its kin

`UIScribbleInteraction` and `UIIndirectScribbleInteraction` (`packages/a/apple-backports/UIKit/UIScribbleInteraction.m`,
`facts/UIKit/UIInertInteractions.md`) are carried for the same wall and behave the same way: made with
`-init` too, delegate kept weakly, never called, `+pencilInputExpected` NO, and the first one added to
a view says so once in the log. Reusing that shape is why this object is forty lines and not a
subsystem: there is nothing to detect and nothing to draw.

`UIView`'s own interaction list (`UIView+Interactions.m`, iOS 11) is what `-[UIPencilInteraction view]`
and the two move callbacks are for, and it is carried: the host answers `view == v` and `count == 1`
after `-addInteraction:` above, which is the port's own `-[UIView addInteraction:]` measured against
the host's.

## The build

`packages/a/apple-backports/UIKit/UIPencilInteraction12.m`, named for its release so the file carries
one release's API and `tools/release-split.lua` has nothing to split. Compiled with the tree's own
compiler and flags at all three deployment floors the armv7 architecture reaches
(`clang -target armv7s-apple-ios6.0`, `armv7-apple-ios6.0`, `armv7-apple-ios4.3`, `-fobjc-arc`,
`-Werror=objc-missing-property-synthesis`): no diagnostic, and `nm -gU` on the object exports
`_OBJC_CLASS_$_UIPencilInteraction`, which is the symbol the strong import binds.
