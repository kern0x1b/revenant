#import <AVFoundation/AVFoundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation AVVideoComposition (CharonAVFoundationSourceTrackForFrameTiming)

- (CMPersistentTrackID)sourceTrackIDForFrameTiming
{
    for (id instruction in self.instructions) {
        if (![instruction isKindOfClass:[AVVideoCompositionInstruction class]])
            continue;
        NSArray *layers = [(AVVideoCompositionInstruction *)instruction layerInstructions];
        if (layers.count == 0)
            continue;
        return [(AVVideoCompositionLayerInstruction *)layers.firstObject trackID];
    }
    return kCMPersistentTrackID_Invalid;
}

@end

@implementation AVMutableVideoComposition (CharonAVFoundationMutableSourceTrackForFrameTiming)

- (CMPersistentTrackID)sourceTrackIDForFrameTiming
{
    return [super sourceTrackIDForFrameTiming];
}

@end
