# UIKit's 18.0 band in this port: the ladder, the one member with substrate, and the 32 names

Every row of `registry/UIKit/ios17-18.json` whose `introduced` is 18.0 is one of 103: 28 classes,
4 protocols, 37 methods and 34 properties. This page holds the measurement all of them rest on, the
one member the port answers with behaviour, and the 32 rows that are carried as names and what that
carries - which is the symbol and nothing else, and saying so is the point of M3.

## M1. Both band ends, class-scoped, with the controls in the same run

```
$ REVENANT_ROOT=$PWD xmake l ./tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
$ REVENANT_ROOT=$PWD xmake l ./tools/corpus/objc-inventory.lua ~/.revenant/dyld/4.3/dyld_shared_cache_armv7
```

6.1.3: 12549 lines, 11378 classes, 1171 protocols, 705 of the classes named `UI*`.
4.3: 7751 lines, 7187 classes, 564 protocols, 597 named `UI*`.

Seven selector controls, each read class-scoped - the class that must own it does:

| selector | 6.1.3 | 4.3 |
| --- | --- | --- |
| `-[UITabBarController selectedViewController]` | on UITabBarController | on UITabBarController |
| `-[UITabBarController setViewControllers:animated:]` | on UITabBarController | on UITabBarController |
| `-[UITextView text]` | on UITextView | on UITextView |
| `-[UIColor blackColor]` | on UIColor | on UIColor |
| `-[UIColor clearColor]` | on UIColor | on UIColor |
| `-[UITableView reloadData]` | on UITableView | on UITableView |
| `-[UIViewController viewDidLoad]` | on UIViewController | on UIViewController |

The two `UIColor` entries are class methods and the dump writes every selector in a class's column
with a `-`, so they read `-blackColor` and `-clearColor` there; the class that owns them is the one
named above, which is the part that makes them controls.

**Checked row by row, all 71 absent member rows of the band.** For each one, either the row's own
class is in neither dump, or the class's own selector list in both dumps holds neither the name, nor
its `is`-getter form, nor its `set-` form. **Zero rows where the claim fails.** 36 of the 71 name a
class that is itself of 18.0 and is in neither dump - `UIBackgroundConfiguration`,
`UIListContentConfiguration`, `UIListContentImageProperties`,
`UICollectionLayoutListConfiguration`, `UITabBarControllerDelegate`, `UITextInput`,
`UITextViewDelegate` - and for those the claim is the class's own absence, not a selector's.

**`UITraitCollection` is in neither dump**, which is why a member of it is a member of a class the
port owns rather than one the release carries (see M2).

### A selector index that cannot be used for this, so nobody uses it again

The cheap reading looks like the right one and is not:
`grep -cxF separatorInsetReference ~/.revenant/dyld/6.1.3/selectors_armv7.txt` answers 0, and so does
the same file for plain `separatorInset`, which `first-rung.lua` places at **7.0**, while the same
file answers 1 for `reloadData`. `selectors_armv7.txt` is a partial index: a zero in it says nothing
about the release. `first-rung.lua` is the reader with a self-test, and the class-scoped dump above
is the reader that answers the question these rows ask. Measured 2026-10-03.

## M2. The one member the port carries: `+[UITraitCollection traitCollectionWithListEnvironment:]`

The band has exactly one member with substrate, and it is this one, because the port owns
`UITraitCollection` itself (M1) and already keeps the list-environment trait on both sides of the
store:

- `UITraitListEnvironment` is `implemented`, minimum 6.0 (`registry/UIKit/ios17traits.json`,
  defined in `UITraitList18.m`), so the class is exported in every band the constructor's object is
  in - the one link-time dependency this object has, and it is a dependency the band keeps;
- `-[UITraitCollection listEnvironment]` is `implemented` and reads through the store's own reader,
  `REVENANT_TRAIT_PROPERTY([UITraitListEnvironment class], UIListEnvironment, listEnvironment,
  setListEnvironment)` at `UITraitCollection+Traits17.m:239`;
- `+[UITraitCollection traitCollectionWithNSIntegerValue:forTrait:]` at
  `UITraitCollection+Traits17.m:321` is the store's own writer, and `UITraitList18.m`'s
  `REVENANT_TRAIT(17, UITraitListEnvironment, @"ListEnvironment", RevenantTraitValueNSInteger,
  RevenantTraitHomeExtras, @(0), YES)` declares this trait's kind to be the writer's kind.

So the constructor is one call to the writer, and what it writes is what `-listEnvironment` reads.
`packages/a/apple-backports/UIKit/UITraitCollection+TraitConstructors18.m` is that call.

### What the system's own UIKit answers, measured

`.agent-work/runs/w-uikit-18/probe-listenv.m` in the worktree this landed from, compiled for
`arm64-apple-ios18.0-macabi` against the host's own UIKit, one collection per line:

```
enum controls: Unspecified=0 None=1 Plain=2 Grouped=3
Unspecified                                          -> listEnvironment=0  description=<UITraitCollection; >            (no ListEnvironment at all)
None                                                 -> listEnvironment=1  description=<UITraitCollection; ListEnvironment = 1>
Plain                                                -> listEnvironment=2  description=<UITraitCollection; ListEnvironment = 2>
Grouped                                              -> listEnvironment=3  description=<UITraitCollection; ListEnvironment = 3>
out of range 99                                      -> listEnvironment=99 description=<UITraitCollection; ListEnvironment = 99>
negative -1                                          -> listEnvironment=-1 description=<UITraitCollection; ListEnvironment = -1>
a collection with no list environment set            -> listEnvironment=0
same collection's other traits are untouched         -> userInterfaceStyle=0
```

Three things the port's answer therefore has to agree with, and does:

1. **the value goes under the trait's own name**, `ListEnvironment`, and nothing else - the last line
   is the control that it is a trait and not a field the constructor kept;
2. **no argument is validated** - 99 and -1 are stored and read back unchanged, exactly as
   `UITraitCollection+TraitConstructors17.m`'s three constructors do, measured the same way for 17.0
   in `facts/UIKit/UIKit17Absence.md` M15 (`imageDynamicRange 99 -> ImageDynamicRange = 99`);
3. **`Unspecified` is the absence of the trait**, not a stored zero: its description carries no
   `ListEnvironment` at all while every other case does. The port's own answer for an unset
   collection is the trait class's default, which `UITraitList18.m` declares as `@(0)` - the same
   value, reached the way the store reaches it, and for the same reason: `Unspecified` is 0.

The 16.4 SDK the package compiles against has no `UITrait.h` (the trait classes reached UIKit in
17.0), so `UIListEnvironment` and `UITraitListEnvironment` come from `RevenantTraits17.h` behind the
`__has_include` the rest of the tree uses, and the object's own declaration sits behind the same
guard - the same reason, and the same shape, as `UITraitCollection+TraitConstructors17.m`.

**Compiled as the build compiles it**, with the flags `modules/apple/backports.lua` assembles
(`-Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability
-Werror=objc-missing-property-synthesis`, ARC, the package on the include path):
`clang -fsyntax-only -target armv7-apple-ios6.1.3` and `armv7-apple-ios4.3` each print **0 lines
matching ` error: `**, and the two warnings each prints are the nullability notes from
`RevenantTraits17.h` that the 17.0 constructors file beside it prints in the same run.

## M3. The 28 class rows and the 4 protocol rows: carried as names, and why that is not a fake

These 32 rows are `implemented`, and the whole of what they carry is the dyld symbol. An application
that links strongly against `UITab` names `_OBJC_CLASS_$_UITab`, and dyld has to resolve it before
`main` runs; a row that said `absent` for that name would be describing an application that does not
launch. `COORDINATION.md` section 2 says it in one line - "**`absent` for a strong-imported class
symbol is forbidden** - that is not a missing feature, that is dyld killing the application at launch"
- and the same ground already carries `RevenantUIKit26.h`'s twenty-one 26.0 classes and the 18.2 and
18.4 classes of `RevenantUIKit18.h`.

**What is carried, measured on the object the band build produces:**

```
$ clang -c -fobjc-arc -target armv7-apple-ios6.1.3 -isysroot <16.4 SDK> UIKit18_0.m -o UIKit18_0.o
$ otool -v -s __TEXT __objc_classname UIKit18_0.o | grep -cE '^[0-9a-f]{8}  '
28
$ otool -s __TEXT __objc_methname UIKit18_0.o
(section empty)
```

28 class names, and **no selector at all** - which is the point stated as a measurement rather than as
a claim: the object carries the twenty-eight symbols and nothing else. The same run at
`armv7-apple-ios4.3` prints 0 lines matching ` error: `, and so does the compile at 6.1.3.

**No conformance is declared, and that is a decision with a reason.** 26.2 gives these classes
`NSCopying`, `NSSecureCoding` and `CTAdaptiveImageProviding`. Transcribing a conformance without its
method is a promise about a method, and its first caller would crash on `copyWithZone:` - the
opposite of what a name-only class is for. So none is declared, and no row claims one.

**Three superclasses are transcribed, because an inheritance is what a caller compiles against and
both parents resolve:** `UITabGroup` and `UISearchTab` inherit `UITab`, which this same object
exports, and `UITextFormattingViewController` inherits `UIViewController`, which the port already
carries. An instance of the child answers everything the parent answers.

**`UICalendarSelectionWeekOfYear` is the exception and the row says so:** 26.2 declares it over
`UICalendarSelection`, the port carries no `UICalendarSelection` (`registry/UIKit/ios15-16.json` has
that row `absent`), and a class whose superclass the library does not export cannot be resolved by dyld
at all. It is declared over `NSObject` rather than trade a missing symbol for a worse one.

**The four protocols** are carried by the source `modules/apple/backports.lua` writes for the band -
`UIKitBackportsProtocols18.0.m` - and their declarations are transcribed into `RevenantUIKitProtocols.h`
with their members, because a forward declaration is not enough there and the check says so:

```
$ sh tests/addon/protocol-sources.sh <16.4 SDK> .agent-work/runs/w-uikit-18/protocols
57 protocol sources over 24 libraries, each at the triple of its rows' minimum
protocol-sources: OK - 57 of 57 protocol sources compile for armv7 against the 16.4 SDK
$ otool -v -s __TEXT __objc_classname UIKitBackportsProtocols18.0.o
00000002  UICalendarSelectionWeekOfYearDelegate
00000028  NSObject
00000031  UITabBarControllerSidebarAnimating
00000054  UITabBarControllerSidebarDelegate
00000076  UITextFormattingViewControllerDelegate
```

**What a caller gets, and what it does not:** the names resolve, the classes allocate, and a selector
of 18.0 sent to an instance gets `doesNotRecognizeSelector:` - which is what a class that exists and
has no such method answers, and the honest end on a release that has no tab sidebar, no formatting
panel, no zoom transition and no update link. Nothing here is stored, believed for nothing, or claimed
to steer anything: the difference from the case COORDINATION.md also forbids - a quietly-different
answer - is that this one makes no answer at all.

The transcription is read from the SDK that declares these names, the host's own UIKit under Mac
Catalyst (`$(xcrun --show-sdk-path)/System/iOSSupport/System/Library/Frameworks/UIKit.framework/Headers`):
all twenty-eight `@interface` declarations are there, and so are the four protocols with their members
(`UITabBarControllerSidebar.h`, `UITextFormattingViewController.h`, `UICalendarSelectionWeekOfYear.h`).
No SDK this package compiles against declares any of the 32 - the 16.4 build SDK has no `UITab.h`, no
`UITrait.h` and no 18.0 protocol - which is why the declarations are here at all.

The other 71 member rows of the band are the `absent` ones of M1, and they are untouched by this.

**Not claimed:** that a 6.1.3 or 4.3 release could have displayed a list environment had it carried
the constructor. Neither does: M1 measured the class out of both band ends. What M2 measures is what
the constructor has to agree with where one exists, which is the host's own UIKit. And not claimed of
M3 either: that any of the twenty-eight classes can do anything. They resolve, they allocate, and a
selector of 18.0 sent to one gets `doesNotRecognizeSelector:`.