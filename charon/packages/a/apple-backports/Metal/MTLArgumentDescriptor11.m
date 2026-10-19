#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

// THE ARGUMENT DESCRIPTOR, the class MTLDevice.h declares at iOS 11.0.
//
// A plain data holder, like the other descriptors beside it: it says what one member of an argument buffer is
// (its data type, binding index, array length, access, texture type and constant block alignment), and asks no
// device anything. The argument encoder that would lay the member out is not in this port, so nothing here
// hands anything back to a device; the descriptor is carried so that a caller building one reads back what it wrote.
//
// FRESH DEFAULTS, measured on the host (tests/backports/host/argument-descriptor): dataType is None (0), index and
// arrayLength are 0, access is read-only (0), textureType is 2D (2), and constantBlockAlignment is 0, which means
// the default alignment. Only the texture type is not zero, so only it is set in init.
//
// THE VALUES APPLE ACCEPTS, measured by forking a child per value on the macOS host (the same host test, data types 0 to
// 255): data types 0 to 60, 78 to 88, 115 to 118, 121 to 124, 127 to 135 and 139, and nothing from 140 to 255; access
// read-only to write-only (0 to 2). The later data types are the host's newer ones and are not measured on an iOS 11
// device. Any other value aborts Apple's process from its own validator; the port raises NSInvalidArgumentException,
// which uncaught ends the process with the same status. The texture type is not checked by Apple, so not here.
//
// COPY is a new object with the same members, and EQUALITY is by value (measured: a copy is equal to its
// original, a fresh descriptor is not equal to a set one), with a hash that agrees with it.

@implementation MTLArgumentDescriptor {
    MTLDataType _dataType;
    NSUInteger _index;
    NSUInteger _arrayLength;
    MTLArgumentAccess _access;
    MTLTextureType _textureType;
    NSUInteger _constantBlockAlignment;
}

+ (MTLArgumentDescriptor *)argumentDescriptor
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _textureType = MTLTextureType2D;
    }
    return self;
}

// Apple's validator, measured on the host: the data types listed in the header comment above, and nothing else.
@synthesize index = _index;
@synthesize arrayLength = _arrayLength;
@synthesize textureType = _textureType;
@synthesize constantBlockAlignment = _constantBlockAlignment;

- (void)setDataType:(MTLDataType)dataType
{
    NSUInteger type = (NSUInteger)dataType;
    BOOL accepted = type <= 60 || (type >= 78 && type <= 88) || (type >= 115 && type <= 118) ||
                    (type >= 121 && type <= 124) || (type >= 127 && type <= 135) || type == 139;
    if (!accepted)
        [NSException raise:NSInvalidArgumentException format:@"dataType (%lu) is not a valid MTLDataType", (unsigned long)dataType];
    _dataType = dataType;
}

- (MTLDataType)dataType
{
    return _dataType;
}

- (void)setAccess:(MTLArgumentAccess)access
{
    if ((NSUInteger)access > (NSUInteger)MTLArgumentAccessWriteOnly)
        [NSException raise:NSInvalidArgumentException format:@"access (%lu) is not a valid MTLBindingAccess", (unsigned long)access];
    _access = access;
}

- (MTLArgumentAccess)access
{
    return _access;
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    MTLArgumentDescriptor *copy = [[MTLArgumentDescriptor alloc] init];
    copy.dataType = _dataType;
    copy.index = _index;
    copy.arrayLength = _arrayLength;
    copy.access = _access;
    copy.textureType = _textureType;
    copy.constantBlockAlignment = _constantBlockAlignment;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[MTLArgumentDescriptor class]])
        return NO;
    MTLArgumentDescriptor *other = object;
    return _dataType == other->_dataType && _index == other->_index && _arrayLength == other->_arrayLength &&
           _access == other->_access && _textureType == other->_textureType &&
           _constantBlockAlignment == other->_constantBlockAlignment;
}

- (NSUInteger)hash
{
    return (NSUInteger)_dataType ^ _index ^ _arrayLength ^ (NSUInteger)_access ^ (NSUInteger)_textureType ^ _constantBlockAlignment;
}

@end
