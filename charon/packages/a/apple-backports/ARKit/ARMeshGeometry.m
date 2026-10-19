// ARMeshGeometry.m - the mesh of the scene, at 13.4 where the scene reconstruction of a depth sensor arrived.
//
// A scene mesh is reconstructed out of scene depth, and this device has no depth sensor, so no session
// produces one; ARMeshAnchor.m says the same of its anchor. The class is carried so the name resolves, and its
// four members (vertices, normals, faces, classification) answer what a mesh would have put in them, which is
// nothing. facts/ARKit/AbsentClasses.md has the reason and what is not carried.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARMeshGeometry

@synthesize vertices = _vertices;
@synthesize normals = _normals;
@synthesize faces = _faces;
@synthesize classification = _classification;

@end

NS_ASSUME_NONNULL_END
