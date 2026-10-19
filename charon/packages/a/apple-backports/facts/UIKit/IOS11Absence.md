# What the 6.1.3 and 4.3 releases carry of what iOS 11.0 added to UIKit

`registry/UIKit/ios11.json` holds 194 rows for the release that introduced them: 88 already
implemented by the port, 71 `absent`, 31 `inert`, 4 `ignored`. The `absent` rows are claims about a
**release**, not about the port — `modules/apple/backports.lua:1901` fires "listed as absent, but the
release carries it itself" for exactly that mistake, so a row is only allowed to say `absent` when the
release really does not answer the name. This page is that check for the file, run once and pasted.

## The measurement

    CHARON_ROOT=<worktree> sh packages/a/apple-backports/facts/UIKit/ios11-absence-census.sh

The script beside this page asks every owner-scoped name the file's `absent` rows name, one release at
a time, through `tools/corpus/objc-inventory.lua` — the tree's own reader, reading each release's own
dyld shared cache. It needs no SDK and no compiler, only the held caches under `$HOME/.charon/dyld`.

**The control is in every line.** Each rung prints its class and protocol counts before its answers,
and 11.0 is a rung the slice's names genuinely exist on: `adjustedContentInsetDidChange=PRESENT`,
`viewSafeAreaInsetsDidChange=PRESENT`, `hasUncommittedUpdates=PRESENT`, and every other name the file
carries as `absent` for 6.1.3 answers PRESENT on 11.0 in the same run. A zero on 6.1.3 beside a
52768-class rung that answered every one of them is the 6.1.3 release's answer and not the reader's.
The class-and-protocol half is the same run through `tools/corpus/cache-census.lua`, which prints its
own `control:` line per name and certifies nothing without it.

**One reader bug was found and fixed before this page existed.** The first run of the selector half
asked for `setFrame:` and every rung answered "no" — for a class that certainly has it. The keys are
not bare selector names: `objc.inventory` keys them `-setFrame:`, with the sign, so the check was
looking up a name the reader had never stored. Every rung answering "no" was the reader being wrong,
and no row was written from it. The control is what caught it; the same command with the sign in the
key is the one below.

## What the run says

    6.1.3/dyld_shared_cache_armv7          11378 classes 1171 protocols  adjustedContentInsetDidChange=no
    4.3/dyld_shared_cache_armv7              7187 classes  564 protocols  adjustedContentInsetDidChange=no
    11.0/dyld_shared_cache_arm64            52768 classes 8954 protocols  adjustedContentInsetDidChange=PRESENT

    6.1.3/dyld_shared_cache_armv7   viewSafeAreaInsetsDidChange=no  viewLayoutMarginsDidChange=no  systemMinimumLayoutMargins=no  viewRespectsSystemMinimumLayoutMargins=no
    4.3/dyld_shared_cache_armv7     viewSafeAreaInsetsDidChange=no  viewLayoutMarginsDidChange=no  systemMinimumLayoutMargins=no  viewRespectsSystemMinimumLayoutMargins=no
    11.0/dyld_shared_cache_arm64    viewSafeAreaInsetsDidChange=PRESENT  viewLayoutMarginsDidChange=PRESENT  systemMinimumLayoutMargins=PRESENT  viewRespectsSystemMinimumLayoutMargins=PRESENT

    6.1.3/dyld_shared_cache_armv7   hasUncommittedUpdates=no  insetsContentViewsToSafeArea=no  separatorInsetReference=no
    4.3/dyld_shared_cache_armv7     hasUncommittedUpdates=no  insetsContentViewsToSafeArea=no  separatorInsetReference=no
    11.0/dyld_shared_cache_arm64    hasUncommittedUpdates=PRESENT  insetsContentViewsToSafeArea=PRESENT  separatorInsetReference=PRESENT

    6.1.3/dyld_shared_cache_armv7   itemProviders=no  setObjects:=no  setObjects:localOnly:expirationDate:=no  setItemProviders:localOnly:expirationDate:=no
    4.3/dyld_shared_cache_armv7     itemProviders=no  setObjects:=no  setObjects:localOnly:expirationDate:=no  setItemProviders:localOnly:expirationDate:=no
    11.0/dyld_shared_cache_arm64    itemProviders=PRESENT  setObjects:=PRESENT  setObjects:localOnly:expirationDate:=PRESENT  setItemProviders:localOnly:expirationDate:=PRESENT

    6.1.3/dyld_shared_cache_armv7   accessibilityContainerType=no  accessibilityDragSourceDescriptors=no  accessibilityDropPointDescriptors=no
    4.3/dyld_shared_cache_armv7     accessibilityContainerType=no  accessibilityDragSourceDescriptors=no  accessibilityDropPointDescriptors=no
    11.0/dyld_shared_cache_arm64    accessibilityContainerType=PRESENT  accessibilityDragSourceDescriptors=PRESENT  accessibilityDropPointDescriptors=PRESENT

`UIBarItem largeContentSizeImage`/`largeContentSizeImageInsets`, `UISplitViewController primaryEdge`,
`UICollectionView hasUncommittedUpdates`/`reorderingCadence`, `NSItemProvider`'s three, and both
`shouldSpringLoad…withContext:` selectors read the same way: **no** on 6.1.3 and 4.3, **PRESENT** on
11.0.

## The owners that are not there at all

Nine of the file's owners are absent from both band ends, which is a different answer from a class
that is there and lacks the member — there is nothing to carry the member on. Each says "owner absent"
on 6.1.3 and 4.3:

    UIFocusAnimationCoordinator   UIAccessibilityCustomAction   NSItemProvider   UITextDocumentProxy
    UIPickerViewAccessibilityDelegate   UIInputViewController   UIScrollViewAccessibilityDelegate

`UIAccessibilityReadingContent` is the interesting one: it **is** a protocol on 6.1.3 (1171 protocols
there) and carries neither attributed member, and it is gone by 4.3. `UICollectionView` and
`UICollectionViewDelegate` are absent on 4.3 and present on 6.1.3, which is why the 4.3 line for the
collection view reads "owner absent" and the 6.1.3 line reads "no" rather than PRESENT.

`UIPickerViewAccessibilityDelegate` is absent on **all three** rungs including 11.0 — it is a private
protocol Apple's own header does not publish, and the two rows that name it are absent for a reason no
cache settles: this release's VoiceOver reads the plain `pickerView:accessibilityLabelForComponent:`,
which the 6.1.3 protocol list carries (`UIPickerViewDelegate` is in it).

## The class and protocol names

Asked by name through `cache-census.lua`, each prints its own control:

    == UITextDropProposal
           images 524, of which naming UITextDropProposal 0      (6.1.3)
           images 354, of which naming UITextDropProposal 0      (4.3)
           images 1258, of which naming UITextDropProposal 0     (11.0 images)
           classes 52768, of which UITextDropProposal* 1 (UITextDropProposal)   (11.0)
    control: 1 name(s) beginning UITextDropProposal found in this run, so a zero on another rung is the release's and not the reader's

    == UISpringLoadedInteraction
           11.0 classes: UISpringLoadedInteraction, UISpringLoadedInteractionContextImpl
           11.0 protocols: UISpringLoadedInteractionBehavior, ...Context, ...Effect, ...Supporting
    control: 10 name(s) beginning UISpringLoadedInteraction found in this run

Every other name in the class-and-protocol half — `UIFocusSystem`, `UIFocusDebugger`,
`UIFocusDebuggerOutput`, `UIFocusAnimationContext`, `UIPasteConfiguration`,
`UIPasteConfigurationSupporting`, `UITextPasteConfigurationSupporting`, `UITextPasteDelegate`,
`UITextPasteItem`, `UIItemProviderPresentationSizeProviding`, `UIDataSourceTranslating`,
`UIAccessibilityContainerDataTable`, `UIAccessibilityContainerDataTableCell`,
`UIAccessibilityContentSizeCategoryImageAdjusting`, `UIAccessibilityLocationDescriptor`,
`UIDocumentBrowserAction` — reads **0 classes, 0 protocols, 0 images on 6.1.3 and on 4.3**, and every
one of them is found on 11.0 or a sibling rung, which is what certifies the zero. The script pastes
the control line for each.

## What this settles, and what it does not

It settles the **release** half of every `absent` row in the file: at 6.1.3 and at 4.3 the name does
not exist, so `absent` is the answer the status means and `respondsToSelector:` may answer honestly.
Three rows of the file did not have this — `UITableView.hasUncommittedUpdates`,
`UIViewController.systemMinimumLayoutMargins` and
`UIViewController.viewRespectsSystemMinimumLayoutMargins` cited only *"UIKit of iOS 11.0 arm64, -[…]
at 0x…"*, which is the SDK's own declaration of the release that **has** the name and says nothing at
all about 6.1.3. Those rows now cite this run.

It does not settle whether the **port** could carry a name anyway. That is the other half of an
`absent` row and it is argued from the substrate, not from a cache: the focus engine is not there
(only GameKit's `GKFocusButton` and PhotoLibrary's `PLCameraFocusView` carry "Focus" in either cache),
spring loading needs a drag that leaves the application, the paste configuration is read by a menu
this release has not got, and the extension-side owners need an extension host. The one row of the
family whose substrate the port supplies — `UITextDropProposal`, which `CharonTextDropRequest` holds
and `UITextView+TextDragDrop11.m` stores a delegate's answer into — is the one this band wrote; see
`TextDragAndDrop.md`.

## The one object, and what it is built from

`UITextDropProposal` moved `absent` → `implemented`, so it is the band and not the audit. The port was
already typed over the class it did not define:

    CharonTextDragDrop11.h:22   @property (nonatomic, strong) UITextDropProposal *proposal;
    UITextView+TextDragDrop11.m:346   request.proposal = (UITextDropProposal *)objc_msgSend(delegate, …);

`objc.code_map` over UIKit of iOS 11.0 arm64 gives the class its superclass (`UIDropProposal`), four
ivars of its own and ten methods. The two that decide behaviour were decoded, and the literals were
settled by assembling candidates with the pinned clang and matching encodings rather than by decoding
bitmasks — the first decoder run read `setPrecise:` as taking 0, which the header contradicts, and the
disagreement had to be measured away:

    -[UITextDropProposal initWithDropOperation:] 0x18a55caa0
        [super initWithDropOperation:] ; CBZ result ; setPrecise: ; setDropAction: ; setUseFastSameViewOperations:
    -[UITextDropProposal copyWithZone:] 0x18a55cb50
        [super copyWithZone:] ; then each of the four getters and setters, in that order

    mov x2,#0      -> 0xd2800002   (UITextDropActionInsert)
    orr w2,wzr,#1  -> 0x320003e2   (precise, and useFastSameViewOperations, both YES)

The object was then compiled for the port's own target and read back:

    clang -target armv7-apple-ios6.1.3 -fobjc-arc -c packages/a/apple-backports/UIKit/UITextDropProposal.m
    llvm-nm -gU UITextDropProposal.o
        00000280 S _OBJC_CLASS_$_UITextDropProposal

and the ten selectors out of its `__objc_methname` are the ten the 11.0 cache lists for the class:
`copyWithZone: dropAction dropPerformer dropProgressMode initWithDropOperation: setDropAction:
setDropPerformer: setDropProgressMode: setUseFastSameViewOperations: useFastSameViewOperations`.
**The properties' names and their selectors agree here**, which is not free: `@property(getter=isX)`
families in this file are where a row spells a name no selector carries, and the gate answers
"listed as implemented, but nothing of that name is built" for one.

And the release the object's API belongs to is one, which `release-split` reads off the symbol table
rather than off the file's name:

    xmake l tools/release-split.lua <objdir> <outdir> ~/Git/tools/sdks/iPhoneOS16.5.sdk
        release-split: clean, every object file's symbols first-appear in one release
                       (1 files, 2 symbols, 50 releases checked)

Two symbols is the class and its metaclass, which is what `exported_symbols` counts for a class object;
the ivars and the `NSCopying` metadata it also carries are excluded. This is the check that a mixed file
passes silently, because it reads band points and not the API — so it was run rather than assumed.