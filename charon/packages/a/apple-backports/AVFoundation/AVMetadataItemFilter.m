#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

@interface AVMetadataItemFilter ()
- (void)charon_setIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers;
- (NSArray<AVMetadataIdentifier> *)charon_storedIdentifiers;
@end

@implementation AVMetadataItemFilter

+ (instancetype)metadataItemFilterForSharing
{
    return [[self alloc] charon_initWithIdentifiers:@[]];
}

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
