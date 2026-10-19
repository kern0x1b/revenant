#import <Foundation/Foundation.h>
#include <uuid/uuid.h>

// NSUUID is a class cluster in the releases that have it (facts/Foundation/NSUUID.md): NSUUID answers the questions a subclass
// has not answered itself through -getUUIDBytes:, and +allocWithZone: on NSUUID itself hands out a concrete class that holds
// the 16 bytes. The concrete class is not exported, as the release's is not.
__attribute__((visibility("hidden")))
@interface __NSConcreteUUID : NSUUID
@end

// The 32-bit hash the releases give an NSUUID: the ELF object file hash over its 16 bytes (the last step of it, the shift of the
// sum by the length, is not applied), which is what -[NSData hash] gives the same bytes.
static NSUInteger charon_uuid_hash(const uint8_t *bytes)
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

static NSException *charon_uuid_unreadable(NSString *reason)
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

// A subclass that does not override these two is not given a UUID to hold, as in the releases.
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
    return charon_uuid_hash(bytes);
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

// What the newest release does with an archive whose bytes are absent or not 16: it refuses to decode it. The release of iOS 6
// makes a random UUID of it instead, which is a UUID nobody archived.
- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSUInteger length = 0;
    const uint8_t *bytes = [coder decodeBytesForKey:@"NS.uuidbytes" returnedLength:&length];
    if (!bytes)
        [charon_uuid_unreadable(@"The data couldn’t be read because it is missing.") raise];
    if (length != sizeof(uuid_t))
        [charon_uuid_unreadable(@"The data couldn’t be read because it isn’t in the correct format.") raise];
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
