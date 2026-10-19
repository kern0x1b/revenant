#import <AVFoundation/AVFoundation.h>

// Every method below is one the 16.4 SDK declares on its own class and places at iOS 11, and the
// release this object is built for has no such member; the same diagnostic for that is what
// AVCaptureDevice+VideoZoom7.m:7 already carries.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// iOS 11's AVFoundation on 6.1.3: two of the 32 rows at 11.0 that 6.1.3 has the substrate for, and
// the 30 that it does not. The two are one answer the release can compute rather than vocabulary it
// lacks, and each of the two rows is carried by a definition on the class the row names.
//
//   sourceTrackIDForFrameTiming, on the composition and on the mutable subclass, is the trackID of the
//     first layer instruction of the first instruction: AVVideoComposition.h:94 says frame timing is
//     derived from "the source asset's track with the corresponding ID", AVVideoComposition.h:650 is
//     the layer instruction's own trackID, and 6.1.3 carries both. kCMPersistentTrackID_Invalid is an
//     enumeration case (CMBase.h:347) and not a symbol, so the composition that names no track needs
//     no symbol to say so.
//   The subclass carries the selector in a category of its own and forwards to the superclass, because
//     a category adds a selector to the class it is written on and not to that class's subclasses, and
//     the surface names a row for each of the two. Dispatch would reach the superclass either way; what
//     the registry asks is what this object defines.
//
// The 30 absent rows are in three families: HLS offlining (which needs a download task this release
// does not have), depth and calibration (which needs a depth format this release does not have), and
// the members of classes that are not on this release at all. See facts/AVFoundation/AVFoundation110.md.

@implementation AVVideoComposition (CharonAVFoundationSourceTrackForFrameTiming)

- (CMPersistentTrackID)sourceTrackIDForFrameTiming
{
    for (id instruction in self.instructions) {
        // -layerInstructions is declared on the instruction class and not on the 7.0 protocol
        // (AVVideoComposition.h:569), which is why the release's own class is named here; 6.1.3 carries
        // both members, and a composition whose instruction is not of this class has no layer
        // instructions on this release either.
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