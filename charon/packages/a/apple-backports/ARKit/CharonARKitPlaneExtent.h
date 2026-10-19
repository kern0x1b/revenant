// CharonARKitPlaneExtent.h - the plane's extent, declared here so that the object carrying it can be
// compiled on its own.
//
// ARPlaneExtent arrived in 16.0 and the 16.4 SDK this package compiles against declares it, in
// `ARKit.framework/Headers/ARPlaneAnchor.h`. What is below is declared from that header and
// nothing else is added: three readonly floats on an NSObject that adopts NSSecureCoding.
//
// Why a declaration here when the build SDK already declares it: the object that implements the class
// then names one declaration, this one, instead of the SDK's, and `API_AVAILABLE(ios(16.0))` is not
// carried over. An attribute that names iOS is an error in the macOS build the host check compiles
// this into, and silencing it on the device build would mean a new
// `#pragma clang diagnostic ignored "-Wunguarded-availability-new"`, which this package does not add
// (the rule is in ../facts/../../../../AGENTS.md). The release the class belongs to is named by the
// file that implements it and by its registry rows, not by an attribute in a header. The declaration
// the release itself carries is in ARKitCore, and its own method list is what the facts page reads.
//
// A caller that imports both this and `<ARKit/ARKit.h>` gets two declarations of one class in one
// translation unit, which is an error; a caller imports this one only when it wants the class without
// the framework's umbrella, which is what the harness that round-trips the archive does.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The extents of a plane: how wide it is, how deep, and how far it is turned about the vertical.
@interface ARPlaneExtent : NSObject <NSSecureCoding>

@property (nonatomic, readonly) float rotationOnYAxis;

/// applying .rotationOnYAxis.
@property (nonatomic, readonly) float width;

@property (nonatomic, readonly) float height;

@end

NS_ASSUME_NONNULL_END
