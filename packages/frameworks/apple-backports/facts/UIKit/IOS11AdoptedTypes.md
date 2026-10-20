# What iOS 11.0 added that a 6.1.3 application can adopt, and what it cannot

`UIKit/RevenantIOS11.m` is the port's one object for the 11.0 API this band settled. Everything it
exports belongs to 11.0 and to no other release, which is what `tools/release-split.lua` weighs: the
file's only `nm -gU` symbols that survive the tool's exclusions are the class and metaclass of
`UIPasteConfiguration` and of `UIAccessibilityLocationDescriptor`, and both classes first appear at
11.0. The categories in the file add members the tool does not weigh (its documented blind spot), which
is why every one of them is named in a registry row of its own.

## The measurement, and the control that certifies it

`objc-inventory.lua` over both caches, class-scoped, in one run each:

    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/4.3/dyld_shared_cache_armv7

The 6.1.3 dump holds 12549 lines (11378 classes, 1171 protocols); the 4.3 dump holds 7751 (7187
classes, 564 protocols). The control is in the same dumps and reads:

| control | 6.1.3 | 4.3 |
| --- | --- | --- |
| `-[UIViewController viewDidLoad]` | present | present |
| `-[UIPasteboard setItems:]` | present | present |
| `-[UIScrollView setContentInset:]` | present | present |
| `-[UITableView setSeparatorStyle:]` | present | present |
| `-[UIView frame]` | present | present |
| `-[NSObject hash]` | present | present |

Every member this object adds reads absent on both, with those six reading present beside it in the
same dump, so the zeros are the releases' and not the reader's.

For the names that are a whole class or a protocol rather than a member,
`tools/corpus/cache-census.lua` reads both ends and a third rung that does have the name, and prints its
own control:

    REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua UISpringLoaded 6.1.3 4.3 16.0
      6.1.3  images 524, of which naming UISpringLoaded 0; classes 11378, of which UISpringLoaded* 0; protocols 1171, of which UISpringLoaded* 0
      4.3    images 354, of which naming UISpringLoaded 0; classes 7187, of which UISpringLoaded* 0;  protocols 564,  of which UISpringLoaded* 0
      16.0   classes 143137, of which UISpringLoaded* 3 (UISpringLoadedGestureRecognizer UISpringLoadedInteraction UISpringLoadedInteractionContextImpl)
              protocols 25549, of which UISpringLoaded* 8 (...)
      control: 11 name(s) beginning UISpringLoaded found in this run

Two families needed a rung the ladder's 12.0 does not have: `UIAccessibilityContainerDataTable` and
`UIPickerViewAccessibilityDelegate` read `control: 0` at 6.1.3, 4.3 and 12.0, so the run certified
nothing, and the census was re-run at 16.0, which reads 2 and 1 respectively with a control of 2 and 1.
Both are declared by the SDK as 11.0 (`coordination/corpus/sdk-26.2-surface.tsv`), and
`tools/cache-index/first-rung.lua` answers 16.0 for both, which is the 12.0->16.0 hole in the held set
and not a later introduction.

## The two classes

`UIPasteConfiguration` says what a drop target accepts, as type identifiers. Its state is a set of
strings, and every operation on it is the set's: `-addAcceptableTypeIdentifiers:` skips an identifier
already there, which is what makes the add order independent; `-addTypeIdentifiersForAcceptingClass:`
asks the class for `+readableTypeIdentifiersForItemProvider` and adds nothing if the class does not
answer, because a class named there need not adopt `NSItemProviderReading` and a configuration that
accepted nothing would be worse than one that says what it has. It conforms to `NSSecureCoding` and
`NSCopying`, both of which the release has.

`UIAccessibilityLocationDescriptor` is four values: a name, the same name styled, a point and the view
the point is in. The three initialisers are one shape with two ways of naming it, so `-name` and
`-attributedName` never disagree. The view is held weakly, as the header declares.

## What this object deliberately does not do

The 11.0 API that is not here is not here because the release has no substrate for it, and each row
says which in its own `reason`. The families are spring-loading (a continuous hover that the release's
own drag gesture does not produce), the focus engine (`UIFocusSystem` and the debugger are UIKit's own
event handling), the keyboard's own access state (`UIInputViewController` answers for a keyboard
extension, and iOS 6 has no extension point for one), the document browser (`UIDocumentBrowserAction`
belongs to a document browser this port does not stand in for), the paste configuration protocols (the
port's own drag routing decides a drop in ViewDragDropRouting11.m and never asks a target what it
accepts), the data-table accessibility protocols (nothing in the port reads them), and the
image-scaling protocol (`UIFontMetrics`' own scale is the identity on this release, so there is no
measured ratio for an image to be adjusted by).