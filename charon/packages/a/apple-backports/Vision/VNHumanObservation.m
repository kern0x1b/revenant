#import "CharonVision.h"

/* Its own object: the SDK marks the class 15.0, but the held release caches export it from 11.0, and the gate
 * places an object by the earliest release that exports what it defines, so it cannot share an object with the
 * 15.0 symbologies and functions of Vision15_0.m. */

/* A person the human rectangles request finds, as the release's type of its results. The request itself answers
 * VNErrorNotImplemented in the port (Vision110.m), so the port makes no VNHumanObservation of its own; the class is
 * here as the release has it. An object made with -init answers as the host's does (facts/Vision/Human15.md): the
 * upper body alone is NO, the bounding box is zero, and the confidence is the superclass's, 1. */
@implementation VNHumanObservation {
    BOOL _upperBodyOnly;
}

@end
