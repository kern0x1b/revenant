// ARFaceAnchor.m - a tracked face, at 11.0 where it arrived with the front camera's depth.
//
// A face is measured across by the TrueDepth sensor, and this device has no depth sensor, so no
// session on it ever reports a face and no ARFaceAnchor is ever handed to an application. The class
// is carried whole anyway: an application that names it in a cast or a test must find it there, and
// its members answer what a session would have put in them - the empty answer of a face that was never
// seen. The initialisers are the anchor's own, as the release's class inherits them; see
// facts/ARKit/SensorShells.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARFaceAnchor

@synthesize geometry = _geometry;
@synthesize blendShapes = _blendShapes;
@synthesize leftEyeTransform = _leftEyeTransform;
@synthesize rightEyeTransform = _rightEyeTransform;
@synthesize lookAtPoint = _lookAtPoint;

@end

NS_ASSUME_NONNULL_END
