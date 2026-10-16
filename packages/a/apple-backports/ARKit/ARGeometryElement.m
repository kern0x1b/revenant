// ARGeometryElement.m - the index buffer of a scene mesh's faces, at 13.4 with the mesh it belongs to.
//
// An element is the list of primitives a scene mesh is drawn with. No scene mesh is made on this device
// (ARMeshGeometry.m), so no element is handed out. Its count of indices per primitive is not stored: the release
// derives it from the primitive type, and the host gives 2 for a line (type 0, the type of a fresh element) and 3 for
// a triangle (type 1), measured by setting the type through key-value coding and reading the getter
// (facts/ARKit/AbsentClasses.md). The other members are the synthesised accessors of the SDK's properties.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARGeometryElement

@synthesize buffer = _buffer;
@synthesize count = _count;
@synthesize bytesPerIndex = _bytesPerIndex;
@synthesize primitiveType = _primitiveType;

- (NSInteger)indexCountPerPrimitive
{
    switch (_primitiveType) {
        case ARGeometryPrimitiveTypeLine: return 2;
        case ARGeometryPrimitiveTypeTriangle: return 3;
    }
    // The type is read-only and only the framework sets it, so a value the enum does not name is not reachable
    // from a caller; the release's answer for one was not measured.
    return 0;
}

@end

NS_ASSUME_NONNULL_END
