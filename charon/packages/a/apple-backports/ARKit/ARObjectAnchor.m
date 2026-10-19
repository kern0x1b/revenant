// ARObjectAnchor.m - a scanned object found in the room, at 12.0 with object detection.
//
// An object is found by matching a scanned reference object against the frames, and the port's tracker
// matches features between frames to find planes and nothing else, so no session reports one. The class
// is carried so the name resolves; the reference object it would name is the one a session would have
// found, which is none. See facts/ARKit/SensorShells.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARObjectAnchor

@synthesize referenceObject = _referenceObject;

@end

NS_ASSUME_NONNULL_END
