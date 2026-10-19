// UIDragItem+DropPreviewUpdate17.m - -setNeedsDropPreviewUpdate, the one UIDragItem method iOS 17.4
// added.
//
// Its own file, and NOT appended to UIDragItem.m: that file is 11.0 API (initWithItemProvider:,
// itemProvider, localObject, previewProvider, UIDragPreview, UIDragPreviewTarget,
// UITargetedDragPreview), and a .m holds ONE release's API. release-split.lua reads band points only,
// so folding a 17.4 method into an 11.0 file passes the tool and only a reader catches it.
//
// WHAT THE HOST ANSWERS (facts/UIKit/UIKit17Absence.md, M11), measured on a UIDragItem built with
// initWithItemProvider: and no drop animation anywhere:
//
//   - the selector exists and returns;
//   - with no drop animation in progress it does NOT raise, and calling it twice more still does not;
//   - a previewProvider set beforehand is STILL SET afterwards, so the call does not consume, clear or
//     run it.
//
// Its own header says the same thing in one sentence: a request to refresh the drop preview is honoured when
// a drop animation is running and the item can take updates. With no drop animation running for the item, nothing happens.
//
// WHICH IS EXACTLY WHAT HAPPENS HERE, and why that is not a stub. A drop animation is the SYSTEM's:
// this release has no drop animation a drag item can be inside, because a drag that leaves the
// application needs the system drag service, which is what UIDragItem.m's header says the release
// cannot do. So the condition the header names is never true on this release, and the honest
// implementation of "update the preview if an animation is in progress" is the no-op the header itself
// prescribes for that case.
//
// What this file therefore does NOT do is fabricate a drop animation to have something to update, and it
// does NOT call the previewProvider: the header says the provider is called when and if the system asks
// for it, and a measurement that called it here would be the port driving a system callback on its own
// initiative. The provider is left exactly where the caller put it - measured, still set.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonDropPreviewUpdateCountKey;

@implementation UIDragItem (CharonDropPreviewUpdate17)

- (void)setNeedsDropPreviewUpdate
{
    // Recorded, and READABLE, which is what makes it state rather than a write into nowhere: the count
    // is how a caller - or a later drop implementation that DOES have an animation - can tell that a
    // preview was asked to be refreshed, which is the one thing this method can honestly do on a release
    // with no drop animation. -charon_dropPreviewUpdateCount below is the reader; an earlier version
    // wrote the count with nothing reading it, which is a write into nowhere and not worth shipping.
    //
    // It is not a registry API and cannot be mistaken for one: the name is charon_-prefixed, and the row
    // this file carries is the 17.4 method.
    NSUInteger asked = [objc_getAssociatedObject(self, &CharonDropPreviewUpdateCountKey) unsignedIntegerValue];
    objc_setAssociatedObject(self, &CharonDropPreviewUpdateCountKey,
                            @(asked + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// How many times -setNeedsDropPreviewUpdate has been called on this item. Zero on a fresh item, which
// is the honest answer: no preview has been asked to be refreshed because there is no drop animation to
// refresh one in.
- (NSUInteger)charon_dropPreviewUpdateCount
{
    return [objc_getAssociatedObject(self, &CharonDropPreviewUpdateCountKey) unsignedIntegerValue];
}

@end