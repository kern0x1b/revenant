#import "MTLTypeReflectionInternal.h"

#include <stdlib.h>
#include <string.h>

MTLDataType CharonDataTypeFromScalar(NSString *scalar)
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

MTLArgumentAccess CharonAccessFromWord(NSString *word)
{
    if ([word isEqualToString:@"read-write"])
        return MTLArgumentAccessReadWrite;
    if ([word isEqualToString:@"write-only"])
        return MTLArgumentAccessWriteOnly;
    return MTLArgumentAccessReadOnly;
}

id CharonTypedNode(NSDictionary *node, Class wanted)
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
    return CharonDataTypeFromScalar(_node[@"scalar"]);
}

- (NSString *)charonKind
{
    return _node[@"kind"] ?: @"";
}

- (NSDictionary *)charonNode
{
    return _node;
}

- (MTLType *)charonElement
{
    return _element;
}

- (NSUInteger)charonSize
{
    return [_node[@"size"] unsignedIntegerValue];
}

- (NSUInteger)charonAlignment
{
    return [_node[@"alignSize"] unsignedIntegerValue];
}

- (MTLDataType)charonDataType
{
    return CharonDataTypeFromScalar(_node[@"scalar"]);
}

- (NSMutableArray<MTLStructMember *> *)charonMemberList
{
    if (!_members) {
        _members = [NSMutableArray array];
        for (NSDictionary *member in _node[@"members"]) {
            if (![member isKindOfClass:[NSDictionary class]])
                continue;
            MTLStructMember *made = [[MTLStructMember alloc] init];
            [made charonSetName:(member[@"name"] ?: @"")
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
    return [element isKindOfClass:[NSDictionary class]] ? CharonDataTypeFromScalar(element[@"scalar"])
                                                        : MTLDataTypeNone;
}

- (MTLArgumentAccess)access
{
    return CharonAccessFromWord(_node[@"access"]);
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
    return CharonAccessFromWord(_node[@"access"]);
}

- (BOOL)isDepthTexture
{
    return NO;
}

@end
