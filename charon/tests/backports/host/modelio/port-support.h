// The two places where the iOS header the port is written against and the macOS header the system's
// ModelIO comes from disagree, declared so the port's own spelling can be asked. Both are the iOS
// spelling, which is the one the port carries.
#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

@interface MDLMesh (CharonProbePlane)
+ (instancetype)newPlaneWithDimensions:(vector_float2)dimensions
                              segments:(vector_uint2)segments
                          geometryType:(MDLGeometryType)geometryType
                         inwardNormals:(BOOL)inwardNormals
                             allocator:(id<MDLMeshBufferAllocator>)allocator;
@end

@interface MDLTexture (CharonProbeTexture)
- (instancetype)initWithData:(NSData *)pixelData
               topLeftOrigin:(BOOL)topLeftOrigin
                        name:(NSString *)name
                  dimensions:(vector_int2)dimensions
                   rowStride:(NSInteger)rowStride
                channelCount:(NSUInteger)channelCount
             channelEncoding:(MDLTextureChannelEncoding)channelEncoding;
@end
