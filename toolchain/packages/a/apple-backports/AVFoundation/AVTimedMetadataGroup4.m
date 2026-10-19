#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

const void *CharonAVMetadataTimedItemsKey = &CharonAVMetadataTimedItemsKey;
const void *CharonAVMetadataTimedRangeKey = &CharonAVMetadataTimedRangeKey;

@implementation AVTimedMetadataGroup (CharonAVMetadataTimed4)

- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        objc_setAssociatedObject(self, CharonAVMetadataTimedItemsKey, items ? [items copy] : @[],
                                 OBJC_ASSOCIATION_COPY);
        objc_setAssociatedObject(self, CharonAVMetadataTimedRangeKey,
                                 [NSValue valueWithCMTimeRange:timeRange], OBJC_ASSOCIATION_RETAIN);
    }
    return self;
}

- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!sampleBuffer) {
        return [self charon_initWithItems:@[] timeRange:kCMTimeRangeInvalid];
    }
    return [self charon_initWithItems:@[]
                            timeRange:CMTimeRangeMake(CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                                                     kCMTimeInvalid)];
}

- (CMFormatDescriptionRef)copyFormatDescription
{
    return NULL;
}

@end
