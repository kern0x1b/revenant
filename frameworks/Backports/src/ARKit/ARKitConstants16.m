#include "../revenant_impl.h"
#import <ARKit/ARKit.h>

#pragma mark - The body's joints

NSString * const BACKPORT_IMPL(ARSkeletonJointNameRoot) = @"root";
NSString * const BACKPORT_IMPL(ARSkeletonJointNameHead) = @"head_joint";
NSString * const BACKPORT_IMPL(ARSkeletonJointNameLeftShoulder) = @"left_shoulder_1_joint";
NSString * const BACKPORT_IMPL(ARSkeletonJointNameRightShoulder) = @"right_shoulder_1_joint";
NSString * const BACKPORT_IMPL(ARSkeletonJointNameLeftHand) = @"left_hand_joint";
NSString * const BACKPORT_IMPL(ARSkeletonJointNameRightHand) = @"right_hand_joint";
NSString * const BACKPORT_IMPL(ARSkeletonJointNameLeftFoot) = @"left_foot_joint";
NSString * const BACKPORT_IMPL(ARSkeletonJointNameRightFoot) = @"right_foot_joint";
