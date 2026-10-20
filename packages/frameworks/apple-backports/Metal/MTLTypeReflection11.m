#import "MTLTypeReflectionInternal.h"

#include <stdlib.h>
#include <string.h>

MTLDataType RevenantDataTypeFromScalar(NSString *scalar)
{
    static NSDictionary *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = (@{@"int32_t": @(MTLDataTypeInt), @"uint32_t": @(MTLDataTypeUInt),
                    @"uint8_t": @(MTLDataTypeUChar), @"uint16_t": @(MTLDataTypeUShort),
                    @"uint64_t": @(MTLDataTypeULong), @"float": @(MTLDataTypeFloat)});
    });
    NSNumber *found = scalar.length ? table[scalar] : nil;
    return found ? (MTLDataType)found.unsignedIntegerValue : MTLDataTypeNone;
}

MTLArgumentAccess RevenantAccessFromWord(NSString *word)
{
    if ([word isEqualToString:@"read-write"])
        return MTLArgumentAccessReadWrite;
    if ([word isEqualToString:@"write-only"])
        return MTLArgumentAccessWriteOnly;
    return MTLArgumentAccessReadOnly;
}

id RevenantTypedNode(NSDictionary *node, Class wanted)
{
    if (![node isKindOfClass:[NSDictionary class]])
        return nil;
    NSString *kind = node[@"kind"];
    if ([wanted isEqual:MTLStructType.class] && [kind isEqualToString:@"struct"])
        return [[MTLStructType alloc] initWithNode:node];
    if ([wanted isEqual:MTLArrayType.class] &&
        ([kind isEqualToString:@"array"] || [kind isEqualToString:@"vector"]))
        return [[MTLArrayType alloc] initWithNode:node];
    if ([wanted isEqual:MTLTextureReferenceType.class] && [kind isEqualToString:@"texture"])
        return [[MTLTextureReferenceType alloc] initWithNode:node];
    if ([wanted isEqual:MTLPointerType.class] && [kind isEqualToString:@"pointer"])
        return [[MTLPointerType alloc] initWithNode:node];
    return nil;
}

@interface MTLType () {
@protected
    NSDictionary *_node;
    MTLType *_element;
    NSMutableArray *_members;
}
@end

@implementation MTLType

- (instancetype)initWithNode:(NSDictionary *)node
{
    if ((self = [super init])) {
        _node = [node isKindOfClass:[NSDictionary class]] ? node : @{};
        NSDictionary *element = _node[@"elementType"];
        if (element)
            _element = [[MTLType alloc] initWithNode:element];
    }
    return self;
}

- (MTLDataType)dataType
{
    return RevenantDataTypeFromScalar(_node[@"scalar"]);
}

- (NSString *)revenantKind
{
    return _node[@"kind"] ?: @"";
}

- (NSDictionary *)revenantNode
{
    return _node;
}

- (MTLType *)revenantElement
{
    return _element;
}

- (NSUInteger)revenantSize
{
    return [_node[@"size"] unsignedIntegerValue];
}

- (NSUInteger)revenantAlignment
{
    return [_node[@"alignSize"] unsignedIntegerValue];
}

- (MTLDataType)revenantDataType
{
    return RevenantDataTypeFromScalar(_node[@"scalar"]);
}

- (NSMutableArray<MTLStructMember *> *)revenantMemberList
{
    if (!_members) {
        _members = [NSMutableArray array];
        for (NSDictionary *member in _node[@"members"]) {
            if (![member isKindOfClass:[NSDictionary class]])
                continue;
            MTLStructMember *made = [[MTLStructMember alloc] init];
            [made revenantSetName:(member[@"name"] ?: @"")
                         offset:[member[@"offset"] unsignedIntegerValue]
                           node:member[@"type"]];
            [_members addObject:made];
        }
    }
    return _members;
}

- (MTLStructType *)elementStructType
{
    return nil;
}

- (MTLArrayType *)elementArrayType
{
    return nil;
}

- (MTLTextureReferenceType *)elementTextureReferenceType
{
    return (MTLTextureReferenceType *)self;
}

- (MTLPointerType *)elementPointerType
{
    return (MTLPointerType *)self;
}

@end





@implementation MTLPointerType

- (MTLStructType *)elementStructType
{
    return nil;
}

- (MTLArrayType *)elementArrayType
{
    return nil;
}

- (MTLTextureReferenceType *)elementTextureReferenceType
{
    return nil;
}

- (MTLPointerType *)elementPointerType
{
    return self;
}

- (MTLType *)pointee
{
    return nil;
}

- (MTLDataType)elementType
{
    NSDictionary *element = _node[@"elementType"];
    return [element isKindOfClass:[NSDictionary class]] ? RevenantDataTypeFromScalar(element[@"scalar"])
                                                        : MTLDataTypeNone;
}

- (MTLArgumentAccess)access
{
    return RevenantAccessFromWord(_node[@"access"]);
}

- (NSUInteger)alignment
{
    return [_node[@"alignSize"] unsignedIntegerValue];
}

- (NSUInteger)dataSize
{
    return [_node[@"size"] unsignedIntegerValue];
}

@end

@implementation MTLTextureReferenceType

- (MTLDataType)textureDataType
{
    return MTLDataTypeNone;
}

- (MTLTextureType)textureType
{
    return MTLTextureType2D;
}

- (MTLArgumentAccess)access
{
    return RevenantAccessFromWord(_node[@"access"]);
}

- (BOOL)isDepthTexture
{
    return NO;
}

@end
