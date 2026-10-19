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
