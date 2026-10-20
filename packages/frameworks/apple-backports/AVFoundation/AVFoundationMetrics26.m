#import "RevenantAVMetrics18.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "RevenantCoding.h"

@implementation AVMetricMediaRendition

@synthesize stableID = _stableID;
@synthesize URL = _URL;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = revenant_intents_super_init(self, [NSObject class]))) {
        revenant_intents_decode(self, coder);
    }
    return self;
}

@end

static id RevenantAVMetricRenditionValue(id object, NSString *property)
{
    return objc_getAssociatedObject(object, property.UTF8String);
}

#define REVENANT_AVF_RENDITION_GETTER(CLASS, PROPERTY)                                          \
    - (AVMetricMediaRendition *)PROPERTY                                                       \
    {                                                                                          \
        NSString *key = [NSString stringWithFormat:@"%@.%@", @#CLASS, @#PROPERTY];              \
        return RevenantAVMetricRenditionValue(self, key);                                        \
    }

@implementation AVMetricPlayerItemVariantSwitchEvent (Renditions26)
REVENANT_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchEvent, videoRendition)
REVENANT_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchEvent, audioRendition)
REVENANT_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchEvent, subtitleRendition)
@end

@implementation AVMetricPlayerItemVariantSwitchStartEvent (Renditions26)
REVENANT_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchStartEvent, videoRendition)
REVENANT_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchStartEvent, audioRendition)
REVENANT_AVF_RENDITION_GETTER(AVMetricPlayerItemVariantSwitchStartEvent, subtitleRendition)
@end
