// CAMetalLayer+ExtendedRange16.m - the three layer properties of iOS 16.0.
//
// They are carried in a category, beside the layer itself in CAMetalLayer8.m and not in it: one file
// carries one release, and 16.0 is not the release the class arrived in. The name of each keeps the
// @dynamic in CAMetalLayer8.m:8, and that is what it means there - not that nothing answers the
// selector, but that this file must not synthesise an accessor of its own for a property another
// file answers. Dropping the three names from that line makes clang synthesise a second pair of
// accessors on the class itself, which the runtime would then find before the category's.
//
// The value behind each is the caller's, kept the way the neighbouring 11.0 and 11.2 properties are
// kept (CAMetalLayer+Timeout11.m, CAMetalLayer+MaximumDrawableCount112.m): an associated object, so
// that the layer's own ivar layout, which a release lays out itself in a band where it has the class,
// is not disturbed.
//
// What the layer does with the values is nothing, and that is what the layer can do on this release:
// an extended-range layer needs a display with an extended range and a CAEDRMetadata to describe the
// content in HDR, and CAEDRMetadata is absent from the armv7 shared cache of iOS 4.3 (0 entries of its
// 7187 class names), so a caller has no metadata object to put in the second of the three.

#import <QuartzCore/CAMetalLayer.h>
#import <QuartzCore/CAEDRMetadata.h>
#import <objc/runtime.h>

static const void *charon_extended_range_key = &charon_extended_range_key;
static const void *charon_edr_metadata_key = &charon_edr_metadata_key;
static const void *charon_developer_hud_key = &charon_developer_hud_key;

@implementation CAMetalLayer (CharonExtendedRange16)

- (BOOL)wantsExtendedDynamicRangeContent
{
    NSNumber *value = objc_getAssociatedObject(self, charon_extended_range_key);
    return value ? value.boolValue : NO;
}

- (void)setWantsExtendedDynamicRangeContent:(BOOL)wants
{
    objc_setAssociatedObject(self, charon_extended_range_key, @(wants), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CAEDRMetadata *)EDRMetadata
{
    return objc_getAssociatedObject(self, charon_edr_metadata_key);
}

// The header declares the property `strong`, so the object is held by the association and released
// with the layer; nil is kept as nil, which is what a nullable strong property means.
- (void)setEDRMetadata:(CAEDRMetadata *)metadata
{
    objc_setAssociatedObject(self, charon_edr_metadata_key, metadata, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)developerHUDProperties
{
    return objc_getAssociatedObject(self, charon_developer_hud_key);
}

// `copy`, per CAMetalLayer.h:141, so the dictionary the caller keeps changing does not change the
// layer's.
- (void)setDeveloperHUDProperties:(NSDictionary *)properties
{
    objc_setAssociatedObject(self, charon_developer_hud_key, [properties copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end