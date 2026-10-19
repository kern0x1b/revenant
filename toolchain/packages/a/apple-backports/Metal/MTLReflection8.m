#import "CharonMetal.h"
#import "MTLTypeReflectionInternal.h"

#include <stdlib.h>

@implementation MTLVertexAttribute

{
    NSDictionary *_node;
}

- (instancetype)initWithNode:(NSDictionary *)node
{
    if ((self = [super init]))
        _node = [node isKindOfClass:[NSDictionary class]] ? node : @{};
    return self;
}

- (NSString *)name
{
    return _node[@"name"] ?: @"";
}

- (NSUInteger)attributeIndex
{
    return [_node[@"index"] unsignedIntegerValue];
}

- (MTLDataType)attributeType
{
    return CharonDataTypeFromScalar(_node[@"scalar"]);
}

- (BOOL)isActive
{
    return YES;
}

- (BOOL)isPatchData
{
    return NO;
}

- (BOOL)isPatchControlPointData
{
    return NO;
}

- (BOOL)isPatchControlPointData1
{
    return NO;
}

@end

@implementation MTLRenderPipelineReflection

{
    NSArray *_bindings;
    NSArray *_arguments;
}

- (instancetype)initWithArguments:(NSArray *)arguments
{
    if ((self = [super init])) {
        _arguments = arguments ?: @[];
        _bindings = @[];
    }
    return self;
}

- (NSArray<id<MTLBinding>> *)vertexBindings
{
    return _bindings;
}

- (NSArray<id<MTLBinding>> *)fragmentBindings
{
    return _bindings;
}

- (NSArray<id<MTLBinding>> *)tileBindings
{
    return _bindings;
}

- (NSArray<id<MTLBinding>> *)objectBindings
{
    return _bindings;
}

- (NSArray<id<MTLBinding>> *)meshBindings
{
    return _bindings;
}

- (NSArray<MTLArgument *> *)vertexArguments
{
    return _arguments;
}

- (NSArray<MTLArgument *> *)fragmentArguments
{
    return _arguments;
}

- (NSArray<MTLArgument *> *)tileArguments
{
    return _arguments;
}

@end

@implementation MTLComputePipelineReflection

{
    NSArray *_bindings;
    NSArray *_arguments;
}

- (instancetype)initWithArguments:(NSArray *)arguments
{
    if ((self = [super init])) {
        _arguments = arguments ?: @[];
        _bindings = @[];
    }
    return self;
}

- (NSArray<id<MTLBinding>> *)bindings
{
    return _bindings;
}

- (NSArray<MTLArgument *> *)arguments
{
    return _arguments;
}

@end
