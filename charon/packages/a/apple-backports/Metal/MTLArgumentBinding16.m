#import "CharonMetal.h"

@interface CharonMetalBinding : NSObject <MTLBinding>
{
    NSString *_name;
    NSUInteger _index;
    MTLArgumentAccess _access;
    BOOL _used, _argument;
}
@end

@interface CharonMetalBufferBinding : CharonMetalBinding <MTLBufferBinding>
{
    NSUInteger _alignment, _dataSize;
    MTLDataType _dataType;
}
@end

@interface CharonMetalTextureBinding : CharonMetalBinding <MTLTextureBinding>
{
    MTLTextureType _textureType;
    MTLDataType _dataType;
    NSUInteger _arrayLength;
}
@end

@interface CharonMetalThreadgroupBinding : CharonMetalBinding <MTLThreadgroupBinding>
{
    NSUInteger _alignment, _dataSize;
}
@end

@interface CharonMetalObjectPayloadBinding : CharonMetalBinding <MTLObjectPayloadBinding>
{
    NSUInteger _alignment, _dataSize;
}
@end

@implementation CharonMetalBinding

@synthesize name = _name;
@synthesize index = _index;
@synthesize access = _access;
@synthesize used = _used;
@synthesize argument = _argument;

- (MTLBindingType)type
{
    return MTLBindingTypeBuffer;
}

@end

CharonMetalBinding *CharonMakeBinding(Class kind, NSString *name, NSUInteger index,
                                            MTLArgumentAccess access, BOOL argument, BOOL used)
{
    CharonMetalBinding *binding = [[kind alloc] init];
    if (!binding)
        return nil;
    [binding setValue:name forKey:@"name"];
    [binding setValue:@(index) forKey:@"index"];
    [binding setValue:@(access) forKey:@"access"];
    [binding setValue:@(argument) forKey:@"argument"];
    [binding setValue:@(used) forKey:@"used"];
    return binding;
}

@implementation CharonMetalBufferBinding

@synthesize bufferAlignment = _alignment, bufferDataSize = _dataSize, bufferDataType = _dataType;

- (MTLBindingType)type
{
    return MTLBindingTypeBuffer;
}

- (NSUInteger)bufferAlignment
{
    return _alignment;
}

- (NSUInteger)bufferDataSize
{
    return _dataSize;
}

- (MTLDataType)bufferDataType
{
    return _dataType;
}

- (MTLStructType *)bufferStructType
{
    return nil;
}

- (MTLPointerType *)bufferPointerType
{
    return nil;
}

@end

@implementation CharonMetalTextureBinding

@synthesize textureType = _textureType, textureDataType = _dataType, arrayLength = _arrayLength;

- (MTLBindingType)type
{
    return MTLBindingTypeTexture;
}

- (MTLTextureType)textureType
{
    return _textureType;
}

- (MTLDataType)textureDataType
{
    return _dataType;
}

- (BOOL)isDepthTexture
{
    return NO;
}

- (NSUInteger)arrayLength
{
    return _arrayLength;
}

@end

@implementation CharonMetalThreadgroupBinding

@synthesize threadgroupMemoryAlignment = _alignment, threadgroupMemoryDataSize = _dataSize;

- (MTLBindingType)type
{
    return MTLBindingTypeThreadgroupMemory;
}

- (NSUInteger)threadgroupMemoryAlignment
{
    return _alignment;
}

- (NSUInteger)threadgroupMemoryDataSize
{
    return _dataSize;
}

@end

@implementation CharonMetalObjectPayloadBinding

@synthesize objectPayloadAlignment = _alignment, objectPayloadDataSize = _dataSize;

- (MTLBindingType)type
{
    return MTLBindingTypeObjectPayload;
}

- (NSUInteger)objectPayloadAlignment
{
    return _alignment;
}

- (NSUInteger)objectPayloadDataSize
{
    return _dataSize;
}

@end
