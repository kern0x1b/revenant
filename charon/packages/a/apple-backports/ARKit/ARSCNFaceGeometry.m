// ARSCNFaceGeometry.m - a face's mesh in SceneKit's form, at 11.0 beside ARFaceGeometry, which it is drawn from.
//
// A SceneKit face geometry is built from an ARFaceGeometry, and that is measured by the TrueDepth camera this
// device lacks (ARFaceGeometry.m). The class is carried as a SceneKit geometry, so the name resolves and its
// init is SCNGeometry's own, as the SDK's unavailable -init says it is on the release. The factories and the
// update from a face mesh are not carried; facts/ARKit/AbsentClasses.md.

#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARSCNFaceGeometry

@end

NS_ASSUME_NONNULL_END
