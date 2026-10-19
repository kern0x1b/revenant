#import <ModelIO/ModelIO.h>

// MDLMeshBufferMap, which MTKMeshBuffer's -map hands out and which the release does not have: ModelIO
// arrived in iOS 9.0. It is carried here for the same reason MDLVertexDescriptor is
// (MDLVertexDescriptor9.m): MetalKit's own objects name it, so a library that carries MetalKit must
// carry the class. The contract is the header's: a reference to memory of a mapped buffer, made by the
// buffer's implementor with the bytes and a block that unmaps on deallocation.

@implementation MDLMeshBufferMap {
    void *_bytes;
    void (^_deallocator)(void);
}

@synthesize bytes = _bytes;

- (instancetype)initWithBytes:(void *)bytes deallocator:(void (^)(void))deallocator
{
    if ((self = [super init])) {
        _bytes = bytes;
        _deallocator = [deallocator copy];
    }
    return self;
}

- (void)dealloc
{
    if (_deallocator)
        _deallocator();
}

@end
