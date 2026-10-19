#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVMetadataConstruction.h"

@interface AVMetadataItemFilter ()
- (void)revenant_setIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers;
- (NSArray<AVMetadataIdentifier> *)revenant_storedIdentifiers;
@end

@implementation AVMetadataItemFilter

+ (instancetype)metadataItemFilterForSharing
{
    return [[self alloc] revenant_initWithIdentifiers:@[]];
}

- (NSArray<AVMetadataIdentifier> *)allowList
{
    NSArray<AVMetadataIdentifier> *stored = objc_getAssociatedObject(self, @"revenant.avf.metadatafilter.list");
    return stored ?: @[];
}

- (void)revenant_setIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
{
    objc_setAssociatedObject(self, @"revenant.avf.metadatafilter.list",
                             identifiers ? [identifiers copy] : @[],
                             OBJC_ASSOCIATION_COPY);
}

- (NSArray<AVMetadataIdentifier> *)revenant_storedIdentifiers
{
    NSArray<AVMetadataIdentifier> *stored = objc_getAssociatedObject(self, @"revenant.avf.metadatafilter.list");
    return stored ?: @[];
}

@end
