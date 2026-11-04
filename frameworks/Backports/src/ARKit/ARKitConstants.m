#include "../revenant_impl.h"
#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>

NSString * const BACKPORT_IMPL(ARErrorDomain) = @"com.apple.arkit.error";

const SCNDebugOptions BACKPORT_IMPL(ARSCNDebugOptionShowFeaturePoints) = (1 << 0);
const SCNDebugOptions BACKPORT_IMPL(ARSCNDebugOptionShowWorldOrigin) = (1 << 1);

#pragma mark - The face's blend shapes

ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationBrowDownLeft) = @"browDownLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationBrowDownRight) = @"browDownRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationBrowInnerUp) = @"browInnerUp";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationBrowOuterUpLeft) = @"browOuterUpLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationBrowOuterUpRight) = @"browOuterUpRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationCheekPuff) = @"cheekPuff";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationCheekSquintLeft) = @"cheekSquintLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationCheekSquintRight) = @"cheekSquintRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeBlinkLeft) = @"eyeBlinkLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeBlinkRight) = @"eyeBlinkRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeLookDownLeft) = @"eyeLookDownLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeLookDownRight) = @"eyeLookDownRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeLookInLeft) = @"eyeLookInLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeLookInRight) = @"eyeLookInRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeLookOutLeft) = @"eyeLookOutLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeLookOutRight) = @"eyeLookOutRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeLookUpLeft) = @"eyeLookUpLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeLookUpRight) = @"eyeLookUpRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeSquintLeft) = @"eyeSquintLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeSquintRight) = @"eyeSquintRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeWideLeft) = @"eyeWideLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationEyeWideRight) = @"eyeWideRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationJawForward) = @"jawForward";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationJawLeft) = @"jawLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationJawOpen) = @"jawOpen";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationJawRight) = @"jawRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthClose) = @"mouthClose";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthDimpleLeft) = @"mouthDimpleLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthDimpleRight) = @"mouthDimpleRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthFrownLeft) = @"mouthFrownLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthFrownRight) = @"mouthFrownRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthFunnel) = @"mouthFunnel";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthLeft) = @"mouthLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthLowerDownLeft) = @"mouthLowerDownLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthLowerDownRight) = @"mouthLowerDownRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthPressLeft) = @"mouthPressLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthPressRight) = @"mouthPressRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthPucker) = @"mouthPucker";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthRight) = @"mouthRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthRollLower) = @"mouthRollLower";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthRollUpper) = @"mouthRollUpper";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthShrugLower) = @"mouthShrugLower";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthShrugUpper) = @"mouthShrugUpper";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthSmileLeft) = @"mouthSmileLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthSmileRight) = @"mouthSmileRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthStretchLeft) = @"mouthStretchLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthStretchRight) = @"mouthStretchRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthUpperUpLeft) = @"mouthUpperUpLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationMouthUpperUpRight) = @"mouthUpperUpRight";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationNoseSneerLeft) = @"noseSneerLeft";
ARBlendShapeLocation const BACKPORT_IMPL(ARBlendShapeLocationNoseSneerRight) = @"noseSneerRight";
