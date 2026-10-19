// UIKit18_1.m - the 18.1 band: two accessors on NSObject.
//
// ONE OBJECT, ONE RELEASE: 18.1, on its own.  A reader is the only thing that would notice this in
// UIKit26_0.m or UIKit26_1.m, because tools/release-split.lua reads band points only and every symbol in
// this file is a CATEGORY METHOD - a category exports no symbol of its own, so the release-split check
// has nothing to walk here.  That blind spot is the tool's own, named in its header; what the registry
// check counts is the selectors a category adds, and it counts these two.
//
// WHAT THESE TWO ARE.  accessibilityTextInputResponder and accessibilityTextInputResponderBlock are the
// 18.1 spelling of the input responder an assistive technology talks to: the first names the object,
// the second names a block that produces it.  Neither is declared by any header this package compiles
// against, so both selectors are defined here.
//
// A CATEGORY HAS NO IVARS - the compiler says "expected identifier or '('" at the opening brace - so the
// storage is an associated object, which is what CADisplayLink+FrameRate.m and CAFrameRate.m already do
// for a property this port adds to a class the release owns.  Each getter returns nil when nothing was
// ever stored, which is what an unboxed ivar would have returned too.
//
// WHY THE PORT'S DECLARATION SAYS `id` AND NOT THE PROPERTY'S OWN TYPE.  No header in this tree names
// the type: the 26.2 sysroot is not in the store (only iPhoneOS16.4.sdk is, under
// ~/.xmake/packages/i/iphoneos-sdk/16.4/) and the 16.4 SDK does not declare either name, so there is no
// declaration here to read a type out of.  A selector's ARGUMENT AND RETURN TYPES DO NOT ENTER THE
// SELECTOR, so the exported name is the SDK's whichever type is spelled here; only this file's own
// compilation sees the difference, and the registry row says so instead of inventing a type nobody
// measured.  Storing and handing back an `id` is also what makes the accessor's behaviour right for
// either: the port does not interpret the value, so a caller that stores an object of any class reads
// back the same object.
//
// THE BLOCK IS COPIED AND THE OBJECT IS NOT, AND THE DIFFERENCE IS WHY.  A block that outlives the frame
// it was made in has to be copied onto the heap or it is freed under the port's own feet, so the setter
// sends -copy: to what it is given; a block answers -copy: by copying itself to the heap.  An ordinary
// object is held with a retaining association instead: sending -copy: to it would demand NSCopying,
// which this port cannot promise for a value it does not own and never inspects.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation NSObject (CharonUIKit18_AccessibilityTextInputResponder)

static char CharonAccessibilityTextInputResponderKey;

- (id)accessibilityTextInputResponder
{
    return objc_getAssociatedObject(self, &CharonAccessibilityTextInputResponderKey);
}
- (void)setAccessibilityTextInputResponder:(id)responder
{
    objc_setAssociatedObject(self, &CharonAccessibilityTextInputResponderKey, responder,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char CharonAccessibilityTextInputResponderBlockKey;

- (id)accessibilityTextInputResponderBlock
{
    return objc_getAssociatedObject(self, &CharonAccessibilityTextInputResponderBlockKey);
}
- (void)setAccessibilityTextInputResponderBlock:(id)block
{
    // -copy: and not a retaining association: see the note above.  A nil block clears the association,
    // which is what a retaining association does with nil as well and what the getter then reports.
    objc_setAssociatedObject(self, &CharonAccessibilityTextInputResponderBlockKey, [block copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
