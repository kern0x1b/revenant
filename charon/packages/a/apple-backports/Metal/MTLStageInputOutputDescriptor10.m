#import "CharonMetal.h"


@implementation MTLBufferLayoutDescriptor

- (id)copyWithZone:(NSZone *)zone
{
    MTLBufferLayoutDescriptor *copy = [[MTLBufferLayoutDescriptor alloc] init];
    copy.stride = self.stride;
    copy.stepFunction = self.stepFunction;
    copy.stepRate = self.stepRate;
    return copy;
}

@end

@implementation MTLBufferLayoutDescriptorArray
{
    NSMutableDictionary<NSNumber *, MTLBufferLayoutDescriptor *> *_entries;
}

- (instancetype)init
{
    if ((self = [super init]))
        _entries = [NSMutableDictionary dictionary];
    return self;
}

- (MTLBufferLayoutDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    return _entries[@(index)] ?: [[MTLBufferLayoutDescriptor alloc] init];
}

- (void)setObject:(MTLBufferLayoutDescriptor *)bufferDesc atIndexedSubscript:(NSUInteger)index
{
    if (bufferDesc)
        _entries[@(index)] = [bufferDesc copy];
    else
        [_entries removeObjectForKey:@(index)];
}

@end

@implementation MTLAttributeDescriptor

- (id)copyWithZone:(NSZone *)zone
{
    MTLAttributeDescriptor *copy = [[MTLAttributeDescriptor alloc] init];
    copy.format = self.format;
    copy.offset = self.offset;
    copy.bufferIndex = self.bufferIndex;
    return copy;
}

@end

@implementation MTLAttributeDescriptorArray
{
    NSMutableDictionary<NSNumber *, MTLAttributeDescriptor *> *_entries;
}

- (instancetype)init
{
    if ((self = [super init]))
        _entries = [NSMutableDictionary dictionary];
    return self;
}

- (MTLAttributeDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    return _entries[@(index)] ?: [[MTLAttributeDescriptor alloc] init];
}

- (void)setObject:(MTLAttributeDescriptor *)attributeDesc atIndexedSubscript:(NSUInteger)index
{
    if (attributeDesc)
        _entries[@(index)] = [attributeDesc copy];
    else
        [_entries removeObjectForKey:@(index)];
}

@end

@implementation MTLStageInputOutputDescriptor

+ (MTLStageInputOutputDescriptor *)stageInputOutputDescriptor
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _layouts = [[MTLBufferLayoutDescriptorArray alloc] init];
        _attributes = [[MTLAttributeDescriptorArray alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLStageInputOutputDescriptor *copy = [[MTLStageInputOutputDescriptor alloc] init];
    for (NSUInteger index = 0; index < 31; index++) {
        copy.layouts[index] = self.layouts[index];
        copy.attributes[index] = self.attributes[index];
    }
    copy.indexType = self.indexType;
    copy.indexBufferIndex = self.indexBufferIndex;
    return copy;
}

- (void)reset
{
    _layouts = [[MTLBufferLayoutDescriptorArray alloc] init];
    _attributes = [[MTLAttributeDescriptorArray alloc] init];
    self.indexType = MTLIndexTypeUInt16;
    self.indexBufferIndex = 0;
}

@end
