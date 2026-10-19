#import <AVFoundation/AVFoundation.h>

// Two of iOS 13's members that a release this port runs on already answers, in pieces the port can
// ask the release for. Both are categories, so both are kept from their band's minimum up and
// install themselves only where the release is short: packages/a/apple-backports/attach.c's
// charon_collect adds a category's method only when charon_implements() finds nothing, so at 13.0
// and above - where the release carries both selectors in its own table - neither copy is installed
// and the release's own bodies run. The measurements are in facts/AVFoundation/AVFoundation13.md.

// +[AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:prototypeInstruction:], iOS 13.
//
// The header defines the method as the release's own one-argument factory plus an override, and names
// videoCompositionWithPropertiesOfAsset: as its companion. The returned AVVideoComposition is built from
// instructions honoring each video track's spatial properties and its timeRanges. Anything
// outside spatial arrangement and timing, such as the background color of a composition or its
// post-processing behaviors, is left to a prototype instruction the caller supplies.
//
// Both halves are separate halves. 6.1.3's AVMutableVideoComposition carries 12 own instance
// selectors and 3 class selectors, and the class selectors are +videoComposition,
// +videoCompositionWithPropertiesOfAsset: and +videoCompositionWithPropertiesOfAsset:videoGravity: -
// the first half, present since iOS 6 and deprecated only at iOS 18. AVVideoCompositionInstruction
// carries backgroundColor, enablePostProcessing, layerInstructions and timeRange at 6.1.3 and at
// 12.0, which is the whole of the second half.
//
// So the spatial and timing half is the release's own computation and is not recomputed here: the
// instructions it built are the ones that carry the asset's tracks' transforms and time range. Each
// is replaced by a copy of the caller's prototype instruction - which is what "uses copies of this
// instruction" means - keeping the release's two spatial members and taking everything else from the
// prototype. An asset with no video track yields no instructions from the release, and an empty
// instruction array is what the header says that case returns.
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

// AVCaptureVideoPreviewLayer.previewing, iOS 13, whose getter the header declares isPreviewing.
//
// The header gives the moment the value changes: a preview layer begins previewing once startRunning
// has been called on the session, and while the session runs the layer's connection can be turned on or
// off to start or stop the video reaching the layer. That is the
// predicate below, and all four members it asks are public API the release carries at both band
// ends: -session and -connection on the layer (connection is API_AVAILABLE(ios(6.0))), -isRunning on
// the session and -isEnabled on the connection.
//
// The release's own isPreviewing is on AVCaptureSession, not on the layer, and no SDK header declares
// it, so forwarding to it would be a private call. The layer's own -connections and -activeConnections
// are likewise undeclared, so neither is asked; -connection is the public singular form and is what
// the layer's -initWithSession: and -setSession: fill in.
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
