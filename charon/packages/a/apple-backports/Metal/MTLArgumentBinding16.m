#import "CharonMetal.h"

// The argument-BINDING objects: what a buffer, a texture, a threadgroup buffer and an object payload
// look like when they are bound into an argument buffer, and the base type they all share.
//
// These are PLAIN DATA HOLDERS, which is the whole of the case for carrying them. A binding is a name,
// a kind, an access, an index, and two or three numbers describing the memory being bound — a buffer's
// alignment and its element size, a texture's type and data type. None of that asks the device
// anything, so every one of them works on a device with no argument buffers at all, and a port that
// dispatches a device pointer and the three thread identifiers still has to hand these back when a
// caller asks what a kernel binds.
//
// THE ENCODER IS NOT IN HERE, and that is the honest half. `MTLArgumentEncoder` binds a resource at an
// index on a device that has an argument BUFFER - a view over a buffer of argument buffers - and this
// port has no such facility, so `-[MTLDevice newArgumentEncoderWithBufferIndex:error:]` answers nil
// and every encoder row stays owed. What this object carries is the description of a binding, which is
// data, and it is the part a caller can actually read.
//
// The values below are the header's own facts, not chosen numbers: MTLBindingTypeBuffer is 0,
// MTLThreadgroupMemory 1, MTLTexture 2, MTLArgumentAccessReadOnly is 0 and ReadWrite 1.

// The base both pairs of readers share, so `name`, `type`, `access`, `index` and the two flags have ONE
// implementation: the four subclasses INHERIT these five and declare only the memory numbers that
// are their own. They used to re-synthesize all five as well, which under ARC gave each of them its
// own shadowing ivars - five implementations where the header declares one, and a change in one
// invisible to the others. Only `-type` is overridden per class, because only the kind differs, and
// that override is what each row's own mutant breaks.
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

// Explicit, because -Werror=objc-missing-property-synthesis forbids the auto-synthesis this
// relied on, and because a binding is five values a round trip has to read back.
@synthesize name = _name;
@synthesize index = _index;
@synthesize access = _access;
@synthesize used = _used;
@synthesize argument = _argument;

- (MTLBindingType)type
{
    // A subclass answers its OWN kind; the base is MTLBinding, which the header gives no value of its
    // own, so it is the buffer's rather than a made-up case.
    return MTLBindingTypeBuffer;
}

@end

// The four subclasses share one constructor and one base instance, so a binding is described once.
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

// "min alignment of start of buffer" and "sizeof(T) for T *argumentName" - both the header's own words
// for what these two are, and both are given rather than computed, because the alignment a caller needs
// is the one its own buffer was allocated with.
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

// "half, float, int, or uint" - the header's own list, and a texture the port binds is one of the two
// it can actually make.
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
    // The header gives an object payload a kind of ITS OWN: MTLBindingTypeObjectPayload is 34
    // (MTLArgument.h:179 in 16.4, :76 in 26.2), documented as "This binding represents an object
    // payload." It is not a buffer and nothing says it is one, so this answers 34.
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
