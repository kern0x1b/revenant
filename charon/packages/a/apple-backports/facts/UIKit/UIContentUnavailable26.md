// Facts: UIKit's 26.x band, 125 rows, and what the port's answer for each name is
//
// WHY THIS FAMILY IS DIFFERENT from every other UIKit family in the tree.  Most of these 125 names are
// names an APPLICATION LINKS STRONGLY: a symbol its binary names, which dyld must resolve before main
// runs.  That is not behaviour the port can reproduce and not behaviour it should try to - a 6.1.3
// release has no liquid glass, no menu system, no tab accessory and no scroll-edge effects, and inventing
// them would be answering for measurements nobody took.
//
// So the port's stance, which every row below states, is two halves:
//
//   THE NAME EXISTS AND IS EXPORTED.  For the twenty-two classes that is the whole of it: a class is a
//   dyld symbol, and an application that does not find one does not launch.  The classes are declared with
//   no members, because a name whose requirement is that dyld resolve it has no other honest answer, and
//   invented members would answer for behaviour nobody measured.
//
//   THE PORT'S ANSWER FOR THE SAME INPUT IS WHATEVER THE RELEASE CAN HONESTLY DO.  For a member of a class
//   the release already has, that is usually storage - the getter returns what the setter stored - and
//   where the 26.0 member is the release's own member PLUS an argument the release has no field for, the
//   port DROPS that argument and the row says it was dropped rather than approximated.  A colour with the
//   wrong exposure is a DIFFERENT colour, so saying so beats guessing one.
//
// WHAT WAS MEASURED, and by what:
//
//   The build SDK is 16.4, and none of the twenty-two classes appears in any header under its
//   UIKit.framework/Headers - so the port is the only thing here that can make those names exist.  Every
//   class is therefore declared in CharonUIKit26.h, guarded on __has_include so a future SDK's own
//   declaration wins.
//
//   The build SDK 16.4 is also missing the two 26.0 enums UIImageSymbolConfigurationColorRenderingMode and
//   UIImageSymbolConfigurationVariableValueMode, so those two selectors take `id`.  A selector's argument
//   types are not part of its name, so the exported symbol is unchanged.
//
//   Each band object compiles, and what it EXPORTS is read out of the object rather than out of the
//   source - the same count the registry check makes:
//
//     clang -c -fobjc-arc -target armv7-apple-ios6.1.3 -isysroot <16.4 SDK> -Wall \
//         packages/a/apple-backports/UIKit/UIKit26_0.m -o UIKit26_0.o
//     otool -v -s __TEXT __objc_classname UIKit26_0.o     # the class names the object carries
//     otool -v -s __TEXT __objc_methname  UIKit26_0.o     # the selectors the object carries
//
//     UIKit26_0.o  69456 bytes  34 class names  162 selectors
//     UIKit26_1.o    3408 bytes   2 class names    5 selectors
//     UIKit26_4.o    2712 bytes   1 class name     4 selectors
//     UIKit27_0.o    2352 bytes   1 class name     4 selectors
//
//   ALL 125 ROWS are exported by the object their band compiles to, checked one selector at a time
//   against __objc_methname and one class at a time against __objc_classname.  Two spellings of the check
//   were needed and the difference is worth recording: __objc_methname prints a no-argument selector
//   WITHOUT its trailing colon, so `-[UIColor colorByApplyingContentHeadroom:]` is in the object as
//   `colorByApplyingContentHeadroom`.  Comparing the first keyword of a multi-word selector finds
//   nothing, and comparing the queue's spelling exactly finds eight that are all there.  A check that
//   reports 117 of 125 exported was wrong about the check, not about the code.
//
// THE FOUR OBJECTS, one release each, because release-split reads band points only and a reader is the
// only thing that would notice a 26.1 method in the 26.0 file:
//
//   CharonUIKit26.h  the twenty-two class declarations, shared - a header is not an object and holds no API
//   UIKit26_0.m      121 rows, 26.0
//   UIKit26_1.m        2 rows, 26.1
//   UIKit26_4.m        1 row,  26.4
//   UIKit27_0.m        1 row,  27.0
//
// FOUR THINGS THE COMPILER SAID IN AS MANY WORDS, all four caught here rather than by reading:
//
//   A CATEGORY CANNOT HAVE IVARS.  "expected identifier or '('" at the opening brace.  The port may not
//   subclass UIKit's own classes away, so the storage for every member added to a class the release owns
//   is an ASSOCIATED OBJECT - which is what CADisplayLink+FrameRate.m and CAFrameRate.m already do for
//   a property this port adds to a class the release owns.
//
//   A CATEGORY CANNOT BE ON A PROTOCOL.  UITextInputTraits, UIMenuBuilder, UIResponderStandardEditActions,
//   UISearchBarDelegate, UISplitViewControllerDelegate, UITextFieldDelegate, UITextViewDelegate and
//   UIWindowSceneDelegate are all @protocol, and "@implementation UITextInputTraits (X)" is "cannot find
//   interface declaration".  They are categories on NSObject, which every conforming object inherits, and
//   the COST of that is stated rather than hidden: an unrelated object also answers YES to -alignLeft:.
//
//   UIDeferredMenuElement's -init is UNAVAILABLE in this SDK, because a deferred element only means
//   anything with a provider.  The 26.0 factory builds through +elementWithProvider: instead, handing it
//   a block that completes with nothing.
//
//   UITextInput is a PROTOCOL, so it cannot be a method's return type here; the two edit-menu selectors
//   return id.
//
// THE TWO ROWS THAT ARE OWED rather than carried, and the reason is arithmetic rather than difficulty:
//
//   UIBarAppearance.overrideUserInterfaceStyle  27.0
//   UITextInput.unobscuredContentRect           26.4
//
// The queue names both and the SDK 26.2 SURFACE declares NEITHER.  A 26.4 or a 27.0 name cannot appear in
// a 26.2 surface by construction - the surface predates them - so there is no declaration anywhere in the
// tree to read the signature from.  Carrying a property on a remembered signature would be a guess with a
// symbol on it, which is the defect this family's rules name.  Both are in coordination/api-queue.md and
// what they need is a NEWER SURFACE, not a different implementation.
## `NSTextList.includesTextListMarkers` is a CLASS property, and the port had it as an instance one

`NSTextList.h:65` of the 26.2 SDK declares

    @property (readonly, class) BOOL includesTextListMarkers API_AVAILABLE(macos(26.0), ios(26.0), ...);

with the comment "When YES, TextKit includes text list marker in the contents.  It is NO by default."

The port answered it with an **instance** getter over a per-list associated flag and an **instance** setter, so
`-[NSTextList includesTextListMarkers]` and `-[NSTextList setIncludesTextListMarkers:]` existed and
`+[NSTextList includesTextListMarkers]` did not.  Two measurements say the shape was wrong and which shape is
right.

**Apple's own class.**  The arm64e shared cache of iOS 18.0, read with `modules/apple/objc.lua`'s inventory:
`includesTextListMarkers` is in `NSTextList`'s **metaclass** list, and in neither of its instance lists.  The
metaclass list holds four names in all: `_standardMarkerAttributesForAttributes:`, `includesTextListMarkers`,
`initialize` and `supportsSecureCoding`.  (The reader stores every method name with a `-` prefix whichever list
it came from, so which list a name is in is the only thing that says instance from class - see the correction
recorded in `UIContentUnavailable17.md`.)

**The host's own class.**  One probe, run twice in the same build, the only difference being whether the port's
object is linked:

    with the port's object NOT linked:   +includesTextListMarkers -> NO
                                         -includesTextListMarkers        absent
                                         -setIncludesTextListMarkers:    absent
    with the port's object linked:       +includesTextListMarkers -> NO
                                         -includesTextListMarkers        absent
                                         -setIncludesTextListMarkers:    absent

Before the change the second run read `-includesTextListMarkers` present and `-setIncludesTextListMarkers:`
present: the two selectors the port used to add, and the two no Apple release has.  After it, the port's
contribution to the class's selector set is empty on the host and the object carries one name of this property.

**The answer on this release is NO**, and the header's own sentence is why: a list is nothing but its markers,
and this port produces no marker at all - `NSTextListMarker` is not a class the port carries, only its seventeen
enumerated constants are (`registry/UIKit/measured-constants.json`).  A flag stored per list would have answered
YES to a question about text this release never generates, which is the same fiction
`registry/UIKit/ios15content.json`'s `NSTextContentStorage.includesTextListMarkers` row already refuses.
