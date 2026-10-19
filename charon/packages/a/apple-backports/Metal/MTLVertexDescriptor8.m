#import "CharonMetal.h"
#import <objc/runtime.h>

@implementation MTLVertexAttributeDescriptor

- (id)copyWithZone:(NSZone *)zone
{
    MTLVertexAttributeDescriptor *d = [[MTLVertexAttributeDescriptor alloc] init];
    d.format = self.format;
    d.offset = self.offset;
    d.bufferIndex = self.bufferIndex;
    return d;
}

@end

@implementation MTLVertexBufferLayoutDescriptor

- (instancetype)init
{
    if ((self = [super init])) {
        self.stepFunction = MTLVertexStepFunctionPerVertex;
        self.stepRate = 1;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLVertexBufferLayoutDescriptor *d = [[MTLVertexBufferLayoutDescriptor alloc] init];
    d.stride = self.stride;
    d.stepFunction = self.stepFunction;
    d.stepRate = self.stepRate;
    return d;
}

@end

@implementation MTLVertexAttributeDescriptorArray {
    NSMutableArray *_items;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _items = [NSMutableArray array];
        for (int i = 0; i < 31; i++)
            [_items addObject:[[MTLVertexAttributeDescriptor alloc] init]];
    }
    return self;
}

- (MTLVertexAttributeDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    return _items[index];
}

- (void)setObject:(MTLVertexAttributeDescriptor *)attributeDesc atIndexedSubscript:(NSUInteger)index
{
    _items[index] = [attributeDesc copy];
}

@end

@implementation MTLVertexBufferLayoutDescriptorArray {
    NSMutableArray *_items;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _items = [NSMutableArray array];
        for (int i = 0; i < 31; i++)
            [_items addObject:[[MTLVertexBufferLayoutDescriptor alloc] init]];
    }
    return self;
}

- (MTLVertexBufferLayoutDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    return _items[index];
}

- (void)setObject:(MTLVertexBufferLayoutDescriptor *)bufferDesc atIndexedSubscript:(NSUInteger)index
{
    _items[index] = [bufferDesc copy];
}

@end

@implementation MTLVertexDescriptor {
    MTLVertexAttributeDescriptorArray *_attributes;
    MTLVertexBufferLayoutDescriptorArray *_layouts;
}

+ (MTLVertexDescriptor *)vertexDescriptor
{
    return [[MTLVertexDescriptor alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _attributes = [[MTLVertexAttributeDescriptorArray alloc] init];
        _layouts = [[MTLVertexBufferLayoutDescriptorArray alloc] init];
    }
    return self;
}

- (MTLVertexAttributeDescriptorArray *)attributes
{
    return _attributes;
}

- (MTLVertexBufferLayoutDescriptorArray *)layouts
{
    return _layouts;
}

- (void)reset
{
    _attributes = [[MTLVertexAttributeDescriptorArray alloc] init];
    _layouts = [[MTLVertexBufferLayoutDescriptorArray alloc] init];
}

// VALUE EQUALITY, and it is here because of what it makes possible two releases away: Apple's own
// MTL4RenderPipelineDescriptor compares its vertexDescriptor, and Apple's own MTLVertexDescriptor has
// value equality - measured, two freshly made ones are equal - so a Metal 4 render pipeline descriptor
// can compare equal against a fresh one. Without this, two fresh render descriptors on this port are
// not equal where Apple's are, and the difference is this class's.
//
// It compares the two ARRAYS ELEMENT BY ELEMENT through their own getters, member by member, rather
// than asking the arrays whether they are equal: the two array classes are the SDK's PROTOCOLS here
// (their instances are objects Apple's own framework makes) and carry no -isEqual: of their own, so
// there is nothing to ask. The bound is THIRTY ONE, which is what -copyWithZone: above walks and what
// MTLVertexDescriptor.h's own table has rows for.
- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTLVertexDescriptor class]]) return NO;
    MTLVertexDescriptor *other = object;
    for (int index = 0; index < 31; index++) {
        MTLVertexAttributeDescriptor *mine = self.attributes[index];
        MTLVertexAttributeDescriptor *theirs = other.attributes[index];
        if (mine.format != theirs.format || mine.offset != theirs.offset || mine.bufferIndex != theirs.bufferIndex)
            return NO;
        MTLVertexBufferLayoutDescriptor *myLayout = self.layouts[index];
        MTLVertexBufferLayoutDescriptor *theirLayout = other.layouts[index];
        if (myLayout.stride != theirLayout.stride || myLayout.stepFunction != theirLayout.stepFunction ||
            myLayout.stepRate != theirLayout.stepRate)
            return NO;
    }
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    for (int index = 0; index < 31; index++) {
        MTLVertexAttributeDescriptor *attribute = self.attributes[index];
        hash = hash * 31u + (uint32_t)attribute.format + (uint32_t)attribute.offset + (uint32_t)attribute.bufferIndex;
        MTLVertexBufferLayoutDescriptor *layout = self.layouts[index];
        hash = hash * 31u + (uint32_t)layout.stride + (uint32_t)layout.stepFunction + (uint32_t)layout.stepRate;
    }
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLVertexDescriptor *d = [[MTLVertexDescriptor alloc] init];
    for (int i = 0; i < 31; i++) {
        d.attributes[i] = self.attributes[i];
        d.layouts[i] = self.layouts[i];
    }
    return d;
}

@end
