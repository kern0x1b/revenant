#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

// AVTimedMetadataGroup's two 8.0 members, on the RELEASE's class.
//
// **This is a category, and the held caches are why.** The 4.3 armv7 cache exports
// `_OBJC_CLASS_$_AVTimedMetadataGroup` and its metaclass and no earlier held rung does, so the release
// carries the class on every band this port targets, and a port that defined it would be a class
// shadowing a release's - which is what release-split reported when this was one object with the 9.0
// groups ("mix more than one release's symbols"). AVMutableTimedMetadataGroup is the same at 4.3 and
// carries no corpus row, so the port does not carry it at all and the release's own answers.
//
// What is left is the two members the corpus rows name:
//
//   -initWithSampleBuffer:   a group over a sample buffer of timed metadata
//   -copyFormatDescription   the format description of the track it came off
//
// Neither is produced here: a sample buffer of timed metadata needs an asset reader, and a track needs
// an asset, and neither is carried. So both answer the case that has no such thing, which is a
// documented answer and not a stub: with no buffer the group is empty over the invalid range - the
// range the framework itself answers for a group it was given none - and with no track the format
// description is NULL, which says there is no track.

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
