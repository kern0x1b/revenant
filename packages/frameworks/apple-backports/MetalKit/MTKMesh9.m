#import <MetalKit/MetalKit.h>

static NSError *RevenantMTKMeshError(void)
{
    return [NSError errorWithDomain:MTKModelErrorDomain code:0
                            userInfo:@{NSLocalizedDescriptionKey: @"this port does not carry MDLMesh, so there is no Model I/O mesh to build an MTKMesh from"}];
}

@implementation MTKMesh
{
    NSArray<MTKMeshBuffer *> *_revenantVertexBuffers;
    MDLVertexDescriptor *_revenantVertexDescriptor;
    NSArray<MTKSubmesh *> *_revenantSubmeshes;
    NSUInteger _revenantVertexCount;
    NSString *_revenantName;
}

- (instancetype)initWithMesh:(MDLMesh *)mesh device:(id<MTLDevice>)device error:(NSError **)error
{
    if (error)
        *error = RevenantMTKMeshError();
    return nil;
}

+ (NSArray<MTKMesh *> *)newMeshesFromAsset:(MDLAsset *)asset device:(id<MTLDevice>)device sourceMeshes:(NSArray<MDLMesh *> **)sourceMeshes error:(NSError **)error
{
    if (error)
        *error = RevenantMTKMeshError();
    return nil;
}

- (NSArray<MTKMeshBuffer *> *)vertexBuffers
{
    return _revenantVertexBuffers ?: @[];
}

- (MDLVertexDescriptor *)vertexDescriptor
{
    return _revenantVertexDescriptor ?: [[MDLVertexDescriptor alloc] init];
}

- (NSArray<MTKSubmesh *> *)submeshes
{
    return _revenantSubmeshes ?: @[];
}

- (NSUInteger)vertexCount
{
    return _revenantVertexCount;
}

- (NSString *)name
{
    return _revenantName ?: @"";
}

- (void)setName:(NSString *)name
{
    _revenantName = [name copy];
}

@end
