#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

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
