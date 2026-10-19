// UIKit26_1.m - the 26.1 band's two members.
//
// ONE OBJECT, ONE RELEASE: 26.1, on its own.  tools/release-split.lua reads band points only, so putting
// either of these in UIKit26_0.m would pass every mechanical check and be wrong.  Only a reader sees it.

#import "CharonUIKit26.h"
#import <objc/runtime.h>

// UIPresentationController.backgroundEffect: storage.  The release's presentation controller has no
// background at all - the 6.1.3 sheet is a plain view - so the port holds what it was given and the row
// says the release draws nothing with it.
@implementation UIPresentationController (CharonUIKit26_1)

static char CharonPresentationBackgroundEffectKey;

- (id)backgroundEffect { return objc_getAssociatedObject(self, &CharonPresentationBackgroundEffectKey); }
- (void)setBackgroundEffect:(id)effect
{
    objc_setAssociatedObject(self, &CharonPresentationBackgroundEffectKey, effect,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

// +[UIColorEffect ...]: the 26.1 constructor on a CLASS the 16.4 SDK DOES NOT DECLARE, so unlike the
// twenty-one in UIKit26_0.m it needs a declaration too, and a category on a class that does not exist is
// "cannot find interface declaration".  So the class is declared here - empty, for the reason the header
// gives - and the category sits on it.
//
// The body builds the release's own UIVisualEffect, which is the closest thing the release has: a
// UIColorEffect is a visual effect described by a colour, and a release with no colour in the description
// can still produce the effect's geometry.  The row says that is what comes back.
@interface UIColorEffect : UIVisualEffect
@end

@implementation UIColorEffect
@end

@implementation UIColorEffect (CharonUIKit26_1)
+ (UIColorEffect *)effectWithColor:(id)color
{
    // The 26.1 constructor is the one named by the queue, effectWithColor:.  The release's UIVisualEffect
    // has no colour to be given, so what comes back is the release's own effect and the row says the
    // colour is not carried rather than claiming a tinted effect nobody measured.
    // The return type is id, NOT UIVisualEffect*.  A method that overrides this one is declared to return
    // UIColorEffect*, and handing back a UIVisualEffect* from it is a lie the compiler catches:
    // "incompatible pointer types returning 'UIVisualEffect *' from a function with result type
    // 'UIColorEffect *'".  Returning id says exactly what is true - an effect, whose class the release
    // does not let this constructor choose - and it keeps the row's claim honest: what comes back is the
    // release's own visual effect, not a colour effect nobody measured.
    return (UIColorEffect *)[[UIVisualEffect alloc] init];
}
@end
