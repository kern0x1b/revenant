# The names of iOS 16.1 and 16.4: the four members of UIHoverGestureRecognizer, UISearchBar's enabled, UITextInputContext

Six rows of `registry/UIKit/ios17-18.json`, every one of them `introduced` 16.1 or 16.4 and every one of them `minimum` 6.0.
Each was read three ways before a word of it was written: the SDK 26.2 surface for what the release declares, the
`objc-inventory` walk of the two band-end caches for what iOS 6.1.3 and 4.3 carry, and a differential against the host's own
UIKit under Mac Catalyst for what Apple's class does. The three answers are not the same, and the differences are what the
rows say.

## The two band ends

`packages/a/apple-backports/facts/UIKit/cache-hover16.tsv` holds the table. The commands a reader re-runs:

    CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7
    python3 -c "import json,os;print(len(json.load(open(os.path.expanduser('~/.charon/dyld/4.3/classes_armv7.json')))['classes']))"

Both rungs are certified in the run that produced the table, because a zero is only a fact about a release when the reader
is known to work: the 6.1.3 run read 11378 classes and 1171 protocols, 705 of the classes named `UI*`, and answered four
names of its own (`-isEnabled` and `-setFrame:` on `UIView`, `-insertDictationResult:` and `-textInRange:` on `UITextInput`);
the 4.3 file holds 7187 classes, 597 of them named `UI*`, and answered `isEnabled` and `setFrame:` on `UIView`,
`becomeFirstResponder` on `UIResponder` and `text` on `UILabel`.

- `UIHoverGestureRecognizer` and `UITextInputContext` are in neither cache: 0 of 11378 classes at 6.1.3, 0 of 7187 at 4.3.
- `zOffset`, `altitudeAngle`, `azimuthAngleInView:` and `azimuthUnitVectorInView:` have **no owner at all** - not one class and
  not one protocol in either cache, at either end. The reader that says this is the one that finds `-isEnabled` on 43 of
  11378 classes at 6.1.3 and 27 of 7187 at 4.3, `UISearchBar` in neither list either time.
- `UISearchBar` is in both, with 150 instance selectors at 6.1.3 and 98 at 4.3, and it declares **neither** `-isEnabled` nor
  `-setEnabled:` of its own at either end. `UIView` declares both. So the search bar of this release answers the two spellings
  of `enabled` through `UIView`, and a search bar method of its own is what the 16.4 property would be.
- Nothing carries `-isPencilInputExpected`, `-setPencilInputExpected:`, `-isDictationInputExpected`,
  `-isHardwareKeyboardInputExpected` or `+current`.

One reading in that table is the trap the tree already warns about, kept because it is the clearest example here: `rollAngle`
has two owners at 6.1.3, `AVMetadataFaceObject` and `AVMetadataFaceObjectInternal` - a face's roll, not a recogniser's. A
first-rung search for the bare name reads 17.5 and tells you nothing about whose member it is.

## What the host answers

    FLEET_HEAVY_LANE=fast $HOME/Git/projects/ios/coordination/heavy.sh sh -c \
      'cd tests/backports/host/uikit2 && UIKIT2_ONLY=hover16 UIKIT2_BUILD="$PWD/build" ./run.sh'

Five checks, no failures, on 2026-10-01:

    ok the four members of the hover recogniser that iOS 16.1 and 16.4 added, and UITextInputContext
    ok rollAngle of 17.5 stays with the release: it answers it and the port does not
    ok the port leaves UISearchBar's enabled to the release's own accessors
    ok the system answers 0 and an empty vector for a device that cannot hover
    ok and so does the port's own recogniser
    checks=5 failures=0

Two failures in the same run are main's own and not this group's: `UIKIT2_ONLY` narrows the groups but
not the tail of `run.sh`, and the buttonconfig red controls there report `FAIL buttonconfig control
[--no-plant]: exit=1, and it must be 2`, and the same for a key that does not exist. Nothing this band
touched is on that path.

The group is
`windowed_expected`: `hover16_system.m` runs in a process that links none of the port's code and writes what the host answered
to a file, and `hover16_test.m` runs the same scenario with the port linked, the port's class names renamed, and compares the
two lists line by line. The scenario is one file, `hover16_scenario.h`, so the two sides cannot drift apart.

The host's own answers, measured 2026-10-01 (macOS 27.0's UIKit through Mac Catalyst, a machine with no hovering device):

- The class answers **all four**, and each answers what SDK 16.4's `UIHoverGestureRecognizer.h` says a device that cannot
  hover answers: `zOffset` 0, `altitudeAngle` 0, `azimuthAngleInView:` 0 with a view and with nil, and
  `azimuthUnitVectorInView:` `0.0000,0.0000` with a view and with nil. The same four answer the same with the recogniser added
  to a view and removed again. `rollAngle` answers 0 too, and is the release's rather than the port's.
- `UISearchBar` does **not** answer `enabled`; it answers `isEnabled` and `setEnabled:`, and it does **not** inherit `UIView`'s
  setter - its own implementation is what runs. Fresh, `isEnabled` is 1 and `userInteractionEnabled` is 1 and `alpha` is 1;
  after `setEnabled:NO`, `isEnabled` and `userInteractionEnabled` are 0 and `alpha` is still 1; after `setEnabled:YES` all
  three are back to 1.
- `UITextInputContext` exists, its superclass is `NSObject`, `+current` hands back a context **of its own on every call** rather
  than a shared one, `+new` works although the header marks it `NS_UNAVAILABLE`, and the three flags read 0 on a fresh context,
  0 again after all three setters have run, 0 from a second `+current`, and 0 after the setters have been run with `NO`. The
  setters keep nothing.

## What the port does

- `UIHoverGestureRecognizer+Hover16.m` - the four members, answering 0 and an empty vector. This is Apple's own documented
  value for a device without the capability, and it is also what the host's class answers here, so the port and the system
  agree. They are methods on the port's own class and export no symbol, so `release-split` reads nothing for this file; the
  `hover16` case and the `documented` check in `hover16_test.m` are what hold them to the header's words, against the host's
  own class and not only against the port.
- `UITextInputContext16.m` - the class, `+current` and the three accessors, and the three flags answering 0 and keeping
  nothing, which is what the host's class does and what this release can support: no pencil, no dictation, no attached
  hardware keyboard for a flag to name.
- `UISearchBar.enabled` is left to the release. A category that added the two accessors would shadow nothing - the search bar
  of 6.1.3 and of 4.3 declares neither of them - but it would forward to `UIView`, and a second copy of what the release
  already answers is the one thing this port does not ship. What the port does add, `UISearchBar.searchTextField`, has nothing
  to do with the flag.

## Where it differs

- `UISearchBar` at 16.4 has its own `setEnabled:`; the search bar of 6.1.3 and of 4.3 has `UIView`'s. The two agree on what
  `NO` does - interaction prevented - so a caller cannot tell them apart by the effect; the second clause of the 16.4
  documentation, a minimized icon-only search bar that will not grow to the text field while disabled, has no such form in
  this release.
- The port's recogniser fails at the first touch it is offered, where the system's receives no touches at all. That is the
  13.0 object's own difference and is unchanged by the four members.
