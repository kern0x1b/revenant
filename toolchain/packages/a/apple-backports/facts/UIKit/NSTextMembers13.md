# Text members of iOS 13 and 14

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by the `views13` group of
`tests/backports/host/uikit2` and `tests/backports/device/uirest.m`.

## showCGGlyphs

`-[NSLayoutManager showCGGlyphs:positions:count:font:textMatrix:attributes:inContext:]` draws the glyphs with the context's text
matrix set to the one given, the font of the name and size, and the fill colour of `NSForegroundColorAttributeName` or black, at the
positions, by `CGContextShowGlyphsAtPositions`. The release's layout manager draws with `showPackedGlyphs:...` and never calls this
one, so it is called by an application's own layout manager subclass, and `super` reaches the port. The glyph numbers are those of
the font, the same in a `CGFont` as in a `CTFont`.

## Hyphenation

`usesDefaultHyphenation` is NO until set and is kept. The text system of iOS 6 hyphenates nothing by default, so YES changes no line
break; the first YES says so once in the log.

## Replacing attributed text

`-replaceRange:withAttributedText:` of `UITextInput` is answered by the text view and the text field: the range's characters are
replaced in the attributed text, the runs of the new text are kept, and the caret is put after it, wherever the selection was, as the
host does (twelve statements, six selections in a text view and in a text field). A range outside the text is clamped.

## Constants

`NSCocoaVersionDocumentAttribute` is `CocoaRTFVersion`, `NSTextScalingDocumentAttribute` and `NSSourceTextScalingDocumentAttribute` are
`TextScaling` and `SourceTextScaling`, and the options `NSSourceTextScalingDocumentOption` and `NSTargetTextScalingDocumentOption` are
`SourceTextScaling` and `TargetTextScaling`. The release's importers and writers read none of them. `NSTrackingAttributeName` is
`CTTracking`; the attribute stays on the string and is read back, and the text is drawn without tracking, since the release's
CoreText has no tracking.

### Correction, iOS 13-14 band, 2026-09-23

`NSCocoaVersionDocumentAttribute` was registered `introduced: 13.0`, read off the SDK 16.4 header's `API_AVAILABLE` annotation, the
same trap `UIFontWidth*` already caught this band: header availability is when Apple published the symbol, not when it first exports
in a real binary. `tools/release-split.lua`, walking the full 6.1.3-18.0 cache ladder, found `_NSCocoaVersionDocumentAttribute`
actually first exports at iOS 9.0 (`UIFoundation.framework` of that release), five releases earlier than the header says, and
confirmed the value byte-for-byte: `CocoaRTFVersion`, the same string this port already carries. `introduced` is corrected to `9.0`.

This is not a duplicate-symbol risk for the armv7 6.1.3 target this package builds for - iOS 6.1.3 does not export the symbol at
all (checked directly against its own cache, not just against the header), so the port's definition is still the only one linking
in. It was a real risk for any deployment target from 9.0 up sharing the same source file as the four other, genuinely
never-native constants (`NSTextScalingDocumentAttribute` and the rest, "none" across the entire cache ladder): `band()` refuses to
link an object file whose symbols first arrive in more than one release for the release actually being built, so a 9.0+ deployment
build of the old, unsplit `NSAttributedString+Constants13.m` would have failed at link time (or worse, silently shipped a
now-redundant definition, if the exact release boundary this port checks against happened to round both up together). Moved to its
own object file, `NSAttributedString+Constants9.m`, so it drops out cleanly - reexported, not redefined - once the deployment
target reaches 9.0.

## `+[NSTextAttachment textAttachmentWithImage:]`

The release's own `NSTextAttachment` holds an image. Its selector table on 6.1.3, in
`UIFoundation`, carries `-image`, `-setImage:`, `-initWithData:ofType:`, `-attachmentCell`,
`-contentView` and `-drawingBounds`, and the SDK's header dates `image` and `bounds` to iOS 7.0
(`NSTextAttachment.h:74,77`) - the header is not what decided this, the class-scoped read of the
6.1.3 cache is, and the earlier claim on this page that "the release's NSTextAttachment holds no
image, and its text views draw no attachment" was false of the release in both halves.

The host's own `+[NSTextAttachment textAttachmentWithImage:]` under Mac Catalyst answers an
attachment whose `image` is the object passed, whose `contents` and `fileType` are nil, and whose
`bounds` are `CGRectZero` - it sets the image and leaves the size to the text system, which derives
the layout bounds from the image when `bounds` is zero. A nil image gives an attachment, not nil.
Measured in `.agent-work/runs/gb04uikit13/probe/host-attachment.m`, and the layout half in
`host-attachment2.m`: an image-backed, a data-backed and a fresh attachment all lay out at the
same advance, which is what "the text system derives the bounds" looks like on the host.

`UIKit/NSTextAttachment+Image13.m` is that: the release's own designated initializer with neither
argument - the case the SDK header describes as "an attachment without document contents" - and one
`setImage:`. It is a category because `NSTextAttachment` is the release's class, not the port's, and
the port's 7.0 file already adds to it. The setter is a send and not `attachment.image = image`
because `-image` is `NS_NONATOMIC_IOSONLY` and the dot syntax does not compile on iOS. The port's
body is run verbatim against a stand-in class in `port-attachment.m`: four of four agree with the
host, and the control is the defect the arrangement exists to prevent - a setter that keeps the
last image, which turns the fourth check red.

## `-[NSTextList initWithMarkerFormat:options:startingItemNumber:]`, iOS 16.0

The release carries `NSTextList` itself, in UIFoundation (`objc.inventory` on 6.1.3), with `initWithMarkerFormat:options:` and
`startingItemNumber`. `UIKit/NSTextList+Init16.m` is those two in a row: the release's initializer, then the starting number set on the
list it made. It adds no state and draws nothing the release did not; the release's text views draw no list markers either way.
`objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-rest.log`): the three-argument initializer is not in 6.1.3 or 12.0 and
is in 16.0 and 18.0, the two-argument one is in all four. No 13-15 cache, so `introduced` stays the header's 16.0. Run on a device: the last section.

## `NSTextList`, the class

UIFoundation carries `NSTextList` from iOS 6.0 and exports it from 9.0 (`objc.inventory` and the exports of the shared caches of 5.1.1
to 10.3.4: none in 5.1.1, carried and not exported in 6.0 to 8.4.1, exported in 9.0 and later, `.agent-work/plan-and-analysis/b1314-catcheck/textlist-ladder.log`; the SDK's header says iOS 7.0). An
application that links the class does not start on a release that does not export it. `UIKit/NSTextList.m` exports the name as an
alias (`charon_alias.h`, as `UIKit/NSTextTab.m` does for `NSTextTab`, carried and not exported before 7.0).

## The aliases, `NSTextList` and `NSTextTab`

`CHARON_ALIAS(Name)` defines `CharonName` and exports `_OBJC_CLASS_$_Name` and its metaclass as aliases of it, so what an
application links is `CharonName`. What the port does with it:

- The library's loader (`attach.c`, `charon_reparent`) makes `CharonName` a subclass of the release's class before the runtime
  first uses it: it writes the release's class into the second word of `CharonName`'s class and of its metaclass - `superclass`,
  after `isa`, in the class structure the compiler emits for every class, in the library's own data - and then has the runtime
  lay it out, which lays it out after the release's instance variables. The loader then checks it through the public
  functions: `class_getSuperclass` is the release's class and `class_getInstanceSize` is the release's. What else was weighed:
  - a superclass given at compile time, `@interface CharonName : Name`: the alias itself defines `_OBJC_CLASS_$_Name`, so the
    superclass would be the class itself; and without the alias the reference is a weak import, NULL on a release that does
    not export the class, and the runtime drops a class whose weak superclass is missing;
  - `objc_allocateClassPair(release, ...)`: it makes a class at run time, and no symbol can name it, while an application's
    subclass has its superclass bound at load to `_OBJC_CLASS_$_Name`, the alias; it would still inherit from the alias;
  - `class_setSuperclass`, the one public function that changes a superclass (deprecated from iOS 2.0 in the header): it
    works on a class the runtime has laid out already, and does not lay it out again. Measured by `textalias.m` on the test's
    own `NSTextTable` alias, which the runtime laid out before the loader: after `class_setSuperclass(CharonNSTextTable,
    NSTextTable)` its superclass is the release's class and its size stays NSObject's, 4 bytes, where the release's `NSTextTable`
    is 52, and the test's subclass has its first instance variable at offset 4, inside the release's (the same on iPhone4,1
    6.1.3 and iPhone2,1 6.0 in the emulator). So a subclass written of it has its instance variables where the release's
    are, and making one would write over them.
- So a subclass an application writes of the name inherits the release's class and has its instance variables after the
  release's; `+alloc` of the subclass makes the subclass.
- Sent to the name itself, the class methods of NSObject answer as the release's class does: `+class`, `+alloc`,
  `+allocWithZone:`, `+superclass`, `+isSubclassOfClass:`, `+instancesRespondToSelector:`, `+instanceMethodForSelector:`,
  `+instanceMethodSignatureForSelector:`, `+conformsToProtocol:`, `+respondsToSelector:`, `+methodForSelector:`, `+description`,
  `+hash` and `+isEqual:`; what the release's class answers beyond them is forwarded to it. Sent to a subclass, they answer as
  NSObject's do, and `+superclass` of a direct subclass is the release's class.
- What differs: the name's own object is not the release's class. `[Name isEqual:release]` is YES, `[release isEqual:Name]`
  is NO (NSObject compares the objects, and the release's class is not ours to change); `class_getName`, `object_getClass`
  and the other C functions of the runtime, given the linked name rather than `[Name class]`, answer `CharonName`; and
  `class_getSuperclass` of a direct subclass is `CharonName`, whose superclass is the release's class.
- ld64 merges a category written on the name in the library into `CharonName`. The loader gives the release's class each method
  of it the release's class lacks, and gives `CharonName`'s copy of each method the release's class has the release's
  implementation, so that a subclass reaches the same method a plain instance does.
- A class of an image loaded with the library that has a `+load` of its own and subclasses the name makes the runtime lay
  `CharonName` out on NSObject before the loader runs. The loader's check fails, it takes its write back, and the log says
  `apple-backports: CharonName was laid out before the library's loader ran`; the name still answers as the release's class,
  and that subclass does not inherit it.
- A category on a class the release carries without exporting, written without an alias, has a NULL class reference, and the
  loader has nothing to attach it to: the gate refuses it and names `charon_alias.h` (`unattached_categories` in
  `modules/apple/backports.lua`).

## An alias whose class the release has in some of the bands and in none of the others

`NSTextList`, `NSTextTab` and `CPListItem` are all carried on every release their object is kept for (measured on
6.1.3, 7.1.2, 8.0, 8.4.1 and 9.0 above), so every band that keeps one of those objects takes the released answer and the
proxy is never the class. `NSURLSessionStreamTask` is the first name the release carries in **some** of the releases a
band is built for and in none of the others -- nothing below 8.0 has a class of that name, 8.0 through 8.4.1 carry one in
CFNetwork with no instance variable and no method of its own and export no symbol for it, and 9.0 exports it (the table and
the `objc.code_map` measurement are in `facts/Foundation/NSURLSessionStreamTask.md`). On the bands below 8.0 the release has
no class of the name at all, so the loader has nothing to re-parent the proxy onto and nothing to adopt its members into,
and the proxy **is** the class the name stands for. `charon_alias.h` answers for that case:

- The released answers are the released's class only where the runtime has a class of the name; where it has none, every
  class method answers as the proxy itself: `+class` is the proxy, `+alloc`/`+allocWithZone:` make an instance of `self`
  through `class_createInstance`, `+superclass` is the superclass the proxy was declared with, `+isSubclassOfClass:` and
  `+instancesRespondToSelector:`/`+instanceMethodForSelector:`/`+instanceMethodSignatureForSelector:`/`+methodForSelector:`
  walk the proxy's own chain (which is why they are not `[super ...]`: that answers about the class above the one asked
  about), and the root-class methods (`+respondsToSelector:`, `+conformsToProtocol:`, `+description`, `+hash`, `+isEqual:`,
  `+forwardingTargetForSelector:`) answer as they do for any class.
- `CHARON_ALIAS_OF(Name, Super)` declares the proxy with the superclass the name has, which a name whose release class is
  an `NSObject` descendant gets from `CHARON_ALIAS(Name)` and `NSURLSessionStreamTask` names as `NSURLSessionTask`: the
  seven methods call through `[super ...]` to the SDK's own hierarchy, and on a release that has the class the loader
  re-parents the proxy onto a class that is itself below `NSURLSessionTask`, so the chain is the same one either way.
- `attach.c`'s `charon_release_class` gives a category written on an aliased name to the release's class where there is one
  and to the proxy where there is none, instead of answering nil and dropping the category.
- `unattached_categories` in `modules/apple/backports.lua` accepts an alias whose class the release of the band does not
  carry where the band's own binaries define the proxy: the proxy is a class of the band, the alias resolves to it, and the
  members the categories add are on it already. An alias record with no proxy in any binary of the band is still refused,
  though a library that links cannot produce one -- the `.set` in `charon_alias.h` has nothing to resolve to.

**What was not measured.** None of this was run: the alias shape needs the package's own linker, and the macOS linker
refuses it -- measured 2026-10-04 on `CHARON_ALIAS` exactly as it stands on main, `ld: null objc class data for
'_OBJC_METACLASS_$_CharonNSCharonProbeAbsent'` -- so a host probe of these answers is not available, and the host tests
rename the symbols away (`tests/backports/host/uikit2/renames.sh`). What is measured is the link and the band machinery: the
object exports the release's name and the proxy at one address each (`nm -gU` in the stream task's facts page), the library
links, and `unattached_categories` and `duplicated` name nothing for that library on 6.1.3, 7.1.2, 8.0, 8.4.1 and 9.0. The
runtime half -- what the loader hands the release's class on 8.x, and what the proxy answers on 6.x -- is the same code path
`tests/backports/device/textalias.m` measures for the three aliases that are kept on every band, and it is that test, on a
device or an emulator, that would measure it for this one.

## Measured

`tests/backports/device/textalias.m`, 61 checks, built by `@addon/charon/daemon` (addon `v0.8.10`) against the package of commit
`dacc7278`, whose library code is the branch's last, and run by `xmake emulate`: 61 of 61 on an emulated iPhone4,1 of iOS 6.1.3
(10B329) and 61 of 61 on an emulated iPhone2,1 of iOS 6.0 (10A403) (`.agent-work/plan-and-analysis/b1314-catcheck/`
`textalias-emulate613.txt`, `textalias-emulate60.txt`). The emulator runs the release's own dyld, runtime and UIFoundation,
which is what the aliases and the loader depend on. The same subclass check answers YES for `NSTextList`, which the loader
put under the release's class, and NO for the test's own `NSTextTable`, laid out before the loader ran, so the check tells the
two apart. On a device: an iPad 2 (iPad2,2) of iOS 6.1.3 (10B329) ran the same test against the full gate's libraries of
`249d6da2`, whose library code is the branch's last, loaded from a directory of their own (`DYLD_PRINT_LIBRARIES` names both),
61 of 61, with the same sizes and offset for `class_setSuperclass` (`textalias-ipad2-gate3.txt`).
