#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>
#import <simd/simd.h>

#import "../SceneKit/RevenantSCN.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARSCNPlaneGeometry () {
    NSArray<NSData *> *_retainedSources;
}
@end

@implementation ARSCNPlaneGeometry


+ (nullable instancetype)planeGeometryWithDevice:(id<MTLDevice>)device
{
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

    NSMutableData *indices = [NSMutableData dataWithLength:triangleCount * sizeof(int)];
    int *indexOut = indices.mutableBytes;
    const int16_t *planeIndices = planeGeometry.triangleIndices;
    for (NSUInteger i = 0; i < triangleCount; i++)
        indexOut[i] = planeIndices[i];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:indices
                                                                  primitiveType:SCNGeometryPrimitiveTypeTriangles
                                                                 primitiveCount:(NSInteger)(triangleCount / 3)
                                                                  bytesPerIndex:(NSInteger)sizeof(int)];

    _retainedSources = @[ positions, uvs ];
    [self revenant_replaceSources:@[ positionsSource, textureSource ] elements:@[ element ]];
}

@end

NS_ASSUME_NONNULL_END
