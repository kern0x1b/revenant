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
    return self.revenantMemberName;
}

- (NSUInteger)offset
{
    return self.revenantMemberOffset;
}

- (MTLDataType)dataType
{
    return self.revenantDataType;
}

- (MTLStructType *)structType
{
    return self.revenantStructType;
}

- (MTLArrayType *)arrayType
{
    return self.revenantArrayType;
}

- (MTLTextureReferenceType *)textureReferenceType
{
    return self.revenantTextureReferenceType;
}

- (MTLPointerType *)pointerType
{
    return self.revenantPointerType;
}

@end

@implementation MTLStructMember (RevenantTypeTreeStorage)

- (void)revenantSetName:(NSString *)name offset:(NSUInteger)offset node:(NSDictionary *)node
{
    _memberName = [name copy];
    _memberOffset = offset;
    _memberNode = node;
}

- (NSDictionary *)revenantMemberNode
{
    return _memberNode;
}

- (NSString *)revenantMemberName
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
    return RevenantDataTypeFromScalar(_memberNode[@"scalar"]);
}

- (MTLDataType)revenantDataType
{
    return RevenantDataTypeFromScalar(_memberNode[@"scalar"]);
}

- (NSUInteger)revenantMemberOffset
{
    return _memberOffset;
}

- (NSUInteger)argumentIndex
{
    return [_memberNode isKindOfClass:[NSDictionary class]] ? [_memberNode[@"index"] unsignedIntegerValue] : 0;
}

- (MTLStructType *)revenantStructType
{
    return RevenantTypedNode(_memberNode, MTLStructType.class);
}

- (MTLArrayType *)revenantArrayType
{
    return RevenantTypedNode(_memberNode, MTLArrayType.class);
}

- (MTLTextureReferenceType *)revenantTextureReferenceType
{
    return RevenantTypedNode(_memberNode, MTLTextureReferenceType.class);
}

- (MTLPointerType *)revenantPointerType
{
    return RevenantTypedNode(_memberNode, MTLPointerType.class);
}
@end

@implementation MTLStructType

- (NSArray<MTLStructMember *> *)members
{
    return self.revenantMemberList;
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
    return [self revenantDataType];
}

- (MTLType *)elementTypeObject
{
    return self.revenantElement;
}

- (NSUInteger)arrayLength
{
    NSDictionary *node = self.revenantNode;
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
    return RevenantTypedNode(self.revenantElement.revenantNode, MTLStructType.class);
}

- (MTLArrayType *)elementArrayType
{
    return RevenantTypedNode(self.revenantElement.revenantNode, MTLArrayType.class);
}

- (MTLTextureReferenceType *)elementTextureReferenceType
{
    return RevenantTypedNode(self.revenantElement.revenantNode, MTLTextureReferenceType.class);
}

- (MTLPointerType *)elementPointerType
{
    return RevenantTypedNode(self.revenantElement.revenantNode, MTLPointerType.class);
}

@end

@implementation RevenantMetalTypeTree {
    NSDictionary *_document;
}

+ (instancetype)treeWithContentsOfFile:(NSString *)path
{
    RevenantMetalTypeTree *tree = [[RevenantMetalTypeTree alloc] init];
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

- (NSUInteger)revenantArgumentIndex
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
    return RevenantAccessFromWord(_argument[@"access"]);
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
    return RevenantDataTypeFromScalar(_argument[@"scalar"]);
}

- (MTLStructType *)bufferStructType
{
    return RevenantTypedNode(_argument, MTLStructType.class);
}

- (MTLPointerType *)bufferPointerType
{
    return RevenantTypedNode(_argument, MTLPointerType.class);
}

- (MTLArrayType *)bufferArrayType
{
    return RevenantTypedNode(_argument, MTLArrayType.class);
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
