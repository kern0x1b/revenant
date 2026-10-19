#import "MTLTypeReflectionInternal.h"

// The 8.0 half of the type tree's reader, and the tree itself.
//
// release-split measured the ladder on the reader's own object: MTLArgument, MTLStructMember,
// MTLStructType and MTLArrayType are exported from 8.0, and MTLType, MTLPointerType and
// MTLTextureReferenceType from 11.0. One object for all seven mixes releases, which is what the 6.1.3
// gate's release-split rule stopped on. This is the 8.0 object and MTLTypeReflection11.m is the other.
//
// It holds NO storage of its own for MTLType: those ivars are a class extension's, and a class
// extension's ivars belong to the translation unit that declares them - which is the 11.0 object. So
// every read of a node here goes through the accessors MTLTypeReflectionInternal.h declares and the 11.0
// object implements. That is the whole reason that header exists, and it is why the two objects can be
// split at all without either of them reaching into the other's translation unit.

// MTLStructMember is 8.0 on the ladder, so this is where its @implementation lives, and its storage
// (the extension above) with it.
// The STORAGE of MTLStructMember, in the translation unit that holds its @implementation: an
// extension's ivars are DEFINED by the @implementation that sees them, so declared anywhere else the
// symbols _OBJC_IVAR_$_MTLStructMember._memberName etc. are defined by no object and the link fails
// (the 6.1.3 gate, gate-613-3).
@interface MTLStructMember () {
@protected
    NSString *_memberName;
    NSUInteger _memberOffset;
    NSDictionary *_memberNode;
}
@end

@implementation MTLStructMember

- (NSString *)name
{
    return self.charonMemberName;
}

- (NSUInteger)offset
{
    return self.charonMemberOffset;
}

- (MTLDataType)dataType
{
    return self.charonDataType;
}

- (MTLStructType *)structType
{
    return self.charonStructType;
}

- (MTLArrayType *)arrayType
{
    return self.charonArrayType;
}

- (MTLTextureReferenceType *)textureReferenceType
{
    return self.charonTextureReferenceType;
}

- (MTLPointerType *)pointerType
{
    return self.charonPointerType;
}

@end

@implementation MTLStructMember (CharonTypeTreeStorage)

// The STORAGE of MTLStructMember, which is 8.0 on the ladder and whose @implementation is in the 8.0
// object. These ivars are a class extension's and belong to THIS translation unit, so the 8.0 object
// reaches them through charonSetName:offset:node: rather than touching them - which is the rule that
// makes the two objects able to exist at all.
- (void)charonSetName:(NSString *)name offset:(NSUInteger)offset node:(NSDictionary *)node
{
    _memberName = [name copy];
    _memberOffset = offset;
    _memberNode = node;
}

// The one way a member is made, so the three values it carries are set once and together. The
// internal header names it because the 8.0 object's array code builds members through it.

- (NSDictionary *)charonMemberNode
{
    return _memberNode;
}

- (NSString *)charonMemberName
{
    return _memberName ?: @"";
}

- (NSString *)name
{
    return _memberName ?: @"";
}

- (NSUInteger)offset
{
    return _memberOffset;
}

- (MTLDataType)dataType
{
    return CharonDataTypeFromScalar(_memberNode[@"scalar"]);
}

- (MTLDataType)charonDataType
{
    return CharonDataTypeFromScalar(_memberNode[@"scalar"]);
}

- (NSUInteger)charonMemberOffset
{
    return _memberOffset;
}

- (NSUInteger)argumentIndex
{
    return [_memberNode isKindOfClass:[NSDictionary class]] ? [_memberNode[@"index"] unsignedIntegerValue] : 0;
}

- (MTLStructType *)charonStructType
{
    return CharonTypedNode(_memberNode, MTLStructType.class);
}

- (MTLArrayType *)charonArrayType
{
    return CharonTypedNode(_memberNode, MTLArrayType.class);
}

- (MTLTextureReferenceType *)charonTextureReferenceType
{
    return CharonTypedNode(_memberNode, MTLTextureReferenceType.class);
}

- (MTLPointerType *)charonPointerType
{
    return CharonTypedNode(_memberNode, MTLPointerType.class);
}
@end

@implementation MTLStructType

- (NSArray<MTLStructMember *> *)members
{
    return self.charonMemberList;
}

- (MTLStructMember *)memberByName:(NSString *)name
{
    for (MTLStructMember *member in [self members])
        if ([member.name isEqualToString:name])
            return member;
    return nil;
}

@end

@implementation MTLArrayType

// elementType is the element's data type, and it is MTLDataTypeNone where the plist carries no
// scalar name: the header's own no-type case, not a case picked to be near.
- (MTLDataType)elementType
{
    return [self charonDataType];
}

- (MTLType *)elementTypeObject
{
    return self.charonElement;
}

- (NSUInteger)arrayLength
{
    NSDictionary *node = self.charonNode;
    return [node[@"length"] unsignedIntegerValue];
}

// The stride is 0, and that is the absence rather than a value: the AIR carries a size and an
// alignment and no stride, and a stride computed from them would be wrong for a padded element.
- (NSUInteger)arrayStride
{
    return 0;
}

- (NSUInteger)stride
{
    return 0;
}

- (NSUInteger)argumentIndexStride
{
    return 0;
}

// The four element accessors MTLArgument.h:266-269 declares, one per kind, and nil where the element
// is not of that kind - which is what a nullable MTLStructType * says, and is also what a kind this
// build does not know gets.
- (MTLStructType *)elementStructType
{
    return CharonTypedNode(self.charonElement.charonNode, MTLStructType.class);
}

- (MTLArrayType *)elementArrayType
{
    return CharonTypedNode(self.charonElement.charonNode, MTLArrayType.class);
}

- (MTLTextureReferenceType *)elementTextureReferenceType
{
    return CharonTypedNode(self.charonElement.charonNode, MTLTextureReferenceType.class);
}

- (MTLPointerType *)elementPointerType
{
    return CharonTypedNode(self.charonElement.charonNode, MTLPointerType.class);
}

@end

// The tree: the property list, read once, with NSPropertyListSerialization - which has read a plist
// since iOS 2, so this adds no parser of its own. A file that is missing, unreadable, or of a version
// this build does not know leaves the tree empty and every type answers what the header documents for
// a type it cannot describe. The version is refused rather than read, because reading a shape this
// build has never seen would be a guess about keys it cannot check.
@implementation CharonMetalTypeTree {
    NSDictionary *_document;
}

+ (instancetype)treeWithContentsOfFile:(NSString *)path
{
    CharonMetalTypeTree *tree = [[CharonMetalTypeTree alloc] init];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data)
        return tree;
    id document = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    if (![document isKindOfClass:[NSDictionary class]])
        return tree;
    if ([document[@"version"] integerValue] != 1)
        return tree;
    tree->_document = document;
    return tree;
}

- (NSArray<NSDictionary *> *)functions
{
    return _document[@"functions"] ?: @[];
}

- (NSDictionary *)functionNamed:(NSString *)name
{
    for (NSDictionary *function in [self functions])
        if ([function[@"name"] isEqualToString:name])
            return function;
    return nil;
}

- (NSArray<NSDictionary *> *)argumentsOfFunction:(NSDictionary *)function
{
    NSArray *arguments = function[@"arguments"];
    return [arguments isKindOfClass:[NSArray class]] ? arguments : @[];
}

@end

// MTLArgument: one argument, as its own metadata node reads.
//
// The AIR says what kind of thing an argument is in two places that agree: its type class
// (air.buffer, air.texture) and its address space. The type class is the one used here, because it is
// what the argument node names and it is not a number that has to be mapped. The address space is
// recorded in the facts and is not used to decide anything: the real libraries put a buffer in space
// 1, another in space 2 and one in space 3, so a space does not name a type on its own.
@implementation MTLArgument {
    NSDictionary *_argument;
}

- (instancetype)initWithNode:(NSDictionary *)node
{
    if ((self = [super init]))
        _argument = [node isKindOfClass:[NSDictionary class]] ? node : @{};
    return self;
}

- (NSString *)name
{
    return _argument[@"name"] ?: @"";
}

- (NSUInteger)index
{
    return [_argument[@"index"] unsignedIntegerValue];
}

- (NSUInteger)charonArgumentIndex
{
    return [_argument[@"index"] unsignedIntegerValue];
}

- (MTLArgumentType)type
{
    NSString *class = _argument[@"typeClass"];
    if ([class isEqualToString:@"texture"])
        return MTLArgumentTypeTexture;
    if ([class isEqualToString:@"sampler"])
        return MTLArgumentTypeSampler;
    if ([class isEqualToString:@"threadgroup"])
        return MTLArgumentTypeThreadgroupMemory;
    return MTLArgumentTypeBuffer;
}

- (MTLArgumentAccess)access
{
    return CharonAccessFromWord(_argument[@"access"]);
}

// An argument of a kernel this port dispatches is bound before the dispatch is encoded, so it is
// active; one of a refused kernel is never reached. The port records the refusal, it does not make an
// argument inactive.
- (BOOL)isActive
{
    return YES;
}

- (NSUInteger)bufferAlignment
{
    return [_argument[@"alignSize"] unsignedIntegerValue];
}

- (NSUInteger)bufferDataSize
{
    return [_argument[@"size"] unsignedIntegerValue];
}

- (MTLDataType)bufferDataType
{
    return CharonDataTypeFromScalar(_argument[@"scalar"]);
}

- (MTLStructType *)bufferStructType
{
    return CharonTypedNode(_argument, MTLStructType.class);
}

- (MTLPointerType *)bufferPointerType
{
    return CharonTypedNode(_argument, MTLPointerType.class);
}

- (MTLArrayType *)bufferArrayType
{
    return CharonTypedNode(_argument, MTLArrayType.class);
}

// The threadgroup members answer 0 and nil: a threadgroup argument is one the AIR marked in address
// space 3, and the plist carries no size or alignment for one. That is the absence, NOT a zero-length
// threadgroup.
- (NSUInteger)threadgroupMemoryAlignment
{
    return 0;
}

- (NSUInteger)threadgroupMemoryDataSize
{
    return 0;
}

- (MTLTextureType)textureType
{
    return MTLTextureType2D;
}

- (MTLDataType)textureDataType
{
    return MTLDataTypeNone;
}

- (BOOL)isDepthTexture
{
    return NO;
}

- (NSUInteger)arrayLength
{
    return [_argument[@"arrayLength"] unsignedIntegerValue];
}

@end
