#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <uuid/uuid.h>
#import "../revenant_alias.h"

REVENANT_ALIAS(NSUUID)

static char RevenantUUIDBytesKey;

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

static void revenant_uuid_store(NSUUID *uuid, const uuid_t bytes)
{
    objc_setAssociatedObject(uuid, &RevenantUUIDBytesKey, [NSData dataWithBytes:bytes length:sizeof(uuid_t)], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static void revenant_uuid_load(NSUUID *uuid, uuid_t bytes)
{
    NSData *stored = objc_getAssociatedObject(uuid, &RevenantUUIDBytesKey);
    if (stored.length == sizeof(uuid_t))
        memcpy(bytes, stored.bytes, sizeof(uuid_t));
    else
        memset(bytes, 0, sizeof(uuid_t));
}

@interface NSUUID (RevenantCore) <NSCopying, NSSecureCoding>
@end

@implementation NSUUID (RevenantCore)

+ (instancetype)UUID
{
    return [[self alloc] init];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init])) {
        uuid_t bytes;
        uuid_generate_random(bytes);
        revenant_uuid_store(self, bytes);
    }
    return self;
}

- (instancetype)initWithUUIDString:(NSString *)string
{
    if (!(self = [self init]))
        return nil;
    uuid_t bytes;
    const char *characters = string.UTF8String;
    if (!characters || uuid_parse(characters, bytes) != 0)
        return nil;
    revenant_uuid_store(self, bytes);
    return self;
}

- (instancetype)initWithUUIDBytes:(const uuid_t)bytes
{
    if (!(self = [self init]))
        return nil;
    uuid_t copy;
    if (bytes)
        memcpy(copy, bytes, sizeof(uuid_t));
    else
        memset(copy, 0, sizeof(uuid_t));
    revenant_uuid_store(self, copy);
    return self;
}

- (void)getUUIDBytes:(uuid_t)bytes
{
    revenant_uuid_load(self, bytes);
}

- (NSString *)UUIDString
{
    uuid_t bytes;
    revenant_uuid_load(self, bytes);
    uuid_string_t text;
    uuid_unparse_upper(bytes, text);
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
