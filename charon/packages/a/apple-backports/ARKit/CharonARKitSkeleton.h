// CharonARKitSkeleton.h - the body's skeleton, declared here because the 16.4 SDK's headers do not
// carry it.
//
// ARKit's skeleton classes arrived in 13.0 and the build SDK this package compiles against is 16.4,
// whose ARKit.framework headers stop at ARBody2D and ARBodyAnchor. What is declared here is
// transcribed from the 26.2 SDK SDK this workspace keeps
// (`.agent-work/sdk-26.2/iPhoneOS26.2.sdk/System/Library/Frameworks/ARKit.framework/Headers`), and
// only the API of 13.0, and only `ARSkeletonDefinition` itself: the skeleton classes that carry a pose
// are declared where they are implemented, which is not here, because there is no body in front of this
// device's camera to measure a pose from.
//
// `ARSkeletonDefinition` is the one class of the family that carries data rather than a pose, so it
// is the one that can be answered without a body in front of the camera. Its table is Apple's, read
// out of the release (see `facts/ARKit/Skeleton.md`); nothing here is a plausible-looking skeleton.

#import <Foundation/Foundation.h>

// Apple's header writes `NS_TYPED_ENUM` and `NS_REFINED_FOR_SWIFT` on these. Both expand to
// availability attributes naming iOS, and an attribute that names iOS is an error in the macOS build
// the host differential compiles this header into -- so they are not carried here. They are Swift
// refinements of Apple's own headers, not part of the Objective-C API this package implements, and the
// declarations below are what the port and the differential both need.
typedef NSString *ARSkeletonJointName;

NS_ASSUME_NONNULL_BEGIN

/// The joints a body is made of, and which of them each hangs from.
@interface ARSkeletonDefinition : NSObject

@property (class, nonatomic, readonly) ARSkeletonDefinition *defaultBody2DSkeletonDefinition;

@property (nonatomic, readonly) NSUInteger jointCount;
@property (nonatomic, readonly) NSArray<NSString *> *jointNames;
@property (nonatomic, readonly) NSArray<NSNumber *> *parentIndices;

- (NSUInteger)indexForJointName:(ARSkeletonJointName)jointName;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END