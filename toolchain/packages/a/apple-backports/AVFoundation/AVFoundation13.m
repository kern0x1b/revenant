#import <AVFoundation/AVFoundation.h>

@implementation AVMutableVideoComposition (CharonAVFoundation13)

+ (AVMutableVideoComposition *)videoCompositionWithPropertiesOfAsset:(AVAsset *)asset
                                              prototypeInstruction:(AVVideoCompositionInstruction *)prototypeInstruction
{
    AVMutableVideoComposition *composition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset];
    if (prototypeInstruction == nil) {
        return composition;
    }
    NSArray<id<AVVideoCompositionInstruction>> *built = composition.instructions;
    NSMutableArray<AVVideoCompositionInstruction *> *instructions =
        [NSMutableArray arrayWithCapacity:[built count]];
    for (AVVideoCompositionInstruction *instruction in built) {
        AVMutableVideoCompositionInstruction *instructionCopy = [prototypeInstruction mutableCopy];
        [instructionCopy setTimeRange:[instruction timeRange]];
        [instructionCopy setLayerInstructions:[instruction layerInstructions]];
        [instructions addObject:instructionCopy];
    }
    [composition setInstructions:instructions];
    return composition;
}

@end

@implementation AVCaptureVideoPreviewLayer (CharonAVFoundation13)

- (BOOL)isPreviewing
{
    AVCaptureSession *session = self.session;
    if (session == nil || ![session isRunning]) {
        return NO;
    }
    AVCaptureConnection *connection = self.connection;
    return connection != nil && [connection isEnabled];
}

@end
