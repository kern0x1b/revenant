// ARMeshAnchor.m - a mesh of the room, at 13.4 where the scene reconstruction of a depth sensor arrived.
//
// A mesh is built out of scene depth, which this device does not have, so no session reports one and
// the anchor is never handed to an application. The class is carried so the name resolves; its geometry
// is the one a session would have given it, which is none. The initialisers are the anchor's own. See
// facts/ARKit/SensorShells.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARMeshAnchor

@synthesize geometry = _geometry;

@end

NS_ASSUME_NONNULL_END
