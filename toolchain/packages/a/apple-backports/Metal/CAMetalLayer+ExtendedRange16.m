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

- (void)setEDRMetadata:(CAEDRMetadata *)metadata
{
    objc_setAssociatedObject(self, charon_edr_metadata_key, metadata, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)developerHUDProperties
{
    return objc_getAssociatedObject(self, charon_developer_hud_key);
}

- (void)setDeveloperHUDProperties:(NSDictionary *)properties
{
    objc_setAssociatedObject(self, charon_developer_hud_key, [properties copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
