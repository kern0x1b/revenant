// MPSState, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static inline NSUInteger CharonMPSResourceLength(id<MTLResource> resource)
{
    if ([resource conformsToProtocol:@protocol(MTLBuffer)])
        return [(id<MTLBuffer>)resource length];
    if ([resource conformsToProtocol:@protocol(MTLTexture)]) {
        id<MTLTexture> texture = (id<MTLTexture>)resource;
        return texture.width * texture.height * (texture.depth ? texture.depth : 1) * 4;
    }
    return 0;
}
@implementation MPSState {
    NSMutableArray *_resources;
    NSMutableArray *_types;
    NSMutableArray *_sizes;
    NSMutableArray *_textures;
    NSUInteger _readCount;
    BOOL _temporary;
    NSString *_label;
    id<MTLDevice> _device;
}

@synthesize label;

- (instancetype)initWithResource:(id<MTLResource>)resource
{
    if ((self = [super init])) {
        _resources = [NSMutableArray array];
        _types = [NSMutableArray array];
        _sizes = [NSMutableArray array];
        _textures = [NSMutableArray array];
        _readCount = 1;
        if (resource)
            [self charon_mps_appendResource:resource];
    }
    return self;
}

- (instancetype)initWithResources:(NSArray<id<MTLResource>> *)resources
{
    if ((self = [super init])) {
        _resources = [NSMutableArray array];
        _types = [NSMutableArray array];
        _sizes = [NSMutableArray array];
        _textures = [NSMutableArray array];
        _readCount = 1;
        for (id<MTLResource> resource in resources)
            [self charon_mps_appendResource:resource];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device bufferSize:(size_t)bufferSize
{
    if ((self = [super init])) {
        _resources = [NSMutableArray array];
        _types = [NSMutableArray array];
        _sizes = [NSMutableArray array];
        _textures = [NSMutableArray array];
        _readCount = 1;
        _device = device;
        [self charon_mps_appendBuffer:bufferSize];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device textureDescriptor:(MTLTextureDescriptor *)descriptor
{
    if ((self = [super init])) {
        _resources = [NSMutableArray array];
        _types = [NSMutableArray array];
        _sizes = [NSMutableArray array];
        _textures = [NSMutableArray array];
        _readCount = 1;
        _device = device;
        [self charon_mps_appendTexture:descriptor];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device resourceList:(MPSStateResourceList *)resourceList
{
    if ((self = [super init])) {
        _resources = [NSMutableArray array];
        _types = [NSMutableArray array];
        _sizes = [NSMutableArray array];
        _textures = [NSMutableArray array];
        _readCount = 1;
        _device = device;
        for (NSNumber *size in [resourceList charon_mps_bufferSizes])
            [self charon_mps_appendBuffer:[size unsignedIntegerValue]];
        for (MTLTextureDescriptor *descriptor in [resourceList charon_mps_textureDescriptors])
            [self charon_mps_appendTexture:descriptor];
    }
    return self;
}

- (instancetype)init
{
    // The header marks -init unavailable: a state without a resource is not a state a kernel can
    // read or write, and MPSStateResourceList is how a caller says what it should hold. A caller
    // that reaches -init anyway is told so in the log and given nothing, rather than an object that
    // answers every question about its storage with zero.
    NSLog(@"MPSState: -init makes a state with no storage; use -initWithResource:, -initWithResources:, -initWithDevice:bufferSize:, -initWithDevice:textureDescriptor: or -initWithDevice:resourceList:");
    return nil;
}

+ (instancetype)temporaryStateWithCommandBuffer:(id<MTLCommandBuffer>)cmdBuf bufferSize:(size_t)bufferSize
{
    return [self charon_mps_temporaryWithBlock:^MPSState *(id<MTLDevice> device) {
        return [[self alloc] initWithDevice:device bufferSize:bufferSize];
    } commandBuffer:cmdBuf];
}

+ (instancetype)temporaryStateWithCommandBuffer:(id<MTLCommandBuffer>)cmdBuf textureDescriptor:(MTLTextureDescriptor *)descriptor
{
    return [self charon_mps_temporaryWithBlock:^MPSState *(id<MTLDevice> device) {
        return [[self alloc] initWithDevice:device textureDescriptor:descriptor];
    } commandBuffer:cmdBuf];
}

+ (instancetype)temporaryStateWithCommandBuffer:(id<MTLCommandBuffer>)cmdBuf resourceList:(MPSStateResourceList *)resourceList
{
    return [self charon_mps_temporaryWithBlock:^MPSState *(id<MTLDevice> device) {
        return [[self alloc] initWithDevice:device resourceList:resourceList];
    } commandBuffer:cmdBuf];
}

+ (instancetype)temporaryStateWithCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
{
    return [self charon_mps_temporaryWithBlock:^MPSState *(id<MTLDevice> device) {
        return [[self alloc] initWithDevice:device bufferSize:0];
    } commandBuffer:cmdBuf];
}

// A temporary state is one the release takes from its own heap and reuses for the next kernel that
// wants the same shape. This port has no MPS heap, so the state is an ordinary state marked
// temporary: its storage is a device buffer made when -resourceAtIndex:allocateMemory: is asked for
// it, which is the same storage the release's sub-allocation would have been, and -readCount is the
// count the release's is. Nothing is returned to a cache, so nothing is invalidated by a read count
// reaching zero; facts/MetalPerformanceShaders/State.md says so.
+ (instancetype)charon_mps_temporaryWithBlock:(MPSState *(^)(id<MTLDevice>))block commandBuffer:(id<MTLCommandBuffer>)cmdBuf
{
    id<MTLDevice> device = [cmdBuf respondsToSelector:@selector(device)] ? [cmdBuf device] : MTLCreateSystemDefaultDevice();
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    MPSState *state = block(device);
    if (state)
        state->_temporary = YES;
    return state;
}

- (void)charon_mps_appendBuffer:(size_t)size
{
    [_sizes addObject:[NSNumber numberWithUnsignedInteger:size]];
    [_types addObject:[NSNumber numberWithUnsignedInteger:MPSStateResourceTypeBuffer]];
    [_resources addObject:[NSNull null]];
    [_textures addObject:[NSNull null]];
}

- (void)charon_mps_appendTexture:(MTLTextureDescriptor *)descriptor
{
    [_textures addObject:descriptor];
    [_types addObject:[NSNumber numberWithUnsignedInteger:MPSStateResourceTypeTexture]];
    [_resources addObject:[NSNull null]];
    [_sizes addObject:[NSNumber numberWithUnsignedInteger:0]];
}

- (void)charon_mps_appendResource:(id<MTLResource>)resource
{
    [_resources addObject:resource];
    if ([resource conformsToProtocol:@protocol(MTLTexture)]) {
        [_types addObject:[NSNumber numberWithUnsignedInteger:MPSStateResourceTypeTexture]];
        [_textures addObject:[NSNull null]];
        [_sizes addObject:[NSNumber numberWithUnsignedInteger:0]];
    } else {
        [_types addObject:[NSNumber numberWithUnsignedInteger:MPSStateResourceTypeBuffer]];
        [_textures addObject:[NSNull null]];
        [_sizes addObject:[NSNumber numberWithUnsignedInteger:CharonMPSResourceLength(resource)]];
    }
}

- (NSUInteger)resourceCount
{
    return _resources.count;
}

- (MPSStateResourceType)resourceTypeAtIndex:(NSUInteger)index
{
    if (index >= _types.count)
        return MPSStateResourceTypeNone;
    return (MPSStateResourceType)[[_types objectAtIndex:index] unsignedIntegerValue];
}

- (id<MTLResource>)resourceAtIndex:(NSUInteger)index allocateMemory:(BOOL)allocateMemory
{
    if (index >= _resources.count)
        return nil;
    id object = [_resources objectAtIndex:index];
    if (object != (id)[NSNull null])
        return object;
    // The storage a state was described with but not given. The release draws it from its heap; this
    // port draws it from the device, which is where the heap's own storage comes from, and only when
    // the caller asks for it with allocateMemory:YES or through -resource.
    id<MTLDevice> device = _device;
    if (!device)
        device = MTLCreateSystemDefaultDevice();
    if (!allocateMemory)
        return nil;
    id<MTLResource> made = nil;
    if ([self resourceTypeAtIndex:index] == MPSStateResourceTypeBuffer) {
        size_t size = [[_sizes objectAtIndex:index] unsignedIntegerValue];
        made = [device newBufferWithLength:size options:MTLResourceStorageModeShared];
    } else {
        MTLTextureDescriptor *descriptor = [_textures objectAtIndex:index];
        made = descriptor ? [device newTextureWithDescriptor:descriptor] : nil;
    }
    if (made)
        [_resources replaceObjectAtIndex:index withObject:made];
    return made;
}

- (id<MTLResource>)resource
{
    if (_resources.count != 1) {
        // The release deprecated -resource for exactly this reason and points at
        // -resourceAtIndex:allocateMemory:. A state of any other shape has no single resource, and
        // the release's own would not have had one either.
        return nil;
    }
    return [self resourceAtIndex:0 allocateMemory:YES];
}

- (NSUInteger)bufferSizeAtIndex:(NSUInteger)index
{
    if (index >= _sizes.count)
        return 0;
    return [[_sizes objectAtIndex:index] unsignedIntegerValue];
}

- (MPSStateTextureInfo)textureInfoAtIndex:(NSUInteger)index
{
    MPSStateTextureInfo info;
    memset(&info, 0, sizeof(info));
    if (index >= _textures.count)
        return info;
    id object = [_textures objectAtIndex:index];
    if (object == (id)[NSNull null])
        return info;
    MTLTextureDescriptor *descriptor = object;
    info.width = descriptor.width;
    info.height = descriptor.height;
    info.depth = descriptor.depth;
    info.arrayLength = descriptor.arrayLength;
    info.pixelFormat = descriptor.pixelFormat;
    info.textureType = descriptor.textureType;
    info.usage = descriptor.usage;
    return info;
}

- (NSUInteger)resourceSize
{
    NSUInteger total = 0;
    for (NSUInteger index = 0; index < _resources.count; index++) {
        if ([self resourceTypeAtIndex:index] == MPSStateResourceTypeBuffer) {
            total += [self bufferSizeAtIndex:index];
        } else {
            MPSStateTextureInfo info = [self textureInfoAtIndex:index];
            id<MTLResource> resource = [_resources objectAtIndex:index];
            if (resource != (id)[NSNull null])
                total += CharonMPSResourceLength(resource);
            else
                total += info.width * info.height * (info.depth ? info.depth : 1) * 4;
        }
    }
    return total;
}

- (void)synchronizeOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    // Every resource of this port is host memory the CPU and the device share, so there is no cache
    // to flush and nothing to wait for. The release flushes a managed buffer here; this port has no
    // managed resource, which is the same answer.
    (void)commandBuffer;
}

- (NSUInteger)readCount
{
    return _readCount;
}

- (void)setReadCount:(NSUInteger)readCount
{
    _readCount = readCount;
}

- (BOOL)isTemporary
{
    return _temporary;
}

- (NSString *)label
{
    return _label;
}

- (void)setLabel:(NSString *)name
{
    _label = [name copy];
}

@end
