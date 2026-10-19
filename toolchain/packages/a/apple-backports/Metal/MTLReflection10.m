#import "MTLTypeReflectionInternal.h"

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

- (MTLDataType)attributeType
{
    return RevenantDataTypeFromScalar(_node[@"scalar"]);
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

- (NSString *)name
{
    return _node[@"name"] ?: @"";
}

- (MTLDataType)type
{
    return RevenantDataTypeFromScalar(_node[@"scalar"]);
}

- (NSUInteger)index
{
    return [_node[@"index"] unsignedIntegerValue];
}

- (BOOL)isRequired
{
    return NO;
}

@end
