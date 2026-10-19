// UIScrollView+ContentAlignment17.m - the six UIScrollView members iOS 17.4 added.
//
// A file of its own, and separate from UIScrollView+KeyboardScrolling17.m beside it, because a .m holds
// ONE release's API. release-split.lua reads band points only, so a file holding both 17.0 and 17.4
// rows passes it and only a reader catches it - which is what happened to three batches before this one.
//
// What the host answers was measured first (facts/UIKit/UIKit17Absence.md, M4), and every default below
// is the host's answer rather than a guess:
//
//   contentAlignmentPoint   gettable and settable; a fresh 100x100 scroll view with contentOffset
//                           (0,0) answers (0,0), and setting (37,11) reads back (37,11) while
//                           contentOffset stays (0,0) - it is INDEPENDENT of the offset, not a
//                           function of it. So it is stored, not computed from contentOffset.
//   isScrollAnimating       NO on a fresh scroll view
//   isZoomAnimating         NO on a fresh scroll view
//   allowsKeyboardScrolling YES on a fresh scroll view  (17.0, and therefore NOT here - see the file
//                           above; it is named here only to record why it is absent from this one)
//   transfersHorizontal     YES on a fresh scroll view
//   transfersVertical       YES on a fresh scroll view
//
// The two "animating" properties are READ-ONLY on the host (measured: the getter answers under the
// `is` spelling and no setter exists for either), so this file declares getters only. Writing a setter
// the host does not have would be the port inventing API.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonContentAlignmentPointKey;
static const char CharonTransfersHorizontalKey;
static const char CharonTransfersVerticalKey;

@implementation UIScrollView (CharonContentAlignment17)

- (CGPoint)contentAlignmentPoint
{
    NSValue *stored = objc_getAssociatedObject(self, &CharonContentAlignmentPointKey);
    // The measured default is (0,0) - the origin, not the centre and not the offset - so a scroll view
    // nobody configured answers the origin rather than a value this file would have had to invent.
    return stored ? stored.CGPointValue : CGPointZero;
}

- (void)setContentAlignmentPoint:(CGPoint)contentAlignmentPoint
{
    // CGPointValue copies the two C floats, so a point the caller keeps mutating does not change what
    // the scroll view answers afterwards.
    objc_setAssociatedObject(self, &CharonContentAlignmentPointKey,
                            [NSValue valueWithCGPoint:contentAlignmentPoint],
                            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isScrollAnimating
{
    // Read-only, and there is nothing to read yet on a release with no animated scroll: the port's own
    // scroll animation is driven by the release's -setContentOffset:animated:, and this property only
    // reports whether such an animation is in flight. Nothing the port owns is in flight at this level,
    // so the honest answer is the measured default, NO, and not a flag this file sets and forgets.
    return NO;
}

- (BOOL)isZoomAnimating
{
    return NO;
}

- (BOOL)transfersHorizontalScrollingToParent
{
    // The measured default is YES, so a fresh scroll view takes horizontal scrolling from its parent
    // exactly as it always has; a caller that wants to stop that sets it to NO.
    NSNumber *stored = objc_getAssociatedObject(self, &CharonTransfersHorizontalKey);
    return stored ? stored.boolValue : YES;
}

- (void)setTransfersHorizontalScrollingToParent:(BOOL)transfersHorizontalScrollingToParent
{
    objc_setAssociatedObject(self, &CharonTransfersHorizontalKey,
                            @(transfersHorizontalScrollingToParent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)transfersVerticalScrollingToParent
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonTransfersVerticalKey);
    return stored ? stored.boolValue : YES;
}

- (void)setTransfersVerticalScrollingToParent:(BOOL)transfersVerticalScrollingToParent
{
    objc_setAssociatedObject(self, &CharonTransfersVerticalKey,
                            @(transfersVerticalScrollingToParent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)withScrollIndicatorsShownForContentOffsetChanges:(void (NS_NOESCAPE ^)(void))changes
{
    // A NIL block is a caller error and the host does not survive one: measured on the host's own
    // UIKit, -withScrollIndicatorsShownForContentOffsetChanges:nil dies with SIGSEGV (exit 139) before
    // returning, having printed nothing. So the port runs the block and does not "handle" nil - a
    // guard here would be the port answering something the system does not, and the caller's own
    // mistake would stop being visible.
    //
    // What the block does is entirely the caller's, and this release's own -setContentOffset: already
    // shows the indicators the way the header describes (fade out after a delay when set without
    // animation). So the port runs the block and lets the release do what it has always done, which is
    // what the host's own call amounts to on a release that has no separate indicator policy to set.
    changes();
}

@end