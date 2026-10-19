// ARGeometrySource.m - one attribute of a scene mesh's geometry, at 13.4 with the mesh it belongs to.
//
// A source describes a buffer of vertices, normals or classifications that a scene mesh owns. No scene mesh is
// made on this device (ARMeshGeometry.m), so no source is handed out. The six members are the synthesised
// accessors of the SDK's own properties, and answer nothing. facts/ARKit/AbsentClasses.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARGeometrySource

@synthesize buffer = _buffer;
@synthesize count = _count;
@synthesize format = _format;
@synthesize componentsPerVector = _componentsPerVector;
@synthesize offset = _offset;
@synthesize stride = _stride;

@end

NS_ASSUME_NONNULL_END
