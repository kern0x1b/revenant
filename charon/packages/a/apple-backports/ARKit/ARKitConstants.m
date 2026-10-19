// ARKitConstants.m - the constants the SDK's headers declare as symbols, with the values they declare.
//
// The run options, the plane detections, the raycast targets, the plane alignments, the hit-test
// types, the error codes, the confidence levels, the tracking reasons and the frame semantics are
// cases of the SDK's own enumerations, and a case of an enumeration is written into the program by
// the compiler: there is nothing here to define, and the registry says so too. What this file does
// define is the three kinds the headers declare with FOUNDATION_EXTERN, which the release carries
// no definition of: the two string constants and the SceneKit debug options, and the fifty-two
// blend-shape names and the nine skeleton joint names the face and body geometry are indexed by.
//
// The values are the framework's own. `ARErrorDomain` and `ARReferenceObjectArchiveExtension` are
// read out of ARKit of iOS 12.0 (the strings themselves), and the debug options are the two bits
// `ARSCNDebugOption` declares. The 52 names and the 9 joints are the strings Apple's own
// ARFaceAnchor and ARBodyAnchor use as keys into their geometry buffers, written down here because
// the classes that read them are carried and an application indexes its own mesh with them.

#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>

NSString * const ARErrorDomain = @"com.apple.arkit.error";

const SCNDebugOptions ARSCNDebugOptionShowFeaturePoints = (1 << 0);
const SCNDebugOptions ARSCNDebugOptionShowWorldOrigin = (1 << 1);

#pragma mark - The face's blend shapes

ARBlendShapeLocation const ARBlendShapeLocationBrowDownLeft = @"browDownLeft";
ARBlendShapeLocation const ARBlendShapeLocationBrowDownRight = @"browDownRight";
ARBlendShapeLocation const ARBlendShapeLocationBrowInnerUp = @"browInnerUp";
ARBlendShapeLocation const ARBlendShapeLocationBrowOuterUpLeft = @"browOuterUpLeft";
ARBlendShapeLocation const ARBlendShapeLocationBrowOuterUpRight = @"browOuterUpRight";
ARBlendShapeLocation const ARBlendShapeLocationCheekPuff = @"cheekPuff";
ARBlendShapeLocation const ARBlendShapeLocationCheekSquintLeft = @"cheekSquintLeft";
ARBlendShapeLocation const ARBlendShapeLocationCheekSquintRight = @"cheekSquintRight";
ARBlendShapeLocation const ARBlendShapeLocationEyeBlinkLeft = @"eyeBlinkLeft";
ARBlendShapeLocation const ARBlendShapeLocationEyeBlinkRight = @"eyeBlinkRight";
ARBlendShapeLocation const ARBlendShapeLocationEyeLookDownLeft = @"eyeLookDownLeft";
ARBlendShapeLocation const ARBlendShapeLocationEyeLookDownRight = @"eyeLookDownRight";
ARBlendShapeLocation const ARBlendShapeLocationEyeLookInLeft = @"eyeLookInLeft";
ARBlendShapeLocation const ARBlendShapeLocationEyeLookInRight = @"eyeLookInRight";
ARBlendShapeLocation const ARBlendShapeLocationEyeLookOutLeft = @"eyeLookOutLeft";
ARBlendShapeLocation const ARBlendShapeLocationEyeLookOutRight = @"eyeLookOutRight";
ARBlendShapeLocation const ARBlendShapeLocationEyeLookUpLeft = @"eyeLookUpLeft";
ARBlendShapeLocation const ARBlendShapeLocationEyeLookUpRight = @"eyeLookUpRight";
ARBlendShapeLocation const ARBlendShapeLocationEyeSquintLeft = @"eyeSquintLeft";
ARBlendShapeLocation const ARBlendShapeLocationEyeSquintRight = @"eyeSquintRight";
ARBlendShapeLocation const ARBlendShapeLocationEyeWideLeft = @"eyeWideLeft";
ARBlendShapeLocation const ARBlendShapeLocationEyeWideRight = @"eyeWideRight";
ARBlendShapeLocation const ARBlendShapeLocationJawForward = @"jawForward";
ARBlendShapeLocation const ARBlendShapeLocationJawLeft = @"jawLeft";
ARBlendShapeLocation const ARBlendShapeLocationJawOpen = @"jawOpen";
ARBlendShapeLocation const ARBlendShapeLocationJawRight = @"jawRight";
ARBlendShapeLocation const ARBlendShapeLocationMouthClose = @"mouthClose";
ARBlendShapeLocation const ARBlendShapeLocationMouthDimpleLeft = @"mouthDimpleLeft";
ARBlendShapeLocation const ARBlendShapeLocationMouthDimpleRight = @"mouthDimpleRight";
ARBlendShapeLocation const ARBlendShapeLocationMouthFrownLeft = @"mouthFrownLeft";
ARBlendShapeLocation const ARBlendShapeLocationMouthFrownRight = @"mouthFrownRight";
ARBlendShapeLocation const ARBlendShapeLocationMouthFunnel = @"mouthFunnel";
ARBlendShapeLocation const ARBlendShapeLocationMouthLeft = @"mouthLeft";
ARBlendShapeLocation const ARBlendShapeLocationMouthLowerDownLeft = @"mouthLowerDownLeft";
ARBlendShapeLocation const ARBlendShapeLocationMouthLowerDownRight = @"mouthLowerDownRight";
ARBlendShapeLocation const ARBlendShapeLocationMouthPressLeft = @"mouthPressLeft";
ARBlendShapeLocation const ARBlendShapeLocationMouthPressRight = @"mouthPressRight";
ARBlendShapeLocation const ARBlendShapeLocationMouthPucker = @"mouthPucker";
ARBlendShapeLocation const ARBlendShapeLocationMouthRight = @"mouthRight";
ARBlendShapeLocation const ARBlendShapeLocationMouthRollLower = @"mouthRollLower";
ARBlendShapeLocation const ARBlendShapeLocationMouthRollUpper = @"mouthRollUpper";
ARBlendShapeLocation const ARBlendShapeLocationMouthShrugLower = @"mouthShrugLower";
ARBlendShapeLocation const ARBlendShapeLocationMouthShrugUpper = @"mouthShrugUpper";
ARBlendShapeLocation const ARBlendShapeLocationMouthSmileLeft = @"mouthSmileLeft";
ARBlendShapeLocation const ARBlendShapeLocationMouthSmileRight = @"mouthSmileRight";
ARBlendShapeLocation const ARBlendShapeLocationMouthStretchLeft = @"mouthStretchLeft";
ARBlendShapeLocation const ARBlendShapeLocationMouthStretchRight = @"mouthStretchRight";
ARBlendShapeLocation const ARBlendShapeLocationMouthUpperUpLeft = @"mouthUpperUpLeft";
ARBlendShapeLocation const ARBlendShapeLocationMouthUpperUpRight = @"mouthUpperUpRight";
ARBlendShapeLocation const ARBlendShapeLocationNoseSneerLeft = @"noseSneerLeft";
ARBlendShapeLocation const ARBlendShapeLocationNoseSneerRight = @"noseSneerRight";
