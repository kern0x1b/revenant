// What ModelIO itself exports that a release without it does not: the three vertex-attribute names
// the port's own meshes and readers use, and the protocol objects those names and the header's
// conformances are looked up by. On a release that has ModelIO the framework supplies both; on one
// that does not, the port has to - this file is the probe's copy of that, so the port process can be
// linked without the system framework. A line here marked TODO belongs in the port itself.
#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>

NSString *const MDLVertexAttributePosition = @"position";
NSString *const MDLVertexAttributeNormal = @"normal";
NSString *const MDLVertexAttributeTextureCoordinate = @"texcoord";
NSString *const MDLVertexAttributeTangent = @"tangent";
NSString *const MDLVertexAttributeBitangent = @"bitangent";
NSString *const MDLVertexAttributeColor = @"color";
NSString *const MDLVertexAttributeJointIndices = @"jointIndices";
NSString *const MDLVertexAttributeJointWeights = @"jointWeights";
NSString *const MDLVertexAttributeOcclusionValue = @"occlusionValue";
NSString *const MDLVertexAttributeEdgeCrease = @"edgeCrease";
NSString *const MDLVertexAttributeAnisotropy = @"anisotropy";
NSString *const MDLVertexAttributeBinormal = @"binormal";
NSString *const MDLVertexAttributeShadingBasisU = @"shadingBasisU";
NSString *const MDLVertexAttributeShadingBasisV = @"shadingBasisV";
NSString *const MDLVertexAttributeSubdivisionStencil = @"subdivisionStencil";

// The protocols of MDLTypes.h, restated so the probe's own objects have protocol objects to conform
// to and compare with when the framework is not in the process.
@protocol MDLComponent <NSObject>
@end

@protocol MDLNamed <NSObject>
@required
@property (nonatomic, copy) NSString *name;
@end

@protocol MDLObjectContainerComponent <MDLComponent, NSFastEnumeration>
- (void)addObject:(id)object;
- (void)removeObject:(id)object;
- (id)objectAtIndexedSubscript:(NSUInteger)index;
@property (readonly) NSUInteger count;
@property (nonatomic, readonly, retain) NSArray *objects;
@end

@protocol MDLTransformComponent <MDLComponent>
@required
@property (nonatomic, assign) matrix_float4x4 matrix;
@property (nonatomic, assign) BOOL resetsTransform;
@property (nonatomic, readonly) NSTimeInterval minimumTime;
@property (nonatomic, readonly) NSTimeInterval maximumTime;
@property (nonatomic, readonly, copy) NSArray<NSNumber *> *keyTimes;
@optional
- (void)setLocalTransform:(matrix_float4x4)transform forTime:(NSTimeInterval)time;
- (void)setLocalTransform:(matrix_float4x4)transform;
- (matrix_float4x4)localTransformAtTime:(NSTimeInterval)time;
+ (matrix_float4x4)globalTransformWithObject:(id)object atTime:(NSTimeInterval)time;
@end

@protocol MDLAssetResolver <NSObject>
- (BOOL)canResolveAssetNamed:(NSString *)name;
- (NSURL *)resolveAssetNamed:(NSString *)name;
@end

@protocol MDLMeshBuffer <NSObject, NSCopying>
- (void)fillData:(NSData *)data offset:(NSUInteger)offset;
- (id)map;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly, retain) id allocator;
@property (nonatomic, readonly, retain) id zone;
@property (nonatomic, readonly) NSUInteger type;
@end

@protocol MDLMeshBufferZone <NSObject>
@property (nonatomic, readonly) NSUInteger capacity;
@property (nonatomic, readonly) id allocator;
@end

@protocol MDLMeshBufferAllocator <NSObject>
- (id)newZone:(NSUInteger)capacity;
- (id)newZoneForBuffersWithSize:(NSArray<NSNumber *> *)sizes andType:(NSArray<NSNumber *> *)types;
- (id)newBuffer:(NSUInteger)length type:(NSUInteger)type;
- (id)newBufferWithData:(NSData *)data type:(NSUInteger)type;
- (id)newBufferFromZone:(id)zone length:(NSUInteger)length type:(NSUInteger)type;
- (id)newBufferFromZone:(id)zone data:(NSData *)data type:(NSUInteger)type;
@end
