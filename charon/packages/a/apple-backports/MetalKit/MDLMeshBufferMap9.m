#import <ModelIO/ModelIO.h>

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
