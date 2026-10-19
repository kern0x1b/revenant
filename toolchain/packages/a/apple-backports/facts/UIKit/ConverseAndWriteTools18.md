// Facts: UIKit's 18.x rows that arrived after the port's newest object, 24 rows, and why three of them
// are classes the port declares empty
//
// The queue names 147 rows in registry/UIKit/ios26.json; 93 of them were already implemented when this
// band started and this page is about the other 54.  They fall into two shapes, and the split is not a
// convenience - it is the whole answer for each row:
//
//   ELEVEN CLASSES THE PORT DECLARES EMPTY.  A class is a DYLD SYMBOL: an application that links
//   strongly against UIWritingToolsCoordinator names _OBJC_CLASS_$_UIWritingToolsCoordinator and dyld has
//   to find it before main runs.  No release this port targets carries any of the eleven, so the port is
//   the only thing here that can make the name exist, and for a name whose only requirement is that dyld
//   resolve it an empty class is the complete honest answer.  This is the same answer RevenantUIKit26.h's
//   twenty-one give, and the same reason.
//
//   FORTY-THREE NAMES NOTHING CAN CARRY.  A @protocol has no implementation: a category cannot be on
//   one, so its members are requirements on whatever object a caller passes and never something a port
//   can define under the protocol's own name.  Where the port owns a class for the selector it defines
//   the selector there and carries a row of its own; where it does not, the protocol-member row is the
//   honest end.  The eleven class names are in no held release either, and that is where they stop: an
//   empty class makes a NAME exist, and there is nothing in this release to put behind these ones beyond
//   the name - so for the members of the classes above, and for every name a release does not carry at
//   all, `absent` is the answer and no symbol is written.
//
// WHAT WAS MEASURED, and by what.  Every command below is one a reader can run; the output beside it is
// what this run of it printed.  Nothing here is taken from a header's availability annotation, which
// answers what a release SHOULD have, not what it has.
//
// 1. THE OWNER OF EVERY PROTOCOL-MEMBER ROW IS A PROTOCOL, IN EVERY RELEASE THAT HAS IT.  This is the
//    measurement that decides those rows, because it is what `carried_by_release` in
//    modules/apple/backports.lua reads (its protocol branch: an owner that is a protocol and not a
//    class can never be `held`).
//
//    Command, from the checkout root, one line per release:
//
//      REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/<release>/dyld_shared_cache_<arch>
//
//    It prints one TSV line per class and per protocol, so the answer is a grep over the owner name.
//    The four releases are both ends of every band this port stages: 6.1.3 is the deployment target,
//    12.0 the last release before the ladder's hole, 16.0 the first after it, and 18.0 the newest held
//    rung at all (dyld.held_ladder tops out there, so no name from a later release can be measured).
//
//      awk -F'\t' '{print $1"\t"$2}' inv-<release>.tsv | grep -E '^(class|protocol)\s+(UIMenuBuilder|UIResponderStandardEditActions|UISearchBarDelegate|UISplitViewControllerDelegate|UITextFieldDelegate|UITextViewDelegate|UIWindowSceneDelegate|UITextInput|UITextInputTraits)$'
//
//    What it printed, release by release:
//
//      6.1.3   protocol  UITextInput  UISearchBarDelegate  NSObject  UITextFieldDelegate
//               UITextViewDelegate  UITextInputTraits
//      12.0    protocol  UISearchBarDelegate  UITextViewDelegate  UITextFieldDelegate  UITextInputTraits
//               UISplitViewControllerDelegate  UIResponderStandardEditActions  NSObject  UITextInput
//      16.0    protocol  UITextInput  UITextFieldDelegate  UIMenuBuilder  UIResponderStandardEditActions
//               UITextViewDelegate  UISplitViewControllerDelegate  UISearchBarDelegate  NSObject
//               UITextInputTraits  UIWindowSceneDelegate
//      18.0    protocol  UIWindowSceneDelegate  UITextInput  UITextFieldDelegate  UIMenuBuilder
//               UIResponderStandardEditActions  UISearchBarDelegate  UISplitViewControllerDelegate
//               UITextViewDelegate  NSObject
//
//    ONE LINE OF THAT IS WORTH READING TWICE: UITextInputTraits is a `class` AND a `protocol` at 6.1.3,
//    12.0 and 16.0, and at 18.0 only the `class` is left.  The class carries an image - public
//    UIKit.framework at 6.1.3, private UIKitCore.framework from 12.0 on - and the protocol carries none,
//    which is why a category cannot be written for the protocol member even where a class of the same name
//    sits in the same inventory row set.
//
//    UIMenuBuilder and UIWindowSceneDelegate are in NO release below 16.0 at all - not as a class and not
//    as a protocol - and UITextInput, UITextFieldDelegate, UITextViewDelegate, UISearchBarDelegate,
//    UISplitViewControllerDelegate, UIResponderStandardEditActions and UITextInputTraits are protocols
//    everywhere they appear.  Not one of the twenty-nine is a class in any release, which is the whole
//    reason no category can carry one of them.
//
//    THE CONTROL, in the same run and the same shape of query: the same awk over the same files finds
//    `class UITextView`, `class UIViewController`, `class UISplitViewController`, `class UIApplication`,
//    `class NSObject`, `class UIResponder` and `class UITextInputTraits` in 6.1.3, and `class UIWindowScene`
//    in 18.0 with 221 instance selectors including `keyWindow`.  UIViewController in 6.1.3 carries 564
//    instance selectors.  A zero on another name is therefore the release's and not the reader's.
//
// 2. THE SELECTORS THEMSELVES ARRIVED WITH 26.0, NOT WITH THE RELEASE THAT HAS THE PROTOCOL.  Read off
//    the 16.0 protocol's own member list, which is the trap this family walks into: a selector's rung says
//    nothing about its owner, so `removeActionForIdentifier:` reads first-rung 8.3 and `toggleInspector:`
//    reads 16.0 while both belong to a 26.0 protocol member.
//
//      awk -F'\t' '$1=="protocol" && $2=="UIMenuBuilder"{print $5}' inv-16.0.tsv
//
//    What it printed: `-actionForIdentifier:,-commandForAction:propertyList:,-insertChildMenu:atEndOfMenuForIdentifier:,-insertChildMenu:atStartOfMenuForIdentifier:,-insertSiblingMenu:afterMenuForIdentifier:,-insertSiblingMenu:beforeMenuForIdentifier:,-menuForIdentifier:,-removeMenuForIdentifier:,-replaceChildrenOfMenuForIdentifier:fromChildrenBlock:,-replaceMenuForIdentifier:withMenu:,-system`
//
//    Eleven members, and not one of them is `insertElements:`.  iOS 16's protocol spells insertion
//    `insertChildMenu:`/`insertSiblingMenu:`; the `insertElements:` family is 26.0's own spelling and is
//    not in the release.
//
//    THE CONTROL, same file, same query shape: `awk -F'\t' 'index($5,"insertElements")||index($6,"insertElements")'`
//    over the whole 16.0 inventory prints exactly one row, `class NSStorage`, so the reader does read
//    selector lists and the eleven-member protocol list above is complete rather than truncated.
//
// 3. THE LADDER, for every name in this band.  One run, 54 names, with the tool's own self-test first:
//
//      xmake l tools/cache-index/first-rung.lua --self-test
//      xmake l tools/cache-index/first-rung.lua <names>
//
//    The self-test is the reader's certificate: `self-test: checks=8 failures=0`, with a positive control
//    answering 3.0 for _NSFileSize and a negative control answering NONE for a nonsense name.  Every one
//    of the eleven class names and the protocol printed NONE, and so did `insertElements:...` (all
//    thirteen spellings), `newFromPasteboard:`, `showWritingTools:`, `insertInputSuggestion:`,
//    `conversationContext:didChange:`, `defaultStatusForCategory:error:`,
//    `textView:shouldChangeTextInRanges:replacementText:` and the rest of the 26.0 members.  NONE is an
//    answer: the tool's own header says a name that arrived after 18.0 looks exactly like this, and 18.0
//    is the newest rung the ladder holds.
//
//    What DID answer is the same trap in its other direction: these selectors belong to another class in an
//    older release.  `alignLeft:`/`alignCenter:`/`alignRight:`/`alignJustified:` read 3.0,
//    `removeActionForIdentifier:` reads 8.3, `toggleInspector:` reads 16.0, `conversationContext` reads 16.0
//    and `unobscuredContentRect` reads 8.0 - where the owner is WebKit's WAKScrollView and WKContentView, never
//    UITextInput.  The same run places those owners: WAKScrollView reads 3.0, WKContentView reads 8.0 and
//    WKWebView reads 8.0, which is why the 6.1.3 inventory carries none of the three.  That is why the 26.4 row is an absence and not an accessor written from a remembered type.
//    The inventories above are what settles the owner question, and they settle it the same way for every one
//    of these: no owner in any of the four releases carries the member this row names.
//
// 4. NO APPLICATION IN THE CORPUS ASKS FOR THESE CLASSES.  This is the demand question, and it is
//    measured on the binaries rather than inferred from the queue.
//
//      nm -u coordination/corpus/<app>/extracted/Payload/<app>.app/<app> | grep -c '_OBJC_CLASS_\$_'
//
//    Provenance reads 316 undefined UIKit class references, UTM 146, PPSSPP 55 - and ZERO of them is any
//    of the twenty-two class symbols checked - the 26.0 band's eighteen and four of this band's
//    (UIGlassEffect, UIGlassContainerEffect,
//    UICornerRadius, UICornerConfiguration, UIScrollEdgeEffect, UIScrollEdgeEffectStyle, UIBarButtonItemBadge,
//    UIContextMenuSystem, UIColorWell, UIDeferredMenuElementProvider, UIMainMenuSystem,
//    UISceneDestructionCondition, UISceneWindowingControlStyle, UIScrollEdgeElementContainerInteraction,
//    UISliderTrackConfiguration, UISymbolContentTransition, UITabAccessory, UIViewLayoutRegion,
//     UIWritingToolsCoordinator, UIConversationContext, UIInputSuggestion, UISmartReplySuggestion).
//    So the classes are not here for a caller this corpus holds: they are here because a class whose
//    requirement is that dyld resolve it has no other honest answer, and the count above is what says the
//    empty class is not standing in for a demand we can measure but have not checked.
//
//    The same three binaries hold the STRING "UIConversationContext" inside them, and that is not demand:
//    corpus/defcache lists what binaries DEFINE, and a name among an app's own methods or classes is the
//    app's own - a port definition would shadow it.  Only the undefined-class count above is the signal.
//
// 5. THE HEADERS.  No header in the build SDK declares any of these names, which is what makes the port
//    the only thing that can make them exist:
//
//      ls ~/.xmake/packages/i/iphoneos-sdk/16.4/*/iPhoneOS16.4.sdk/System/Library/Frameworks/UIKit.framework/Headers | wc -l
//
//    351 headers, and @interface UIGlassEffect, @interface UIWritingToolsCoordinator and
//    @interface UIConversationEntry are in none of them - the same measurement RevenantUIKit26.h rests on.
//
//    AvailabilityVersions.h in that same SDK defines __IPHONE_16_4 as its highest macro and no
//    __IPHONE_17_* or __IPHONE_18_*, which is why RevenantUIKit18.h guards on those macros rather than on
//    __has_include of a header name this tree cannot measure:
//
//      grep -o '__IPHONE_1[0-9]_[0-9]' AvailabilityVersions.h | sort -u | tail -5
//
//    __IPHONE_16_0 __IPHONE_16_1 __IPHONE_16_2 __IPHONE_16_3 __IPHONE_16_4
//
// 6. WHAT IS NOT IN THIS TREE, and what closes the rows it holds.  The 26.2 sysroot is not in the store -
//    only iPhoneOS16.4.sdk is - so there is no declaration here to read the type of
//    `NSObject.accessibilityTextInputResponder`, of `NSObject.accessibilityTextInputResponderBlock`, of
//    `UITextView.writingToolsCoordinator`, of `UITextView.subclassForWritingToolsCoordinator` or of
//    `-[UIApplication defaultStatusForCategory:error:]` out of.  The four accessors the port DOES build are
//    therefore typed `id` and their rows say so: a selector's argument and return types are not part of
//    its name, so the exported symbol is the SDK's whichever type is spelled here.
//
//    `-[UIApplication defaultStatusForCategory:error:]` is the one name in this family the port does NOT
//    build, and the reason is the same one without the way out: its return type is not readable from any
//    declaration in this tree, and a category on UIApplication spelled from a remembered signature would
//    be a guess with a symbol on it.  What closes it is the 26.2 sysroot, or any declaration of it.
//
//    `UIWritingToolsCoordinatorDelegate` is the one PROTOCOL row, and it is not built for a different
//    reason: an `implemented` protocol row needs a header that declares it with a body (the gate writes
//    one source per release a library's protocol rows arrived in, naming the row, and a row no header
//    declares is a source that does not compile), and tools/transcribe-protocols.py@52253c0650 reads BOTH the 26.2
//    and the 16.4 sysroots.  With one of the two missing, transcribing is not possible here.  What closes
//    it is the 26.2 sysroot too.
//
// WHAT THE PORT CARRIES, release by release, and where each row lives:
//
//   18.1  UIKit18_1.m          NSObject.accessibilityTextInputResponder
//                               NSObject.accessibilityTextInputResponderBlock
//   18.2  UIKit18_2.m          UIWritingToolsCoordinator, UIWritingToolsCoordinatorContext,
//                               UIWritingToolsCoordinatorAnimationParameters,
//                               UITextView.writingToolsCoordinator,
//                               UITextView.subclassForWritingToolsCoordinator
//   18.4  UIKit18_4.m          UIConversationContext, UIConversationEntry,
//                               UIMailConversationContext, UIMailConversationEntry,
//                               UIMessageConversationContext, UIMessageConversationEntry,
//                               UIInputSuggestion, UISmartReplySuggestion,
//                               UITextInputTraits.conversationContext (as -[NSObject conversationContext])
//
// and the 26.0 and 26.4 protocol-member rows - twenty-nine at 26.0 and one at 26.4 - change no code at
// all: UIKit26_0.m already exports every one of those selectors, on NSObject, UIResponder or UIView, and
// each of those is a row of its own and `implemented`.  What changes is that the protocol-member row
// stops saying `owed`, which the queue's own rulebook calls out as not a landing state, and says
// `absent`, which is what the inventories above measure: no release has a class of that name for a
// member to live on.
