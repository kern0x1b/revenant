#import "CharonAVMetrics18.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../../../c/charon-coding/files/CharonCoding.h"

@implementation AVMetricMediaRendition

@synthesize stableID = _stableID;
@synthesize URL = _URL;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = charon_intents_super_init(self, [NSObject class]))) {
        charon_intents_decode(self, coder);
    }
    return self;
}

@end

static id CharonAVMetricRenditionValue(id object, NSString *property)
{
    return objc_getAssociatedObject(object, property.UTF8String);
}

#define CHARON_AVF_RENDITION_GETTER(CLASS, PROPERTY)                                          \
    - (AVMetricMediaRendition *)PROPERTY                                                       \
    {                                                                                          \
        NSString *key = [NSString stringWithFormat:@"%@.%@", @#CLASS, @#PROPERTY];              \
        return CharonAVMetricRenditionValue(self, key);                                        \
    }

@implementation AVMetricPlayerItemVariantSwitchEvent (Renditions26)
CHARON_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchEvent, videoRendition)
CHARON_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchEvent, audioRendition)
CHARON_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchEvent, subtitleRendition)
@end

@implementation AVMetricPlayerItemVariantSwitchStartEvent (Renditions26)
CHARON_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchStartEvent, videoRendition)
CHARON_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchStartEvent, audioRendition)
CHARON_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchStartEvent, subtitleRendition)
@end
