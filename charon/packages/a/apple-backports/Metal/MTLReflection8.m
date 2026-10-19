#import "CharonMetal.h"
#import "MTLTypeReflectionInternal.h"

#include <stdlib.h>

// The 8.0 half of the reflection classes: what a pipeline state says about itself.
//
// An object carries the API of ONE release, and these three are the 8.0 ones - MTLRenderPipeline.h
// and MTLComputePipeline.h place MTLRenderPipelineReflection and MTLComputePipelineReflection at 8.0,
// and MTLLibrary.h places MTLVertexAttribute at 8.0.
//
// WHAT THE PLIST CARRIES, and what it does not, is the whole of these classes. air2cpu writes each
// function's ARGUMENTS - index, name, access, texture data type, type tree, type name, size, alignment,
// and a struct's member list - and it carries NOTHING about a render pipeline's bindings, a function's
// constants, or a vertex attribute. So every member here is answered from the argument list the plist
// does have where one is the right answer, and from the header's own documented absence where it is
// not, and the row says which is which. A reflection object that invents bindings it cannot see
// would be reporting a pipeline the port did not build.

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

// The data type, from the same scalar name the reader's helpers already use, and MTLDataTypeNone
// where the AIR named none - the header's own no-type case, not a case picked to be near.
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

// The two pipeline reflections. Both are the same shape - the bindings, and the arguments - and
// neither binding list is in the plist, so they answer EMPTY rather than a guess.
@implementation MTLRenderPipelineReflection

{
    NSArray *_bindings;
    NSArray *_arguments;
}

- (instancetype)initWithArguments:(NSArray *)arguments
{
    if ((self = [super init])) {
        _arguments = arguments ?: @[];
        // The binding lists are EMPTY and the row says why: the plist carries no bindings, because
        // the port translates each kernel's argument list and nothing about a pipeline's resource
        // bindings. An empty list is the honest answer and a fabricated one is not.
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

// The ARGUMENTS are in the plist, and this is the right answer for them: the reader builds one
// MTLArgument per entry of the function's argument list.
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
        _bindings = @[];   // as above: the plist carries no bindings
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
