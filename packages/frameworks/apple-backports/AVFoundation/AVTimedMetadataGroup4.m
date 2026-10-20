#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVMetadataConstruction.h"

const void *RevenantAVMetadataTimedItemsKey = &RevenantAVMetadataTimedItemsKey;
const void *RevenantAVMetadataTimedRangeKey = &RevenantAVMetadataTimedRangeKey;

@implementation AVTimedMetadataGroup (RevenantAVMetadataTimed4)

- (instancetype)revenant_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        objc_setAssociatedObject(self, RevenantAVMetadataTimedItemsKey, items ? [items copy] : @[],
                                 OBJC_ASSOCIATION_COPY);
        objc_setAssociatedObject(self, RevenantAVMetadataTimedRangeKey,
                                 [NSValue valueWithCMTimeRange:timeRange], OBJC_ASSOCIATION_RETAIN);
    }
    return self;
}

- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!sampleBuffer) {
        return [self revenant_initWithItems:@[] timeRange:kCMTimeRangeInvalid];
    }
    return [self revenant_initWithItems:@[]
                            timeRange:CMTimeRangeMake(CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                                                     kCMTimeInvalid)];
}

- (CMFormatDescriptionRef)copyFormatDescription
{
    return NULL;
}

@end
