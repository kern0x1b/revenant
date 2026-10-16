// ARFaceGeometry.m - the mesh of a face, at 11.0 beside ARFaceAnchor, which is the only thing that hands one out.
//
// The mesh is measured across a face by the TrueDepth camera. This device has no such camera, so the face
// configuration answers NO (ARConfiguration2.m) and no session reports an ARFaceAnchor, and no session makes
// one of these. The class is carried so the name resolves and its six members answer what a face mesh would
// have put in them, which is nothing. The initialiser that builds a mesh from blend shapes is not carried; see
// facts/ARKit/AbsentClasses.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARFaceGeometry

@synthesize vertexCount = _vertexCount;
@synthesize vertices = _vertices;
@synthesize textureCoordinateCount = _textureCoordinateCount;
@synthesize textureCoordinates = _textureCoordinates;
@synthesize triangleCount = _triangleCount;
@synthesize triangleIndices = _triangleIndices;

@end

NS_ASSUME_NONNULL_END
