#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

// AVMetadataItemFilter — the CLASS, in an object of its own, defined under Apple's own name.
//
// **Why the class is defined here at all, when 7.0 and every release above it already has it.**
// Measured over the held caches, searching this class's own symbols — `_OBJC_CLASS_$_AVMetadataItemFilter`
// and its metaclass — in the exports of all fifteen held rungs (4.3, 6.1.3, 7.0, 7.1, 7.1.1, 7.1.2 and
// 8.0 armv7; 8.1.3, 8.2 and 8.4.1 armv7s; 9.3.6 armv7; 10.0.1, 11.0 and 12.0 arm64; 16.0 arm64e),
// the FIRST held rung that exports it is **7.0**, with `_NSFileSize` planted as a control. So 4.3 and
// 6.1.3 — the releases the port's floor is — have no such class, and a category alone is not enough
// there: a category compiles to no `_OBJC_CLASS_$_` symbol at all, `nm -gU` finds nothing of the name,
// `check_registry` counts the row's `built` false, and the 6.1.3 band build stops with "the registry
// does not describe what the backports carry: listed as implemented, but nothing of that name is
// built". That is not a wording problem and this object is the fix.
//
// **And why the 7.0 members are NOT in this object.** They are in AVMetadataItemFilter7.m, a category.
// A category is invisible to `nm`, so it is never dropped by a band's staging while a defined class is
// dropped from 7.0 up, where the release's own class answers. Had the members ridden here, the class
// symbol would be dropped on every 7.0+ band and the port's members with it. Split this way, a 7.0+ band
// uses the release's class and still gets the port's members, and a 6.1.3 band uses this class and
// still gets them.
//
// The list is attached rather than ivar'd, and keyed on a string rather than on a symbol defined in
// this file: a symbol would leave the category with an undefined reference on a 7.0+ band, where this
// object is dropped, and two string literals with the same content are the same NSString at runtime.

// The two charon_ initializers are declared in CharonAVMetadataConstruction.h, which is imported
// below; redeclaring the category here warned "duplicate definition of category" and was removed.
@interface AVMetadataItemFilter ()
- (void)charon_setIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers;
- (NSArray<AVMetadataIdentifier> *)charon_storedIdentifiers;
@end

@implementation AVMetadataItemFilter

// The header's own member, and not a 7.0 one, so it belongs in this object rather than in the
// category: a filter that keeps everything, which is the empty allow list. The first version put it in
// the class EXTENSION, which is a declaration and not a definition, and the build said so.
+ (instancetype)metadataItemFilterForSharing
{
    return [[self alloc] charon_initWithIdentifiers:@[]];
}

// The current spelling of the member. The 26.2 headers call it -allowList and the 7.0-era name is
// -identifiers, which is in the category; both read this one list, so the two spellings cannot disagree.
- (NSArray<AVMetadataIdentifier> *)allowList
{
    NSArray<AVMetadataIdentifier> *stored = objc_getAssociatedObject(self, @"charon.avf.metadatafilter.list");
    return stored ?: @[];
}

- (void)charon_setIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
{
    objc_setAssociatedObject(self, @"charon.avf.metadatafilter.list",
                             identifiers ? [identifiers copy] : @[],
                             OBJC_ASSOCIATION_COPY);
}

- (NSArray<AVMetadataIdentifier> *)charon_storedIdentifiers
{
    NSArray<AVMetadataIdentifier> *stored = objc_getAssociatedObject(self, @"charon.avf.metadatafilter.list");
    return stored ?: @[];
}

@end
