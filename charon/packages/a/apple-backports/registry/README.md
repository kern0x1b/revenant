# The registry of what the backports do and do not carry

An application that calls API the device lacks stops there, so every API a
release added is decided on before it is missed. The entries live under
`registry/<Framework>/`, a file per author - `base.json` beside `ios10.json`,
`ios11.json`, `floor.json` - so that work on different releases never edits the
same file; a plain `<Framework>.json` beside them is read as well. A file holds
an array of entries, or an object with `framework` and `entries`, and one API
named by two files stops the build with both names.

    {
      "framework": "UIKit",
      "entries": [
        {
          "api": "-[UIView tintColorDidChange]",
          "kind": "method",
          "introduced": "7.0",
          "status": "implemented",
          "facts": "facts/UIKit/UIView+TintColor.md",
          "source": "UIKit 18.0 arm64e"
        },
        {
          "api": "UIDragInteraction",
          "kind": "class",
          "introduced": "11.0",
          "status": "absent",
          "reason": "dragging is carried by a system service the release does not run",
          "effect": "the class is not there: NSClassFromString answers nil and alloc on a compile time reference crashes"
        }
      ]
    }

`api` names what an application writes: a class as `UIStackView`, an instance
method as `-[UIView tintColorDidChange]`, a class method as
`+[UITraitCollection traitCollectionWithDisplayScale:]`, a property, both
accessors at once, as `UIScreen.captured`, a function as
`UIGraphicsBeginImageContextWithOptions()`, and a constant by its symbol,
`UIFontTextStyleBody`. A class whose whole surface shares one status is one
entry; a method of an implemented class that is not implemented gets its own.

`kind` is `class`, `protocol`, `method`, `property`, `constant` or `function`,
and two more for what no symbol can ever answer for. An `NS_ENUM` or
`NS_OPTIONS`, a typedef, a struct or a union has no exported symbol by nature -
nothing exports `MLMultiArrayDataType` or `MLMultiArrayDataTypeDouble` - so
such a row could never be `implemented` and the check would hold it red
forever. They are `kind: "type"` (the typedef, enumeration or struct itself)
and `kind: "case"` (one case of it, named by its own symbol), and the check
asks a different question of them: a header the build reads - the tree's own, a
Charon header generated or written, or the SDK it compiled against - must
**declare** the name. That is read, never taken on trust from the entry, so an
`implemented` type or case no header declares is held exactly as red as an
implemented class nothing builds. `introduced` still says when the release
arrived, which is what makes a Swift module that needs the case see it.

`introduced` is the release the SDK's availability gives, and for a private
entry point a backport calls, the release of the API that needed it. `removed` names the
release that took the API away, so that what modern iOS no longer has is not
backported as though it were current. `minimum` is the release below which the
entry becomes `absent`, which is how a release older than the one a backport
needs is written down once instead of once per release. `maximum` is its mirror,
the release from which the entry becomes `absent` although the release itself
does not have the API either: a member of a class the backports implement
themselves, whose behaviour lives inside that implementation, is gone once the
release carries the class and lays it out itself. `facts` points at the
file the behaviour was read into. It is required of an entry that claims
behaviour - one whose API the package itself carries - and of every `ignored`
entry; a record that only says where an API begins or ends, for a symbol this
release has nothing of, needs `reason` and `source` instead. `source`
names the library, release and architecture the behaviour was read from.

A `maximum` below `introduced` is the dangerous direction, and quietly so. It
does not make a build red: the entry is simply off for every band between the
two, which are the bands where the release does **not** have the API and the
port is the only source of it, so the band loses an API it was carrying and the
gap shows up on a device rather than in a gate. `modules/apple/backports.lua`'s
`in_range` is `minimum <= deployment < maximum`, and its `ours = in_range(entry,
deployment)` gates the "listed as implemented, but nothing of that name is
built" report, so a band that never asks about the row never hears about it.
The registry maximum check (removed) compares `maximum` against `introduced` and refuses
the rest, which catches a wrong `maximum` and **cannot** catch a wrong
`introduced`, because that field is written by hand from the SDK's availability:
reading it out of the headers is `tools/corpus/sdk-introduced.py`'s walk, and
until a row's `introduced` is measured against the SDK, a release that is one
too low passes this check and hides the API in the band above it.

That comparison is the rule for a member of a class **the release carries**,
where the port hands the member over as soon as the release answers it. The two
other cases are not that rule, and the tool says so rather than guessing:

- a member of a class **the backports carry** leaves the bands where the *class*
  stops being the port's, which can be earlier than the member's own
  `introduced`. `NSURLSessionTaskTransactionMetrics`'s two header byte counts
  are the case in the tree: `introduced 13.0` from the SDK header and
  `maximum 10.0`, because the release ladder gives the class its first release
  at 10.0.1. A band at 10.0 where the release's own class *does* export the
  getter then answers the property, so the row must already be out of the bands
  by then - which is what `maximum 10.0` says, and what `maximum 13.0` would get
  a gate to report as "listed as absent, but the release carries it itself".
- a member of a class the backports carry **and the release lays out itself**
  may go earlier still, down to the release that took the API away:
  `NSURLSessionStreamTask`'s `-init`, `+new` and `-stopSecureConnection` sit at
  `introduced 7.0, maximum 7.0` against a class the port carries to 9.0.

The tool counts those two shapes apart and never counts them as right: a run
prints how many members of a class the backports carries it did **not** judge,
so a green line with a large number there says "not judged", not "checked".

`status` is one of four, and there is no fifth. The registry has no resting
place for "not built": a row is either `implemented` or `owed`.

- `implemented` - the port's behaviour, with facts behind it and tests in
  `tests/backports`. Where the device lacks the part an API needs, the behaviour
  is the answer the real system gives there: an availability query that says
  NO (`readingAvailable`, `isRelativeAltitudeAvailable`), a generator that does
  nothing without its engine. That answer is the implementation, not a gap.
  A header-only value the port does not define (a static inline, an enumeration
  case) is `implemented` once its header says where its body is, and `owed`
  until then.
- `owed` - the work still to do. The API is not there yet, and the port will
  build it. It claims nothing at run time: the API stays unavailable on the
  device until the port implements it, and the `reason` is one line saying what
  to build. Where the build defines the API anyway, that is a stand-in: an
  stub that does nothing, or keeps values nothing reads. The gate reports
  the count and the names as a note, never as an error, because the real
  behaviour is still owed. A stand-in is not `implemented`: only a row whose
  real system does nothing on a device without the part, with facts that say so
  and name the measurement or documentation, is `implemented`.
- `absent` - the release's own window only, never a decision. A `maximum` says
  the release from which the release carries the API itself, so the port must
  not answer it there. An `absent` row without a `maximum` is refused by the
  reader (`modules/apple/backports.lua`), and a decision not to build an API is
  `owed`. `minimum` is the lowest deployment the entry applies to; it does not
  make an absence right, because an `absent` row with only a `minimum` is absent
  for every deployment it applies to.
- `ignored` - the call reaches the release's own implementation, which does
  something else with it, and nothing of ours is in the way: an option of an
  enumeration the compiler writes into a system call, a key of a dictionary a
  newer release reads and this one does not. There is nothing for
  `respondsToSelector:` to answer, since the method is the system's own, and
  nowhere to write a line, since the call never passes through the backports, so
  `effect` and `facts` are required and say what comes out instead. This is the
  quietest of the four and the one a port is least likely to notice, so a report
  says it first.

A value the header itself carries - a `static const`, a macro, a case of an
enumeration - gets no entry, because the package carries nothing of it: the
compiler writes the value into the application, and neither side of the check can
see it. `UIStackViewSpacingUseSystem` is one of those. Where such a value changes
what an API does, the entry of the API that reads it says so, and its file of
facts says what the value means.

The build checks the registry against what the package really defines: the
classes its libraries carry and the selectors its categories add. A class or
selector without an entry, an `implemented` entry that names nothing the build
carries and nothing the release itself exports, and an entry whose status comes
without the reason, effect or facts it owes stop the build; a band built for a
later release drops what that release already has, so only the libraries of the
port's own release are checked both ways. Entries that are not `implemented`
cannot be derived from anything, so they are written by hand, and a delivery
without them is not accepted.
