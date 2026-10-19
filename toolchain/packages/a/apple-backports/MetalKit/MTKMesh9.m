#import <MetalKit/MetalKit.h>

static NSError *CharonMTKMeshError(void)
{
    return [NSError errorWithDomain:MTKModelErrorDomain code:0
                            userInfo:@{NSLocalizedDescriptionKey: @"this port does not carry MDLMesh, so there is no Model I/O mesh to build an MTKMesh from"}];
}

@implementation MTKMesh
{
    NSArray<MTKMeshBuffer *> *_charonVertexBuffers;
    MDLVertexDescriptor *_charonVertexDescriptor;
    NSArray<MTKSubmesh *> *_charonSubmeshes;
    NSUInteger _charonVertexCount;
    NSString *_charonName;
}

- (instancetype)initWithMesh:(MDLMesh *)mesh device:(id<MTLDevice>)device error:(NSError **)error
{
    if (error)
        *error = CharonMTKMeshError();
    return nil;
}

+ (NSArray<MTKMesh *> *)newMeshesFromAsset:(MDLAsset *)asset device:(id<MTLDevice>)device sourceMeshes:(NSArray<MDLMesh *> **)sourceMeshes error:(NSError **)error
{
    if (error)
        *error = CharonMTKMeshError();
    return nil;
}

- (NSArray<MTKMeshBuffer *> *)vertexBuffers
{
    return _charonVertexBuffers ?: @[];
}

- (MDLVertexDescriptor *)vertexDescriptor
{
    return _charonVertexDescriptor ?: [[MDLVertexDescriptor alloc] init];
}

- (NSArray<MTKSubmesh *> *)submeshes
{
    return _charonSubmeshes ?: @[];
}

- (NSUInteger)vertexCount
{
    return _charonVertexCount;
}

- (NSString *)name
{
    return _charonName ?: @"";
}

- (void)setName:(NSString *)name
{
    _charonName = [name copy];
}

@end
