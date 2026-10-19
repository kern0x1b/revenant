// UIKit18_2.m - the 18.2 band: three Writing Tools classes, and two properties UITextView carries from
// this release on.
//
// ONE OBJECT, ONE RELEASE: 18.2, on its own.  Its sibling UIWritingToolsCoordinatorTextAnimation18.m is
// 18.2 too and carries one C function; this file carries the three class symbols of the same release and
// nothing from any other, because tools/release-split.lua walks the held ladder symbol by symbol and
// refuses a file that mixes releases.  A reader is the only thing that would notice a 26.0 class in this
// file, because that check reads band points only for a category method.
//
// --- (a) THE THREE CLASSES --------------------------------------------------------------------
//
// UIWritingToolsCoordinator, UIWritingToolsCoordinatorContext and
// UIWritingToolsCoordinatorAnimationParameters are declared in CharonUIKit18.h and implemented empty.
// Why an empty class is the whole answer is that header's note, and the short form is: a class is a
// DYLD SYMBOL, an application that links strongly against it names _OBJC_CLASS_$_X and dyld has to
// find it, and what a 6.1.3 text input could do with a Writing Tools coordinator is nothing - the
// feature needs a system service that release does not have.  Invented members would answer for
// behaviour nobody measured; the registry row for each says this in its own words.
//
// --- (b) THE TWO PROPERTIES UITEXTVIEW CARRIES ---------------------------------------------------
//
// UITextView exists in every release this port targets, so these are CATEGORIES, and a CATEGORY CANNOT
// HAVE IVARS - the compiler says "expected identifier or '('" at the opening brace - so the storage is
// an associated object.  Each getter returns nil when nothing was ever stored.
//
// The two properties are the shape Writing Tools has on a text view: the coordinator it talks to, and
// the coordinator SUBCLASS the text view would use.  The port answers both by holding what a caller
// stores and displaying nothing, because a 6.1.3 text view draws no writing-tools UI, has no
// TextInputUI service to ask and no revision-tracking model to rewrite a range in.  A caller that
// stores a coordinator and reads it back gets the same object; a caller that never stores one reads nil,
// which is what a text view with no Writing Tools coordinator should answer.
//
// WHY THE PORT'S DECLARATION SAYS `id`.  No header in this tree names either property's type: the 26.2
// sysroot is not in the store (only iPhoneOS16.4.sdk is, under
// ~/.xmake/packages/i/iphoneos-sdk/16.4/) and the 16.4 SDK declares neither, so there is no declaration
// to read a type out of, and `subclassForWritingToolsCoordinator` in particular is a name whose value is
// a Class that no declaration here will confirm.  A selector's RETURN TYPE DOES NOT ENTER THE SELECTOR,
// so the exported name is the SDK's whichever type is spelled here.  Storing and handing back an `id` is
// what makes the accessor right for either type: the port never calls the value, so it cannot get it
// wrong.

#import "CharonUIKit18.h"
#import <objc/runtime.h>

// =====================================================================================
// (a) THE THREE CLASSES.  No members: see the note above.
// =====================================================================================

@implementation UIWritingToolsCoordinator
@end

@implementation UIWritingToolsCoordinatorContext
@end

@implementation UIWritingToolsCoordinatorAnimationParameters
@end

// =====================================================================================
// (b) THE PROPERTIES ON A CLASS THE RELEASE ALREADY HAS.
// =====================================================================================

@implementation UITextView (CharonUIKit18_WritingTools)

static char CharonTextViewWritingToolsCoordinatorKey;
static char CharonTextViewWritingToolsCoordinatorSubclassKey;

- (id)writingToolsCoordinator
{
    return objc_getAssociatedObject(self, &CharonTextViewWritingToolsCoordinatorKey);
}
- (void)setWritingToolsCoordinator:(id)coordinator
{
    objc_setAssociatedObject(self, &CharonTextViewWritingToolsCoordinatorKey, coordinator,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (id)subclassForWritingToolsCoordinator
{
    return objc_getAssociatedObject(self, &CharonTextViewWritingToolsCoordinatorSubclassKey);
}
- (void)setSubclassForWritingToolsCoordinator:(id)subclass
{
    objc_setAssociatedObject(self, &CharonTextViewWritingToolsCoordinatorSubclassKey, subclass,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
