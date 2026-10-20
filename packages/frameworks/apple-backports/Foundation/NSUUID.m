#import <Foundation/Foundation.h>
#include <uuid/uuid.h>

__attribute__((visibility("hidden")))
@interface __NSConcreteUUID : NSUUID
@end

static NSUInteger revenant_uuid_hash(const uint8_t *bytes)
{
    uint32_t hash = 0;
    for (int index = 0; index < 16; index++) {
        uint32_t step = (hash << 4) + bytes[index];
        uint32_t high = step & 0xF0000000;
        if (high)
            step ^= high >> 24;
        hash = step & ~high;
    }
    return hash;
}

static NSException *revenant_uuid_unreadable(NSString *reason)
{
    return [NSException exceptionWithName:NSInvalidUnarchiveOperationException reason:reason userInfo:nil];
}

@implementation NSUUID

+ (instancetype)UUID
{
    return [[self alloc] init];
}

+ (id)allocWithZone:(NSZone *)zone
{
    if (self == [NSUUID class])
        return [__NSConcreteUUID allocWithZone:zone];
    return [super allocWithZone:zone];
}

- (instancetype)init
{
    return self;
}

- (instancetype)initWithUUIDString:(NSString *)string
{
    return nil;
}

- (instancetype)initWithUUIDBytes:(const uuid_t)bytes
{
    return nil;
}

- (void)getUUIDBytes:(uuid_t)bytes
{
    memset(bytes, 0, sizeof(uuid_t));
}

- (NSString *)UUIDString
{
    return @"";
}

- (id)copyWithZone:(NSZone *)zone
{
    return nil;
}

- (NSUInteger)hash
{
    uuid_t bytes;
    [self getUUIDBytes:bytes];
    return revenant_uuid_hash(bytes);
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSUUID class]])
        return NO;
    uuid_t mine, theirs;
    [self getUUIDBytes:mine];
    [other getUUIDBytes:theirs];
    return memcmp(mine, theirs, sizeof(uuid_t)) == 0;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    uuid_t bytes;
    [self getUUIDBytes:bytes];
    [coder encodeBytes:bytes length:sizeof(uuid_t) forKey:@"NS.uuidbytes"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSUInteger length = 0;
    const uint8_t *bytes = [coder decodeBytesForKey:@"NS.uuidbytes" returnedLength:&length];
    if (!bytes)
        [revenant_uuid_unreadable(@"The data couldn’t be read because it is missing.") raise];
    if (length != sizeof(uuid_t))
        [revenant_uuid_unreadable(@"The data couldn’t be read because it isn’t in the correct format.") raise];
    return [self initWithUUIDBytes:bytes];
}

@end

@implementation __NSConcreteUUID {
    uuid_t _uuidBytes;
}

- (instancetype)init
{
    if ((self = [super init]))
        uuid_generate_random(_uuidBytes);
    return self;
}

- (instancetype)initWithUUIDString:(NSString *)string
{
    if (!(self = [super init]))
        return nil;
    const char *characters = string.UTF8String;
    if (!characters || uuid_parse(characters, _uuidBytes) != 0)
        return nil;
    return self;
}

- (instancetype)initWithUUIDBytes:(const uuid_t)bytes
{
    if (!(self = [super init]))
        return nil;
    if (bytes)
        memcpy(_uuidBytes, bytes, sizeof(uuid_t));
    else
        memset(_uuidBytes, 0, sizeof(uuid_t));
    return self;
}

- (void)getUUIDBytes:(uuid_t)bytes
{
    memcpy(bytes, _uuidBytes, sizeof(uuid_t));
}

- (NSString *)UUIDString
{
    uuid_string_t text;
    uuid_unparse_upper(_uuidBytes, text);
    return [NSString stringWithUTF8String:text];
}

- (NSString *)description
{
    return [self UUIDString];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (Class)classForCoder
{
    return [NSUUID class];
}

@end
