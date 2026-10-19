#import "MTLTypeReflectionInternal.h"

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

- (void)charonSetName:(NSString *)name offset:(NSUInteger)offset node:(NSDictionary *)node
{
    _memberName = [name copy];
    _memberOffset = offset;
    _memberNode = node;
}

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
