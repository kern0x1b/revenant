#import "MTLTypeReflectionInternal.h"

// The 10.0 half of the reflection classes: MTLAttribute and MTLFunctionConstant.
//
// MTLLibrary.h places both at 10.0, and they are the two the port's own header is missing between
// MTLVertexAttribute (8.0) and the pipeline buffer descriptors (11.0) - so this object is one release
// and one release only, which is what the release-split rule requires.
//
// WHAT THE PLIST CARRIES, again, decides every member here. It writes a function's ARGUMENTS - index,
// name, access, type tree, type name, size, alignment, and a struct's member list - and it carries
// NOTHING about a stage input or a function constant. So:
//
//   MTLAttribute          is built from an argument node, exactly as MTLVertexAttribute is in
//                         MTLReflection8.m, and its two patch-data getters answer NO because the plist
//                         has no patch flag to read.
//   MTLFunctionConstant   cannot be built from anything the plist carries, because the plist has no
//                         constants. Its members are still real: they read the node a caller hands it,
//                         and the dictionary that would hand them one is the empty one
//                         MTLFunction.functionConstantsDictionary already returns, with the absence
//                         recorded in the row.

@implementation MTLAttribute

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

// The data type, from the same scalar name the rest of the reader uses, and MTLDataTypeNone where the
// AIR named none - the header's own no-type case, not a case picked to be near.
- (MTLDataType)attributeType
{
    return CharonDataTypeFromScalar(_node[@"scalar"]);
}

- (BOOL)isActive
{
    return YES;
}

// NO, and the absence is the plist's: it carries no patch or control-point flag, so there is nothing
// that says this argument is patch data. These are 13.0 members and the port dispatches compute and
// render kernels, neither of which is tessellated.
- (BOOL)isPatchData
{
    return NO;
}

- (BOOL)isPatchControlPointData
{
    return NO;
}

@end

@implementation MTLFunctionConstant

{
    NSDictionary *_node;
}

- (instancetype)initWithNode:(NSDictionary *)node
{
    if ((self = [super init]))
        _node = [node isKindOfClass:[NSDictionary class]] ? node : @{};
    return self;
}

// The four members the header declares at MTLLibrary.h, all read from the node a caller hands this
// class. The node is empty in practice - air2cpu writes no constants - and then each answers the
// header's own empty case rather than a fabricated one.
- (NSString *)name
{
    return _node[@"name"] ?: @"";
}

- (MTLDataType)type
{
    return CharonDataTypeFromScalar(_node[@"scalar"]);
}

- (NSUInteger)index
{
    return [_node[@"index"] unsignedIntegerValue];
}

// A constant the plist has no record of is not required: the header calls it whether the value must
// be provided at every use, and a kernel this port dispatches has none.
- (BOOL)isRequired
{
    return NO;
}

@end
