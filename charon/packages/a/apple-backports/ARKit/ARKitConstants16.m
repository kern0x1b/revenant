// ARKitConstants16.m - the constants of the 16.0 headers.
//
// Split from ARKitConstants.m because an object carries the API of one release. These are the nine
// joint names a body anchor's geometry is indexed by, which arrived with the body tracking the 16.0
// headers declare in ARConfiguration4.m.
//
// The values are the ones ARKitCore itself answers with, read out of the arm64e shared cache of
// iOS 16.0 with tools/corpus/cache-value.lua (the project's own reader, the same one the constant
// rows of every framework are read with). `facts/ARKit/Skeleton.md` has the addresses, the table
// each value was read from and the controls that make the read mean something. The seven names
// that carry a `_joint` suffix here were written without it before, and the two shoulder names
// carry the `_1` a second shoulder would take: a body tracked from the front camera has one pair of
// shoulders in this table, so a name without it is not a name the release has.

#import <ARKit/ARKit.h>

#pragma mark - The body's joints

NSString * const ARSkeletonJointNameRoot = @"root";
NSString * const ARSkeletonJointNameHead = @"head_joint";
NSString * const ARSkeletonJointNameLeftShoulder = @"left_shoulder_1_joint";
NSString * const ARSkeletonJointNameRightShoulder = @"right_shoulder_1_joint";
NSString * const ARSkeletonJointNameLeftHand = @"left_hand_joint";
NSString * const ARSkeletonJointNameRightHand = @"right_hand_joint";
NSString * const ARSkeletonJointNameLeftFoot = @"left_foot_joint";
NSString * const ARSkeletonJointNameRightFoot = @"right_foot_joint";