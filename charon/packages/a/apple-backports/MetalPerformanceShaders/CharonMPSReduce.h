// The one internal method that lets the eight concrete MPSImageReduce classes say which operation and which axis
// they are, and the operation's names. Shared by MPSImageReduceUnary16.m (the base, which implements it) and
// MPSImageReduce12.m (the eight concrete classes, which call it). Two objects because the release exports the
// eight concrete classes from iOS 12.0 and MPSImageReduceUnary from iOS 16.0, and an object carries one release.
//
// The MPSNNReduceUnary seam below is here for the same reason and is shared the same way: MPSNNReduce16.m
// implements it and MPSNNReduce12.m's twelve concrete classes call it, because the release exports the
// twelve from iOS 12.0 and the base only from iOS 16.0. The operation enum is already this one's own -
// MPSNNReduce's twelve classes are the same four operations over the same three axes plus the feature
// channel, which is why MPSNNReduce12.m imports this header and not a second one.
#pragma once
#import "CharonMPS.h"
#import "CharonMPSImage.h"

// Which of the four operations, and over which axis. The eight concrete classes differ only in these two.
typedef NS_ENUM(NSInteger, CharonMPSReduceOperation) {
    CharonMPSReduceMin = 0,
    CharonMPSReduceMax,
    CharonMPSReduceMean,
    CharonMPSReduceSum,
};

@interface MPSImageReduceUnary ()
// Internal, and the base's real designated initialiser. This is how a concrete class says which of the
// eight operations it is and over which axis, without a subclass reaching into the base's storage and
// without going through the base's refusing -initWithDevice: below.
//
// WHY THIS IS NOT AN `init` METHOD, which is the whole of the crutch recorded in
// coordination/crutches.md: NS_DESIGNATED_INITIALIZER is only accepted on a method whose name begins with
// "init", so this cannot be marked designated - clang rejects the attribute outright with
// "'objc_designated_initializer' attribute only applies to init methods of interface or class extension".
// The SDK marks the base's -initWithDevice: NS_UNAVAILABLE (:44-47) and each concrete class's
// -initWithDevice: NS_DESIGNATED_INITIALIZER, so clang requires the concrete one to call a designated
// initializer of the base, and the base's only designated initializer is -initWithCoder:device:, which
// cannot know which of the eight operations to build and takes a nonnull coder this path has no use for.
// Passing a nil coder to it was tried and is worse than the warning: it passes null to a nonnull parameter.
//
// The native fix, when one exists, is a header of our own that declares the hierarchy's designated
// initializer; the release's own chain is unreachable from outside because the class it would have to be
// declared on is the SDK's.
- (instancetype)charon_initWithDevice:(id<MTLDevice>)device
                            byColumn:(BOOL)byColumn
                            operation:(CharonMPSReduceOperation)operation;
@end

// The same seam for MPSNNReduceUnary, and the same reason it is not an `init` method: the SDK marks the
// base's -initWithDevice: NS_UNAVAILABLE (:44-47) and each concrete class's NS_DESIGNATED_INITIALIZER,
// over the same four operations and with the third axis - the feature channel - MPSImageReduceUnary
// does not have. Implemented in MPSNNReduce16.m, called by MPSNNReduce12.m's twelve concrete classes.
// The two weight accessors are here and not only in the base because the SDK declares `weight` on the
// CONCRETE feature-channel classes, so a caller that sets it has to reach the base's storage; see
// MPSNNReduce12.m for the measurement of which classes declare it.
@interface MPSNNReduceUnary (CharonMPSNNReduce)
- (instancetype)charon_nnReduceWithDevice:(id<MTLDevice>)device
                                   byColumn:(BOOL)byColumn
                           byFeatureChannel:(BOOL)byFeatureChannel
                                 operation:(CharonMPSReduceOperation)operation;
- (float)charon_nnReduceWeight;
- (void)charon_setNnReduceWeight:(float)weight;
@end
