# UIListSeparatorConfiguration, iOS 14.5

A configuration for the separators of a `UICollectionView` list: two visibilities, two sets of insets, a colour
and a colour for while several rows are selected. The 14.5 header declares ten names and states no default for
any of them, so every number below is measured.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0, build 26A428), asked for every default, every
write read back, the copy, the archive round trip and the two `NS_UNAVAILABLE` constructors, by the case in
`tests/backports/host/uikit2/listseparator_test.m` - the port's object built beside the system's in one
process, under the name `CharonHostUIListSeparatorConfiguration`, and every value printed by the case for both
sides. That case is the oracle: its expectations are what the host answers, not what the port returns.

## M1. The defaults, as the host answers them

One reading per appearance; the case asks all five and the host gives the same six values for every one of
them, so a port that switched on the appearance would be red.

| read | the host's answer |
| --- | --- |
| `topSeparatorVisibility` | `0` - `UIListSeparatorVisibilityAutomatic` |
| `bottomSeparatorVisibility` | `0` - `UIListSeparatorVisibilityAutomatic` |
| `topSeparatorInsets` | `0 1.79769e+308 0 1.79769e+308`, and it **is** `UIListSeparatorAutomaticInsets` by value (`1`) |
| `bottomSeparatorInsets` | the same automatic constant |
| `color` | a colour - the separator colour, 0 0 0 0.098 resolved |
| `multipleSelectionColor` | a colour - a DYNAMIC one on the host, over the same role |

`UIListSeparatorAutomaticInsets` is not a made-up constant here: the header declares it, and the case asks
whether the value the configuration answers **is** that constant, by comparison, and the host says yes.

The multiple-selection colour being dynamic is the one that shows on the host: it resolves to the same 0 0 0
0.098 on a light interface, and it is a provider over the trait collection rather than a frozen colour, so the
port makes it a dynamic colour over the same role instead of freezing a value that would be wrong on the other
interface.

## M2. Writes, the copy and the archive

Every property is written and read back on both sides, and the answers agree: visibility `2` and `1`, insets
`1 2 3 4` and `5 6 7 8`, and each colour **by identity** - the getter hands back the very object the setter was
given, which is what `copy` on the property means for an object.

`-copy` is another object, never its receiver, and it keeps the top visibility, the bottom insets and **the
colour instance** - the same colour object, not an equal one.

The archive round trip goes through `NSKeyedArchiver` with `requiringSecureCoding:YES` and back through
`NSKeyedUnarchiver`, on both sides, and the keys are the host's own - read out of the host's archive plist by
the band that measured them. A configuration written with visibility `2`/`1` and insets `1 2 3 4` / `5 6 7 8`
reads back with all four, and with a colour present.

## M3. `+new` and `-init` are `NS_UNAVAILABLE`, the port defines neither, and what a call reaches is `NSObject`'s

The 14.5 header marks both unavailable, and Apple's own class defines neither. Measured on the class's own
method lists, the way item 1's eight rows are decided and not by the header:

| read | source | result |
| --- | --- | --- |
| `-init` in `UIListSeparatorConfiguration`'s own instance list | arm64e cache of iOS 16.0, `modules/apple/objc.lua`'s `inventory` | **no** (`no-own-init`) |
| a method named `new` in its own metaclass list | the same read | **no** (`no-own-new`) |
| control: `-init` in a class's own instance list | the same read | yes, **28851** of that cache's classes, `ARConfiguration` and `NSObject` among them |
| control: a method named `new` in a class's own metaclass list | the same read | yes, **523** of them, `NSObject` itself among those |
| `UIListSeparatorConfiguration`'s own lists, on the host | `class_copyMethodList` | 37 instance methods, no `init`; 6 metaclass methods, no `new` |

The class arrived in 14.5 and no 14.x cache is held on this machine, so **16.0 is the oldest release here
that carries it** and 18.0 the newest read for this ruling; both agree, and both agree with the host. The two
rows are therefore answered by `NSObject`'s own initialiser, and the port answers the same way: it defines neither,
so `-init` and `+new` reach `NSObject` on the port as they do on the host, and the rows are `implemented` on that
measurement. The object carries `-initWithListAppearance:`, `-initWithCoder:` and the header's ten members and
nothing else.

What a call reaches is `NSObject`'s, on this release and on Apple's alike, and what that answers is every
field at the zero of its type - measured on the host, and the port's own case asks both constructors on both
sides with `objc_msgSend` and reads every field back:

| read | `+[UIListSeparatorConfiguration new]` | `-[UIListSeparatorConfiguration init]` |
| --- | --- | --- |
| `topSeparatorVisibility` | `0` | `0` |
| `bottomSeparatorVisibility` | `0` | `0` |
| `topSeparatorInsets` | `0 0 0 0` | `0 0 0 0` |
| `bottomSeparatorInsets` | `0 0 0 0` | `0 0 0 0` |
| `color` | nil | nil |
| `multipleSelectionColor` | nil | nil |

The insets are **zero** where `-initWithListAppearance:` - the header's `NS_DESIGNATED_INITIALIZER` - gives
the automatic ones, and both colours are nil where it gives the separator colour. Those numbers need no code
here: they are what an object that wrote nothing reads back as.

**The port defined both for a while, and the header was not the reason to take them out.** It defined
`-init` as `[super init]` and `+new` as `[[self alloc] init]`, and the `-init` was also the only warning the
package's own compile line printed on the file (the rows are answered by `NSObject` on both sides, as above):

    UIListSeparatorConfiguration145.m:115:19: warning: convenience initializer should not invoke an
    initializer on 'super' [-Wobjc-designated-initializers]

Both are gone and the warning with them: the header already marks `-initWithListAppearance:`
`NS_DESIGNATED_INITIALIZER`, so the class's one initializer is a designated one and there is no secondary
initializer left to warn about. The two definitions were answering what `NSObject`'s already answers, on a
class Apple's own metadata does not give them to.

A first version of this file, and of the row beside it, said the port had a `-initCharonWithDefaults:` method
"stated as a separate method so the difference between the two paths is in the code rather than in a comment".
**There is no such method** and there never was. The registry check's coherence pass is what found it - it
named the selector as one the row cites and the file the row names does not define. A comment that describes a
method which is not there is the same defect as a row that describes one, so both were corrected forward.

## M4. `visualEffect` (15.0): what the host does with it, measured

The row used to be `absent`, on the ground that the port did not carry this class. The class arrived and the
ground went with it - and the port was answering the property all the same, because the 16.4 build SDK
declares it on the class and clang auto-synthesised the pair into the 14.5 object. `nm` on that object at
`armv7-apple-ios6.0`, before the fix:

    00000570 t -[UIListSeparatorConfiguration visualEffect]
    00000574 t -[UIListSeparatorConfiguration setVisualEffect:]
    00001168 S _OBJC_IVAR_$_UIListSeparatorConfiguration._visualEffect

Apple's own metadata says the pair belongs to the class: the arm64e cache of iOS 18.0 carries
`-visualEffect` and `-setVisualEffect:` in `UIListSeparatorConfiguration`'s own instance list, among its 37,
and so does the host's own class. So the member is carried, in `UIListSeparatorConfiguration+VisualEffect15.m`
(15.0), and the 14.5 object declares the property `@dynamic` so nothing is synthesised there. After the fix
`nm` on the 14.5 object shows nothing for this member, and the 15.0 object carries the pair and three seams.

### What the host does with it

The oracle is the host's own UIKitCore under Mac Catalyst, read by
`.agent-work/runs/fix/effect-probe.m`; nothing of the port's is linked into it.

| read | the host's answer |
| --- | --- |
| a fresh configuration's `visualEffect` | **nil** |
| after `-setVisualEffect:` | a `UIBlurEffect`, and **not** the instance that was set - the header's `copy` is applied |
| `-copyWithZone:` | carries it, and the copy's effect is again not the receiver's instance; the copy is not its receiver |
| a copy of a fresh configuration | nil |
| `-isEqual:` of two written alike, both effectless | **1** |
| `-isEqual:` of the same two, one given an effect | **0** - the effect joins the equality |
| `-hash:` of either pair | **alike** - the hash does *not* take it into account |
| the archive | writes **seven** keys, the seventh being `visualEffect`, the property's own name, and reads back a `UIBlurEffect` |

The host's object's dictionary in the archive, verbatim:

    { bottomSepVisibility = 0; color = ...; insets = ...; multiSelectColor = ...;
      topSepInsets = ...; topSepVisibility = 2; visualEffect = ...; }

Six of those seven this port wrote from the start; the seventh is the one under discussion, and it is now
written too, under the host's own key.

### Why `@dynamic` here and not there

`@dynamic` on a property whose accessors do not exist is a crutch: the selector is unrecognised and the row
would be claiming nothing. Here they exist, in the 15.0 object, and the `@dynamic` says exactly that: the 14.5
object must not synthesise a pair of its own, because it is a 14.5 object and this member is 15.0, and the
auto-synthesised ivar is not wanted since the storage is an associated object the 15.0 object owns.

### The three seams

The 14.5 object holds the copy and the archive, and both have to reach a 15.0 member. A category's
`[super copyWithZone:]` resolves against `NSObject` rather than against the class it is a category of -
measured, not assumed, in `UIImageConfiguration+Locale17.m`'s comment - so a 15.0 category could not *extend*
the 14.5 copy; it could only replace it, and a replacement would lose the six fields. The direction that
works is the one the locale object uses: the older object calls, the newer one implements, through
declarations both can see in `CharonLists.h`. Nothing outside this library reads those three, which is why
they are not registry rows; the case reads the public pair.

## M5. `-isEqual:` and `-hash`, field by field

Both are Apple's: the arm64e cache of iOS 18.0 carries them in `UIListSeparatorConfiguration`'s own 37
methods. **The port's `-isEqual:` is a value equality over seven fields, and the port's `-hash` covers five
of them.**

How each field was measured: a pair of configurations from one appearance, identical apart from exactly one
field, and both answers taken (`.agent-work/runs/fix/equality-probe.m`, the host's own UIKitCore only).

| field | joins `-isEqual:` | joins `-hash` |
| --- | --- | --- |
| `topSeparatorVisibility` | yes | yes |
| `bottomSeparatorVisibility` | yes | yes |
| `topSeparatorInsets` | yes | **no** |
| `bottomSeparatorInsets` | yes | yes |
| `color` | yes | yes |
| `multipleSelectionColor` | yes | yes |
| `visualEffect` (15.0) | yes | **no** |
| the list appearance | **no** | **no** |

The two `no`s in the hash column were re-measured with **four** value sets each, because one sample cannot
tell a field left out of the hash from a pair that happened to collide: the top insets and the visual effect
are out of it every time, the bottom insets are in it every time. So the asymmetry between the two insets is
the release's and not a slip in the table.

**The appearance is not compared at all**, and that is the one that looks wrong until it is measured. Two
configurations built from **different** appearances and equal in every field are equal:

    appearance, all written alike             isEqual = 1   hashes alike
    plain vs sidebar, colours written         isEqual = 1   hashes alike
    plain vs sidebar, msc only written        isEqual = 1   hashes alike
    plain vs sidebar, colour only written     isEqual = 0   hashes DIFFER
    plain vs sidebar, visibility written      isEqual = 0   hashes DIFFER
    plain vs sidebar, insets written          isEqual = 0   hashes DIFFER
    plain vs sidebar, effect written          isEqual = 0   hashes DIFFER

The carrier is `multipleSelectionColor`: on the host its default is a `UIDynamicProviderColor` that differs
between a plain and a sidebar configuration (the two defaults are not `-isEqual:` to each other), and
writing that one field on both sides makes the pair equal. The automatic insets are the **same** for both
appearances on this host (measured: `1.79769e+308 0 1.79769e+308 0` either way), so they cannot be the
carrier, and writing `color` leaves the pair unequal, so `color` is not it either.

Two configurations whose colours are equal by value but are separate objects are **equal** (measured), which
is what a value equality means and what an identity cannot do - and it is the pair an earlier measurement in
this tree called unequal.

### What this leaves different, stated rather than smoothed over

A port pair built from two **different** appearances with nothing written answers **equal**, where the host
answers unequal: the port's `multipleSelectionColor` is the same dynamic role for every appearance, there
being no list here whose appearance could vary it. That is a difference in a *default*, not in the equality
rule, and it is the honest consequence of carrying a value that varies with a thing this release does not
have.

### The red control

Two plants in a scratch copy of the port's source - the bottom insets left out of the equality, and the top
insets put into the hash - and the case goes red on exactly the two rows they touch:

    FAIL the top insets join the equality and NOT the hash:   port 0/other hash != system 0/same hash
    FAIL the bottom insets join the equality and the hash:   port 1/other hash != system 0/other hash

### A correction, and what it cost

The 14.5 object's first version said `-isEqual:` and `-hash` were deliberately left undefined because "the
host's isEqual: is not a value equality either: two configurations both written alike are NOT equal
(`two written alike isEqual=0`)". **That is false, and it was false in the same tree, in the same commit
family.** The probe written for the visual effect had already measured `isEqual = 1` for two alike
configurations; the claim was taken from an earlier band's note, was repeated in a code comment and in this
file, and was used to justify leaving two of Apple's own methods unimplemented. A measurement in the same
directory contradicted it and the contradiction was not read.

## What this port does not do

The appearance model. `-initWithListAppearance:` stores the appearance and applies the defaults above; it does
not switch a separator's colour on the interface style, on a selection, or on a list's own background, because
this release has no `UICollectionView` list for a separator to be drawn in. The rows say what the object stores
and answers back and do not claim the drawing.

## The crash that was in this case, and where it was

The group's run died with `exit=139` - SIGSEGV - and the band that wrote the case could not root it in the time
it had, and recorded that the port's archive round trip passed in isolation and so did the system's.

**It was the case's own diagnostic string, not the archive.** Under AddressSanitizer the stack is

    #0 objc_opt_respondsToSelector+0xc (libobjc.A.dylib)
    #1 __CFSTRING_IS_CALLING_OUT_TO_AN_OBJECT_FORMAT_ARGUMENT_WITH_CONTEXT__ (CoreFoundation)
    #5 +[NSString stringWithFormat:]
    #6 check_one_appearance listseparator_test.m:117

and line 117 was `[NSString stringWithFormat:@"port %@ system %@", error, ourArchive.length]` - a `%@` given
`ourArchive.length`, an `NSUInteger`. CFString sent `-respondsToSelector:` to a number near the zero page and
the process died. The string is built **eagerly**, as the detail argument of the check, so it killed the run
whether or not the check it was reporting had failed: the archive round trip was never reached, and M2 above is
what it answers once the string is right.

Three errors, one per call, and the lengths as integers: `NSKeyedArchiver archivedDataWithRootObject:` was given
the same `NSError *` twice and so were the two unarchive calls, so a failure on the port's side could not be
told from one on the system's.

## The red control

The comparison responds to a wrong answer on the keys M1 states. One plant in a scratch copy of the port's
source - `_topInsets = NSDirectionalEdgeInsetsMake(3, 3, 3, 3)` where the measured value is
`UIListSeparatorAutomaticInsets` - and the run goes red and names the keys:

    FAIL the plain top insets are the automatic ones: port 3 3 3 3 != system 0 1.79769e+308 0 1.79769e+308
    FAIL the plain insets are the shared constant: port 0 != system 1
    FAIL the grouped top insets are the automatic ones: port 3 3 3 3 != system 0 1.79769e+308 0 1.79769e+308
    FAIL the grouped insets are the shared constant: port 0 != system 1

It is a value and not a call, so the group still builds and still links: a plant that broke the build would
prove the compiler works and not that the comparison works.