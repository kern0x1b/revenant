# The traits of iOS 17, 18 and 26 on a release that has none of them

What the port's `UITraitCollection`, the twenty-two trait classes and the trait change
registration do, and where each answer was read from. Every number below was measured before the
code that answers it was written, on the host's own UIKit under Mac Catalyst, by
`.agent-work/runs/traits17/probe.m` and by the `d.m` probe beside it, and then held by
`tests/backports/host/uikit2/traits17_test.m`, which puts the port and the system in one process
and asks both the same question. That test is 352 checks and is green.

The two oracles are not the same and are not interchangeable. The host's UIKit is 26.2's own, and
it is a *measurement*, not a specification: where it and the header disagree, M8 records what the
host did. A real iPad 2 on 6.1.3 is the target the behaviour has to hold for, and no run on one has
happened: this is **device-unverified**.

## Where the value of a trait lives

A trait collection already held a value per trait, so the traits of 17 add no store. Each of the
twenty-two says where its value already lives, and the 17.0 accessors read and write that one
place, so a collection made by `+traitCollectionWithUserInterfaceStyle:` and one made by
`+traitCollectionWithNSIntegerValue:forTrait:` with `UITraitUserInterfaceStyle` are the same
collection and compare equal.

| home | traits |
| --- | --- |
| `UITraitCollection.m`'s own ivars | idiom, display scale, both size classes |
| `charon_trait_style` | user interface style |
| the force touch capability's own storage | force touch capability |
| the extras dictionary | the other fourteen |

The extras dictionary holds `NSNumber` for the numeric traits, which is what the older traits
already stored, and the object itself for the two object traits, so equality, hashing, coding, the
merge of `+traitCollectionWithTraitsFromCollections:` and the description all reach the new traits
without a store of their own. One name differs from the trait's `+name`: the collection has always
keyed the layout direction as `UserInterfaceLayoutDirection`, and it still does, so a description
that printed it before has not changed.

## M1 — a trait class

All twenty-two derive from `NSObject` and carry no state. Measured, per class:

- `+identifier` is the class's own name.
- `+name` is that name without its `UITrait` prefix. One rule, twenty-two classes.
- `+defaultValue` is the value a collection that sets none of the trait has, read through the type
  the class's protocol declares: `-1` for idiom, layout direction, gamut, contrast, level, legibility
  weight, active appearance, toolbar item presentation size, image dynamic range, scene capture
  state, HDR headroom usage limit; `0` for user interface style, horizontal and vertical size class,
  force touch capability, list environment, tab accessory environment, split view controller layout
  environment; `0.0` for display scale; the string `_UICTContentSizeCategoryUnspecified` for the
  preferred content size category; and **nil** for the typesetting language and for the natural
  alignment flag.
- `+affectsColorAppearance` is YES for exactly seven: idiom, style, gamut, contrast, level, active
  appearance, list environment. NO for the other fourteen. `UITraitTypesettingLanguage` has **no**
  `+affectsColorAppearance` at all, and neither has the port: the property is `@optional` in the
  header and the host leaves it out, so an application that asks must be ready for nothing.
- The host also carries two class methods no SDK header declares, `+defaultValueRepresentsUnspecified`
  and `+_isPrivate`, and four trait classes no SDK header declares, which M1 lists below. Nothing
  here answers any of the six.

## M2 — what a collection holds

Every trait a collection does not set reads as its class's `defaultValue`. A collection built from
`+traitCollectionWithTraits:` with an empty block answers: idiom `-1`, style `0`, layout direction
`-1`, display scale `0`, both size classes `0`, gamut/contrast/level/legibility/active/dynamic range/
capture/HDR `-1`, typesetting language `nil`, list environment `0`, toolbar item presentation size
`-1`, force touch `0`, and **true** for the natural alignment flag.

That last one is the only place the collection and the trait class disagree: the class's
`defaultValue` is nil and the collection answers true. The port answers true, because true is the
answer a collection on this release has to give — the base writing direction of a view here is the
one the user's language gives, which is the other of the two the header names, so natural alignment
resolves the way this release has always resolved it.

`-[UITraitCollection traitCollectionByModifyingTraits:]` keeps the traits of the collection it was
made from and applies the mutation, in that order. `+traitCollectionWithTraits:` starts from
nothing. A collection's traits are immutable, so `-copyWithZone:` answers the same object and a copy
to mutate is made through `+traitCollectionWithTraitsFromCollections:` with the force touch
capability put back by its own route.

`changedTraitsFromTraitCollection:` answers an `NSSet` of the traits whose value differs. A trait
neither collection sets is not a change, so a collection against itself changes nothing, and a
collection against `nil` changes every trait it sets.

## M3 — the two system lists

`+systemTraitsAffectingColorAppearance` names nine classes and `+systemTraitsAffectingImageLookup`
eleven. Four of them are private and **no SDK header declares them**: `UITraitVibrancy`,
`UITraitUserInterfaceRenderingMode`, `UITraitSelectionIsKey`, `UITraitArtworkSubtype`. The port
carries none of the four and answers the public ones in the host's order: six for colour appearance
(idiom, style, gamut, contrast, level, active appearance) and ten for image lookup (those six
without active appearance, plus layout direction, display scale, both size classes, the preferred
content size category and legibility weight). The differential fails if the host ever stops naming
the four, so the subtraction is noticed rather than forgotten.

## M4 — the three refusals

Asked through the wrong protocol, of a class that is not a trait, the host raises
`NSInternalInconsistencyException`:

- `Data type (CGFloat) for trait with name 'DisplayScale' does not match expected data type (Object)`
- `Data type (NSInteger) for trait with name 'UserInterfaceStyle' does not match expected data type (CGFloat)`
- `Trait class '(null)' does not implement the required defaultValue class property`, for `nil` and
  for a class that is not a trait at all.

The port raises the same three, word for word, with the trait named by its `+name`.

## M5 — traitOverrides

A view, a view controller, a presentation controller and a scene each have their own, and two views
never share one. The host's class is named `_UITraitOverrides`; the port's is named `CharonOverrides`,
and the two names are different on purpose. A class a library defines under a name nobody owns is
that library's own type, is not Apple's API, and carries no release - which is how every other private
helper in this library is named. Defined under Apple's private name it is the other thing: it looks
like Apple's API, nothing dates it, and the 6.1.3 gate refuses to build a tree holding one:

```
neither the SDK, the registry nor a held release's own cache says which iOS release _UITraitOverrides
_UITraitRegistration arrived in, and UITraitOverrides17.m defines it, so no band can hold it
```

What that costs is the class name inside a printed description, so the differential compares the two
descriptions with the leading class name left out. What the host prints, and what the port's object
holds:

```
<_UITraitOverrides: 0x...; no overrides>
<_UITraitOverrides: 0x...; overrides = { UserInterfaceStyle = Dark }>
<_UITraitOverrides: 0x...; overrides = { DisplayScale = 2, TypesettingLanguage = Optional(fr) }>
```

`containsTrait:` is NO for a trait the object was not told, YES after `setNSIntegerValue:forTrait:`,
and NO again after `removeTrait:`. Reading a trait it was not told raises
`NSInternalInconsistencyException: Can't return value for trait UserInterfaceStyle that has no
override` — the port raises it too, and *only* here: the mutations object a `traitCollectionWithTraits:`
block is given answers the trait's default instead, because a block reading a trait it has not set is
reading the environment's, which is what the host's mutations do.

`removeTrait:` puts the trait back to what the environment says, which is the trait's default: the
dictionary entry goes, the five ivar-backed traits go to their unspecified values, the style is
taken away, and the force touch capability goes to Unknown.

## M6 — the registration

A view, a view controller, a window and a scene answer the four methods of `UITraitChangeObservable`.
The host's registration is a class named `_UITraitRegistration`; the port's is `CharonRegistration`,
for the reason M5 gives. It conforms to `UITraitChangeRegistration`, which is `NSCopying`, and a copy is the same registration:
two calls asking for the same traits are two registrations and a copy is not a second of them.
Unregistering is quiet twice over, and unregistering a registration that is not the observable's is
quiet as well. Two refusals, word for word:

- `Must pass one or more traits to register for`, for an empty trait list.
- `Must pass a non-nil registration to unregister`, for `nil`.

`withTarget:action:` takes a method of zero, one or two arguments and the count of the method's own
decides what the call is given: the environment, and then the collection it had before.

A registration is called back when the traits it names change in the environment it was made on, and
the port's delivery is the trait change delivery `UITraitCollection.m` already runs, so the two paths
a handler can fire on are the ones this release really has: the release reporting a new status bar
orientation, and an application setting a trait. Nothing else here moves a trait.

## M7 — what a description prints

One rule, read value by value from a collection built for every trait at `-1` through `6`:

- a trait whose value is its own class `defaultValue` is **not printed at all**;
- any other value is printed as the name the trait's enumeration gives that case, or as the number
  where the enumeration has no name for it.

So `DisplayGamut` prints `sRGB` and `P3` and `2`; `AccessibilityContrast` prints `Normal`, `High`,
`2`; `UserInterfaceLevel` prints `Base`, `Elevated`, `2`; `UITraitLayoutDirection` prints `LTR`,
`RTL`, `2`; the force touch capability prints nothing for `Unknown`, `Unavailable`, `Available` and
`3`; the toolbar item presentation size prints `Regular`, `Small`, `2`, `Large` — **2 has no name in
that one**; and image dynamic range, scene capture state, HDR headroom usage limit, list environment,
tab accessory environment and split view controller layout environment have no names at all, so every
value of theirs prints as its number. Legibility weight and active appearance are printed by neither
side.

A trait's value is printed the same way wherever a description prints one, so a collection and a
trait overrides object never print the same value two ways.

## M8 — where the host is not a specification

Two findings, and both are the reason a header is not enough:

1. **The host's `forTrait:` machinery does not survive being exercised.** Asked first, in a process
   where nothing has raised, `[UITraitCollection traitCollectionWithObject:@"fr" forTrait:[UITraitTypesettingLanguage class]]`
   **succeeds** and the value reads back. After a trait metadata exception has been raised once, the
   same call answers `Trait class 'UITraitTypesettingLanguage' does not implement the required
   defaultValue class property`, and so does a call that succeeded a moment earlier — and the process
   does not come back from it. The port therefore **accepts** those two traits, which is the
   behaviour of a host asked first, and the differential asks the refusals it relies on one after
   another at the very end of the run, printing what it had before them so a process that dies among
   them is a truncated log and not a silent pass.
2. **The host prints an object trait's value inside a Swift optional**, `Optional(fr)`, `Optional(0)`,
   because the value it holds is one. This release has no Swift optional and no way to make one, so
   the port prints the value. The differential takes the wrapper off the host's text and **fails if
   the host ever stops printing it**, so the divergence is noticed rather than forgotten.

## What is not carried

- The four private trait classes of M3, and the two private class methods of M1. No SDK header
  declares any of the six, so nothing here answers them.
- The host's two private classes, `_UITraitOverrides` and `_UITraitRegistration`. No header declares
  either, and the port does not define them: the port's own classes for the two jobs are
  `CharonOverrides` and `CharonRegistration`, and M5 gives why the names are not shared.
- The Swift-only `UIKit.Trait` and its twenty-two case names, which are a typealias and enum cases in
  the corpus and carry no code at run time.
- The traits of a scene the release does not have: a scene capture state, an HDR headroom usage limit
  and a tab accessory environment all read as their unspecified values on a release that is never
  being recorded or shown in a tab accessory, which is what the header's own comments say they mean.

## What the host's UIKit can and cannot be asked about these protocols

The twelve protocol objects the objects of this series define are in the tree, and `nm` over
those objects is the evidence for them. The host differential cannot be: the SDK it compiles
against declares the trait protocols in its own `UITrait.h` **and the trait classes that adopt
them** — `@interface UITraitUserInterfaceIdiom : NSObject <UINSIntegerTraitDefinition>`,
`@interface UITraitDisplayScale : NSObject <UICGFloatTraitDefinition>` — so a class list read off
a trait class in that process is the SDK's declaration, not this library's, whatever
`CharonTraits17.h` says.

Measured, on this file's own group: taking `<UINSIntegerTraitDefinition>` off
`UITraitUserInterfaceIdiom` in `CharonTraits17.h` and giving `UITraitDisplayScale` the integer
kind as well both leave `traits17` at `checks=352 failures=0`, exit 0. The class is renamed to
`CharonHost…` and still carries the SDK's protocol list, because the declaration that binds is
the one in the SDK's header for the same name.

The one protocol in this delivery a host case *can* read is the range layer's `NSTextLocation`,
and only because `CharonTextLocation` is a name no SDK header uses — see
`facts/UIKit/NSTextRange15.md` and the case in `content15_test.m`, whose mutation drops that
declaration off the class and turns the group red.

## One path the differential does not reach

`UITraitCollection.m` declares `-displayScale` and `-setDisplayScale:` on the collection itself,
and `UITraitCollection+Traits17.m` declares the same pair as a category beside the integer and
object readers. A category method of a name the class has is the one the class answers with, so
the differential's read of `-displayScale` never reaches the category's pair - and neither does
the one existing case that calls `-valueForCGFloatTrait:` directly on the collection, because it
asks the reader and not the pair.

The pair is `-valueForCGFloatTraitClass:` and `-setCGFloatValueForTraitClass:value:`, and they are
not on the collection: `nm` over the built object has them on
`-[CharonHostCharonTraitMutations …]`, the port's own category on `NSObject`, and the collection's
own `-valueForCGFloatTrait:` on `-[CharonHostUITraitCollection(CharonTraits) …]`. So the two ways
in are two classes, and nothing in the group asks the `NSObject` one. Measured, by putting one
into the forwarding reader over a copy of the package and running the group: `checks=355
failures=0`, exit 0. Nothing is wrong with what the port answers - both paths reach the one
ivar - and a case asking `-valueForCGFloatTraitClass:` through the mutations category is what
would hold that path.

## The device run that has not happened

Everything above is the host's own UIKit and the port beside it. A real iPad 2 on 6.1.3 is the target
and has not been run: the collection's own traits on a device (idiom, scale, both size classes, the
style, the force touch capability the screen says is Unavailable), the description of a collection
holding a screen's traits, a registration firing on the release's own orientation change, and the two
private classes' names under the port's own loader. That run is what turns this from device-unverified
into device-verified, and it is the first thing the next session should do.
