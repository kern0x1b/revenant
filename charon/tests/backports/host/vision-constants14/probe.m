/* probe.m - prints every string constant of Vision that iOS 14 added, one `name=value` line each, read with UTF8String
 * so the two sides compare by bytes. Compiled once against the host's Vision framework and once against the port's
 * Vision14_0Constants.m (the same source, the same names, no framework linked on the port side). */
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>

#define SHOW(name) printf("%s=%s\n", #name, [(NSString *)(name) UTF8String])

int main(void)
{
    @autoreleasepool {
        SHOW(VNBodyLandmarkKeyLeftAnkle);
        SHOW(VNBodyLandmarkKeyLeftEar);
        SHOW(VNBodyLandmarkKeyLeftElbow);
        SHOW(VNBodyLandmarkKeyLeftEye);
        SHOW(VNBodyLandmarkKeyLeftHip);
        SHOW(VNBodyLandmarkKeyLeftKnee);
        SHOW(VNBodyLandmarkKeyLeftShoulder);
        SHOW(VNBodyLandmarkKeyLeftWrist);
        SHOW(VNBodyLandmarkKeyNeck);
        SHOW(VNBodyLandmarkKeyNose);
        SHOW(VNBodyLandmarkKeyRightAnkle);
        SHOW(VNBodyLandmarkKeyRightEar);
        SHOW(VNBodyLandmarkKeyRightElbow);
        SHOW(VNBodyLandmarkKeyRightEye);
        SHOW(VNBodyLandmarkKeyRightHip);
        SHOW(VNBodyLandmarkKeyRightKnee);
        SHOW(VNBodyLandmarkKeyRightShoulder);
        SHOW(VNBodyLandmarkKeyRightWrist);
        SHOW(VNBodyLandmarkKeyRoot);
        SHOW(VNBodyLandmarkRegionKeyFace);
        SHOW(VNBodyLandmarkRegionKeyLeftArm);
        SHOW(VNBodyLandmarkRegionKeyLeftLeg);
        SHOW(VNBodyLandmarkRegionKeyRightArm);
        SHOW(VNBodyLandmarkRegionKeyRightLeg);
        SHOW(VNBodyLandmarkRegionKeyTorso);
        SHOW(VNHumanBodyPoseObservationJointNameLeftAnkle);
        SHOW(VNHumanBodyPoseObservationJointNameLeftEar);
        SHOW(VNHumanBodyPoseObservationJointNameLeftElbow);
        SHOW(VNHumanBodyPoseObservationJointNameLeftEye);
        SHOW(VNHumanBodyPoseObservationJointNameLeftHip);
        SHOW(VNHumanBodyPoseObservationJointNameLeftKnee);
        SHOW(VNHumanBodyPoseObservationJointNameLeftShoulder);
        SHOW(VNHumanBodyPoseObservationJointNameLeftWrist);
        SHOW(VNHumanBodyPoseObservationJointNameNeck);
        SHOW(VNHumanBodyPoseObservationJointNameNose);
        SHOW(VNHumanBodyPoseObservationJointNameRightAnkle);
        SHOW(VNHumanBodyPoseObservationJointNameRightEar);
        SHOW(VNHumanBodyPoseObservationJointNameRightElbow);
        SHOW(VNHumanBodyPoseObservationJointNameRightEye);
        SHOW(VNHumanBodyPoseObservationJointNameRightHip);
        SHOW(VNHumanBodyPoseObservationJointNameRightKnee);
        SHOW(VNHumanBodyPoseObservationJointNameRightShoulder);
        SHOW(VNHumanBodyPoseObservationJointNameRightWrist);
        SHOW(VNHumanBodyPoseObservationJointNameRoot);
        SHOW(VNHumanBodyPoseObservationJointsGroupNameAll);
        SHOW(VNHumanBodyPoseObservationJointsGroupNameFace);
        SHOW(VNHumanBodyPoseObservationJointsGroupNameLeftArm);
        SHOW(VNHumanBodyPoseObservationJointsGroupNameLeftLeg);
        SHOW(VNHumanBodyPoseObservationJointsGroupNameRightArm);
        SHOW(VNHumanBodyPoseObservationJointsGroupNameRightLeg);
        SHOW(VNHumanBodyPoseObservationJointsGroupNameTorso);
        SHOW(VNHumanHandPoseObservationJointNameIndexDIP);
        SHOW(VNHumanHandPoseObservationJointNameIndexMCP);
        SHOW(VNHumanHandPoseObservationJointNameIndexPIP);
        SHOW(VNHumanHandPoseObservationJointNameIndexTip);
        SHOW(VNHumanHandPoseObservationJointNameLittleDIP);
        SHOW(VNHumanHandPoseObservationJointNameLittleMCP);
        SHOW(VNHumanHandPoseObservationJointNameLittlePIP);
        SHOW(VNHumanHandPoseObservationJointNameLittleTip);
        SHOW(VNHumanHandPoseObservationJointNameMiddleDIP);
        SHOW(VNHumanHandPoseObservationJointNameMiddleMCP);
        SHOW(VNHumanHandPoseObservationJointNameMiddlePIP);
        SHOW(VNHumanHandPoseObservationJointNameMiddleTip);
        SHOW(VNHumanHandPoseObservationJointNameRingDIP);
        SHOW(VNHumanHandPoseObservationJointNameRingMCP);
        SHOW(VNHumanHandPoseObservationJointNameRingPIP);
        SHOW(VNHumanHandPoseObservationJointNameRingTip);
        SHOW(VNHumanHandPoseObservationJointNameThumbCMC);
        SHOW(VNHumanHandPoseObservationJointNameThumbIP);
        SHOW(VNHumanHandPoseObservationJointNameThumbMP);
        SHOW(VNHumanHandPoseObservationJointNameThumbTip);
        SHOW(VNHumanHandPoseObservationJointNameWrist);
        SHOW(VNHumanHandPoseObservationJointsGroupNameAll);
        SHOW(VNHumanHandPoseObservationJointsGroupNameIndexFinger);
        SHOW(VNHumanHandPoseObservationJointsGroupNameLittleFinger);
        SHOW(VNHumanHandPoseObservationJointsGroupNameMiddleFinger);
        SHOW(VNHumanHandPoseObservationJointsGroupNameRingFinger);
        SHOW(VNHumanHandPoseObservationJointsGroupNameThumb);
        SHOW(VNRecognizedPoint3DGroupKeyAll);
        SHOW(VNRecognizedPointGroupKeyAll);
        SHOW(VNVideoProcessingOptionFrameCadence);
        SHOW(VNVideoProcessingOptionTimeInterval);
    }
    return 0;
}
