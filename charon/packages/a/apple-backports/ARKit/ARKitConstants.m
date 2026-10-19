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
