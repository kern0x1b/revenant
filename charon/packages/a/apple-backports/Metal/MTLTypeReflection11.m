#import "MTLTypeReflectionInternal.h"

#include <stdlib.h>
#include <string.h>

// The 11.0 half of the type tree's reader.
//
// An object carries the API of ONE release, decided by the cache ladder, and release-split measured
// which: MTLType, MTLPointerType and MTLTextureReferenceType are exported from 11.0, while
// MTLArgument, MTLStructMember, MTLStructType and MTLArrayType are exported from 8.0. One object for
// all seven mixes releases, which is what the 6.1.3 gate's release-split rule stopped on.
//
// This is the 11.0 object, and it is also where MTLType's STORAGE lives - its class extension's ivars
// belong to the translation unit that declares them, so the 8.0 object's subclasses cannot read them
// and go through the accessors MTLTypeReflectionInternal.h declares. Those accessors are implemented
// here, beside the ivars they publish, and that is why this file exists as more than three classes.

// The helpers are EXTERNAL, not static: a static function cannot cross a translation unit, and the 8.0
// object needs both of them. The names are the port's own and the library compiles with
// -fvisibility=hidden, so they cost an application nothing.
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

// The storage, in a CLASS EXTENSION in this same file: the non-fragile ABI refuses ivars in a category,
// and this is where they are reachable from.
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

// The member list of a struct, built on first use from the air.struct_type_info the plist carries. A
// member the AIR did not name is in the list with an EMPTY name, because an LLVM 23 StructType has
// element types and no per-element names - the absence is in the data, and a name invented here would
// be a name the shader does not have.
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





// MTLPointerType: the pointee is nil, always. LLVM has used opaque pointers since 15, so the AIR carries
// no pointee type at all - the absence is in the data, and a pointee invented here would name a type
// the shader does not have.
// The element accessors MTLArgument.h:266-269 declares on MTLType itself, so EVERY subclass must
// carry them and clang checks the inherited set per @implementation. The 8.0 object carries them on
// MTLArrayType, where the header's argument-by-argument reading is most useful; this object carries
// them on MTLPointerType, whose element is a pointer and so is neither a struct nor an array - which
// is the header's own nullable answer and not a guess.
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

// elementType is the element's data type, and alignment and dataSize are the header's own "min
// alignment for the element data type" and "sizeof(T) for T *argName" - and the AIR carries exactly
// those two numbers as size and alignSize, so both are MEASURED, not defaulted.
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

// MTLTextureReferenceType: textureType is a DEFAULT and is labelled one. The plist carries no texture
// type for a texture argument, and MTLTextureType's enumeration has no "none" case - it starts at 2D -
// so there is no honest absent value. A texture argument this port carries is a 2D texture, because
// that is the shape the port builds. isDepthTexture is NO, and that absence is the plist's.
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
