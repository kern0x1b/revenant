// ARSCNPlaneGeometry.m - a plane's geometry in SceneKit's form, at 12.0 where ARPlaneGeometry is.
//
// `ARPlaneGeometry` is a 12.0 class and this takes one, so this object carries 12.0's API and nothing
// older. The geometry is the four corners and the six indices the framework already declares as C
// buffers in `ARPlaneGeometry`; what SceneKit wants is a geometry source over those corners and a
// geometry element over those indices, so this is the one class in the family that is arithmetic
// rather than a forward, and it is a copy into the element layout SceneKit takes.

#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>
#import <simd/simd.h>

#import "../SceneKit/CharonSCN.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARSCNPlaneGeometry () {
    /// The buffers the sources read. A geometry source is handed data it does not copy, so whatever
    /// the sources point at has to live as long as they do, and an ivar is what holds it - the
    /// framework's class is declared in the SDK's header, not here, so this cannot be a property.
    NSArray<NSData *> *_retainedSources;
}
@end

@implementation ARSCNPlaneGeometry


+ (nullable instancetype)planeGeometryWithDevice:(id<MTLDevice>)device
{
    // The device is the Metal device SceneKit draws with, and a caller that has none is asking for
    // geometry nothing can render; nil is what the framework answers and what is returned here.
    if (!device)
        return nil;
    return [self geometryWithSources:@[] elements:@[]];
}

- (void)updateFromPlaneGeometry:(ARPlaneGeometry *)planeGeometry
{
    NSUInteger vertexCount = planeGeometry.vertexCount;
    NSUInteger triangleCount = planeGeometry.triangleCount;
    if (vertexCount == 0 || triangleCount == 0)
        return;

    // The plane's own vertex buffer, read in place. The vertices are three floats each, and the
    // texture coordinates are three floats a corner too, which is the second source.
    NSMutableData *positions = [NSMutableData dataWithLength:vertexCount * 3 * sizeof(float)];
    float *out = positions.mutableBytes;
    const simd_float3 *corners = planeGeometry.vertices;
    for (NSUInteger i = 0; i < vertexCount; i++) {
        out[i * 3 + 0] = corners[i].x;
        out[i * 3 + 1] = corners[i].y;
        out[i * 3 + 2] = corners[i].z;
    }
    const simd_float2 *coordinates = planeGeometry.textureCoordinates;
    NSMutableData *uvs = [NSMutableData dataWithLength:vertexCount * 2 * sizeof(float)];
    float *uvOut = uvs.mutableBytes;
    for (NSUInteger i = 0; i < vertexCount; i++) {
        uvOut[i * 2 + 0] = coordinates[i].x;
        uvOut[i * 2 + 1] = coordinates[i].y;
    }

    SCNGeometrySource *positionsSource =
            [SCNGeometrySource geometrySourceWithData:positions
                                             semantic:SCNGeometrySourceSemanticVertex
                                          vectorCount:(NSInteger)vertexCount
                                       floatComponents:YES
                                    componentsPerVector:3
                                   bytesPerComponent:(NSInteger)sizeof(float)
                                          dataOffset:0
                                           dataStride:(NSInteger)(3 * sizeof(float))];
    SCNGeometrySource *textureSource =
            [SCNGeometrySource geometrySourceWithData:uvs
                                             semantic:SCNGeometrySourceSemanticTexcoord
                                          vectorCount:(NSInteger)vertexCount
                                       floatComponents:YES
                                    componentsPerVector:2
                                   bytesPerComponent:(NSInteger)sizeof(float)
                                          dataOffset:0
                                           dataStride:(NSInteger)(2 * sizeof(float))];

    // The index buffer, copied into the int16 layout SceneKit's element takes.
    NSMutableData *indices = [NSMutableData dataWithLength:triangleCount * sizeof(int)];
    int *indexOut = indices.mutableBytes;
    const int16_t *planeIndices = planeGeometry.triangleIndices;
    for (NSUInteger i = 0; i < triangleCount; i++)
        indexOut[i] = planeIndices[i];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:indices
                                                                  primitiveType:SCNGeometryPrimitiveTypeTriangles
                                                                 primitiveCount:(NSInteger)(triangleCount / 3)
                                                                  bytesPerIndex:(NSInteger)sizeof(int)];

    // `geometrySources` and `geometryElements` are readonly (SCNGeometry.h:121 and :135) and the only
    // public way into a geometry is +geometryWithSources:elements:, which returns a new object - so
    // an in-place update goes through the port's own package-internal method, declared in
    // CharonSCN.h and in no public header. Nothing private is reached: the class is implemented here.
    //
    // The buffers are kept for as long as the geometry is, because a source is handed data it does
    // not copy.
    _retainedSources = @[ positions, uvs ];
    [self charon_replaceSources:@[ positionsSource, textureSource ] elements:@[ element ]];
}

@end

NS_ASSUME_NONNULL_END
