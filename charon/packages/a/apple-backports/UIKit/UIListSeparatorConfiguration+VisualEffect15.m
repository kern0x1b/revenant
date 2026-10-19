// UIListSeparatorConfiguration+VisualEffect15.m - the visual effect of iOS 15.0 on a
// UIListSeparatorConfiguration: the accessor pair and the storage, plus the three seams the 14.5 object
// reaches them through for its copy and its archive.
//
// WHAT THE HOST ANSWERS, measured first, and every clause below is a line of
// facts/UIKit/UIListSeparatorConfiguration145.md M4 (the probe in .agent-work/runs/fix/effect-probe.m,
// run against the host's own UIKitCore under Mac Catalyst):
//
//   default                     (nil)
//   after -setVisualEffect:     a UIBlurEffect, and NOT the instance that was set - the header's `copy`
//                               is applied on the way in, and the host applies it
//   -copyWithZone:              carries it; the copy's effect is not the receiver's instance either, and
//                               the copy is not its receiver
//   copy of a fresh one         (nil)
//   -isEqual: two alike, both effectless      1
//   -isEqual: the same two, one with an effect 0
//   -hash: either way                        EQUAL - the hash does not take the effect into account
//   the archive                 writes SEVEN keys and the seventh is `visualEffect`, the property's own
//                               name, and reads back a UIBlurEffect
//
// WHY THE ROW IS `implemented` AND NOT `absent`, and it is not the header that says so: the arm64e cache of
// iOS 18.0 carries `-visualEffect` and `-setVisualEffect:` in UIListSeparatorConfiguration's OWN instance
// list, among its 37, and the host's own class answers both. The 16.4 build SDK declares the property on
// this class, so the 14.5 object was auto-synthesising the pair into itself - nm on that object showed
// -visualEffect, -setVisualEffect: and _OBJC_IVAR_$_UIListSeparatorConfiguration._visualEffect, in a file
// whose every other member is 14.5. This object is where that pair belongs, and the 14.5 object declares
// the property @dynamic so that nothing is synthesised there.
//
// One release per object: visualEffect is 15.0, and the file that DEFINES the class is 14.5, so this is its
// own file rather than two lines in that one.
//
// A category and not a subclass, which is the shape this tree's UIImageConfiguration+Locale17.m uses: the
// ACCESSORS are the row's subject and belong to this class, and a category is the only shape that adds a
// member to a class the port implements wholesale. A category cannot add an ivar, so the storage is one
// associated object per configuration, keyed by a file-static address.
//
// The three seams, and why there is no other shape: a category's `[super copyWithZone:]` resolves against
// NSObject rather than against the class it is a category of - measured, not assumed, in
// UIImageConfiguration+Locale17.m's comment - so a 15.0 category could not EXTEND the 14.5 object's own
// copy or archive. It could only replace them, and a replacement copy would lose the six fields. The
// direction that works is the one used here and by the locale object beside it: the older object calls, the
// newer one implements, through declarations both can see in CharonLists.h.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonLists.h"

static const char CharonSeparatorVisualEffectKey;

static UIVisualEffect *charon_separator_visual_effect(UIListSeparatorConfiguration *configuration)
{
    return objc_getAssociatedObject(configuration, &CharonSeparatorVisualEffectKey);
}

@implementation UIListSeparatorConfiguration (CharonVisualEffect15)

// NOT [effect copy] on the way in and the stored object returned as is: the host's getter answers a
// different instance from the one that was set, so the copy is made here and what is stored IS the copy.
// A UIVisualEffect a caller goes on configuring therefore cannot change what the configuration answers.
- (UIVisualEffect *)visualEffect
{
    return charon_separator_visual_effect(self);
}

- (void)setVisualEffect:(UIVisualEffect *)visualEffect
{
    objc_setAssociatedObject(self, &CharonSeparatorVisualEffectKey, [visualEffect copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// The host's own -copyWithZone: carries the effect and the copy's effect is not the receiver's instance,
// which is this same setter's doing: the base object builds the copy through the designated initialiser and
// then calls in here, and the copy of the copy is made once more.
- (void)charon_takeVisualEffectFrom:(UIListSeparatorConfiguration *)other
{
    [self setVisualEffect:charon_separator_visual_effect(other)];
}

// The equality the 14.5 object answers includes the effect: measured, a pair differing only in the effect
// is NOT equal (isEqual 0), and two effects that are equal by value and not the same object ARE equal
// (measured, isEqual 1) - so the comparison is by -isEqual: and not by identity, the same rule the colours
// follow.
- (BOOL)charon_visualEffectIsEqualTo:(UIListSeparatorConfiguration *)other
{
    UIVisualEffect *mine = charon_separator_visual_effect(self);
    UIVisualEffect *theirs = charon_separator_visual_effect(other);
    if (mine == theirs)
        return YES;
    if (!mine || !theirs)
        return NO;
    return [mine isEqual:theirs];
}

// The host's key is the property's own name, read out of the host's plist. The class of the value is
// declared for the unarchiver rather than left to the archiver: +supportsSecureCoding is YES on the host
// and this object answers YES, so the decode has to name a class the value can be.
- (void)charon_encodeVisualEffectWithCoder:(NSCoder *)coder
{
    [coder encodeObject:charon_separator_visual_effect(self) forKey:@"visualEffect"];
}

- (void)charon_decodeVisualEffectWithCoder:(NSCoder *)coder
{
    UIVisualEffect *effect = [coder decodeObjectOfClass:[UIVisualEffect class] forKey:@"visualEffect"];
    if (effect)
        [self setVisualEffect:effect];
}

@end