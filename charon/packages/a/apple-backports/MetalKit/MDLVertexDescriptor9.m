#import <ModelIO/ModelIO.h>

// MDLVertexDescriptor, MDLVertexAttribute and MDLVertexBufferLayout are defined here, and this
// object references none of the fifteen MDLVertexAttribute* name constants: they are defined in
// ModelIO/MDLVertexAttributes9.m, and `nm -u` over this object finds no reference to any of them, so
// this library does not ask for them and does not need ModelIO's to be linked beside it. What this
// object does need is MetalKit's own, and backports.lua:45 declares them: MetalKitBackports links
// FoundationBackports and MetalBackports.


static NSUInteger CharonMDLComponentSize(MDLVertexFormat format)
{
    switch (format & 0xFF0000) {
        case MDLVertexFormatUCharBits:
        case MDLVertexFormatCharBits:
        case MDLVertexFormatUCharNormalizedBits:
        case MDLVertexFormatCharNormalizedBits:
            return 1;
        case MDLVertexFormatUShortBits:
        case MDLVertexFormatShortBits:
        case MDLVertexFormatUShortNormalizedBits:
        case MDLVertexFormatShortNormalizedBits:
        case MDLVertexFormatHalfBits:
            return 2;
        default:
            return 4;
    }
}

@implementation MDLVertexBufferLayout

- (instancetype)initWithStride:(NSUInteger)stride
{
    if ((self = [super init]))
        self.stride = stride;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[MDLVertexBufferLayout alloc] initWithStride:self.stride];
}

@end

@implementation MDLVertexAttribute

- (instancetype)init
{
    if ((self = [super init])) {
        self.name = @"";
        self.format = MDLVertexFormatInvalid;
        self.initializationValue = (vector_float4){0, 0, 0, 1};
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name format:(MDLVertexFormat)format offset:(NSUInteger)offset bufferIndex:(NSUInteger)bufferIndex
{
    if ((self = [self init])) {
        self.name = name;
        self.format = format;
        self.offset = offset;
        self.bufferIndex = bufferIndex;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MDLVertexAttribute *copy = [[MDLVertexAttribute alloc] initWithName:self.name format:self.format offset:self.offset bufferIndex:self.bufferIndex];
    copy.time = self.time;
    copy.initializationValue = self.initializationValue;
    return copy;
}

@end

@implementation MDLVertexDescriptor

- (instancetype)init
{
    if ((self = [super init])) {
        self.attributes = [NSMutableArray array];
        self.layouts = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithVertexDescriptor:(MDLVertexDescriptor *)vertexDescriptor
{
    if ((self = [self init])) {
        for (MDLVertexAttribute *attribute in vertexDescriptor.attributes)
            [self.attributes addObject:[attribute copy]];
        for (MDLVertexBufferLayout *layout in vertexDescriptor.layouts)
            [self.layouts addObject:[layout copy]];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[MDLVertexDescriptor alloc] initWithVertexDescriptor:self];
}

- (MDLVertexAttribute *)attributeNamed:(NSString *)name
{
    for (MDLVertexAttribute *attribute in self.attributes) {
        if ([attribute.name isEqualToString:name])
            return attribute;
    }
    return nil;
}

- (void)addOrReplaceAttribute:(MDLVertexAttribute *)attribute
{
    for (NSUInteger index = 0; index < self.attributes.count; index++) {
        MDLVertexAttribute *existing = self.attributes[index];
        if ([existing.name isEqualToString:attribute.name] && existing.time == attribute.time) {
            self.attributes[index] = attribute;
            return;
        }
    }
    [self.attributes addObject:attribute];
}

- (void)removeAttributeNamed:(NSString *)name
{
    NSIndexSet *doomed = [self.attributes indexesOfObjectsPassingTest:^BOOL(MDLVertexAttribute *attribute, NSUInteger index, BOOL *stop) {
        return [attribute.name isEqualToString:name];
    }];
    [self.attributes removeObjectsAtIndexes:doomed];
}

- (void)reset
{
    [self.attributes removeAllObjects];
    [self.layouts removeAllObjects];
}

- (void)setPackedStrides
{
    NSMutableDictionary<NSNumber *, NSNumber *> *strides = [NSMutableDictionary dictionary];
    for (MDLVertexAttribute *attribute in self.attributes) {
        if (attribute.format == MDLVertexFormatInvalid)
            continue;
        NSUInteger components = attribute.format & 0x1F;
        NSUInteger size = attribute.offset + CharonMDLComponentSize(attribute.format) * components;
        NSNumber *key = @(attribute.bufferIndex);
        strides[key] = @(MAX(strides[key].unsignedIntegerValue, size));
    }
    [strides enumerateKeysAndObjectsUsingBlock:^(NSNumber *bufferIndex, NSNumber *stride, BOOL *stop) {
        while (self.layouts.count <= bufferIndex.unsignedIntegerValue)
            [self.layouts addObject:[[MDLVertexBufferLayout alloc] initWithStride:0]];
        self.layouts[bufferIndex.unsignedIntegerValue].stride = stride.unsignedIntegerValue;
    }];
}

- (void)setPackedOffsets
{
    NSMutableDictionary<NSNumber *, NSNumber *> *offsets = [NSMutableDictionary dictionary];
    for (MDLVertexAttribute *attribute in self.attributes) {
        if (attribute.format == MDLVertexFormatInvalid)
            continue;
        NSNumber *key = @(attribute.bufferIndex);
        NSUInteger offset = offsets[key].unsignedIntegerValue;
        attribute.offset = offset;
        NSUInteger components = attribute.format & 0x1F;
        offsets[key] = @(offset + CharonMDLComponentSize(attribute.format) * components);
    }
}

@end
