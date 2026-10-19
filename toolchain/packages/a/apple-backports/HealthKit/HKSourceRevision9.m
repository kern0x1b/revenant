#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKSourceRevision {
    HKSource *_source;
    NSString *_version;
    NSString *_charonProductType;
    NSOperatingSystemVersion _charonOperatingSystemVersion;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

- (instancetype)charon_initWithSource:(HKSource *)source version:(nullable NSString *)version
{
    return [self initWithSource:source version:version];
}

- (void)charon_setProductType:(nullable NSString *)productType
         operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion
{
    _charonProductType = [productType copy];
    _charonOperatingSystemVersion = operatingSystemVersion;
}

- (nullable NSString *)charon_storedProductType
{
    return _charonProductType;
}

- (NSOperatingSystemVersion)charon_storedOperatingSystemVersion
{
    return _charonOperatingSystemVersion;
}
@dynamic productType;
@dynamic operatingSystemVersion;


+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithSource:(HKSource *)source version:(nullable NSString *)version
{
    if (![source isKindOfClass:[HKSource class]]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ is not a source; a source revision is a revision of a source.", source];
        return nil;
    }
    HKSourceRevision *revision = [super init];
    if (revision) {
        revision->_source = (HKSource *)[source copy];
        revision->_version = [version copy];
    }
    return revision;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKSource *source = [coder decodeObjectOfClass:[HKSource class] forKey:@"source"];
    NSString *version = [coder decodeObjectOfClass:[NSString class] forKey:@"version"];
    NSString *productType = [coder decodeObjectOfClass:[NSString class] forKey:@"productType"];
    NSOperatingSystemVersion operatingSystem = {
        (NSInteger)[coder decodeDoubleForKey:@"osMajor"],
        (NSInteger)[coder decodeDoubleForKey:@"osMinor"],
        (NSInteger)[coder decodeDoubleForKey:@"osPatch"]
    };
    HKSourceRevision *revision = [self initWithSource:source ?: [HKSource charon_sourceWithName:@"" bundleIdentifier:@""]
                                             version:version];
    if (revision)
        [revision charon_setProductType:productType operatingSystemVersion:operatingSystem];
    return revision;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_source forKey:@"source"];
    [coder encodeObject:_version forKey:@"version"];
    [coder encodeObject:_charonProductType forKey:@"productType"];
    [coder encodeDouble:(double)_charonOperatingSystemVersion.majorVersion forKey:@"osMajor"];
    [coder encodeDouble:(double)_charonOperatingSystemVersion.minorVersion forKey:@"osMinor"];
    [coder encodeDouble:(double)_charonOperatingSystemVersion.patchVersion forKey:@"osPatch"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[HKSourceRevision alloc] initWithSource:_source version:_version];
}

- (HKSource *)source
{
    return _source;
}

- (nullable NSString *)version
{
    return _version;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKSourceRevision class]])
        return NO;
    HKSourceRevision *that = other;
    return [_source isEqual:that.source] && (_version == that.version || [_version isEqualToString:that.version]);
}

- (NSUInteger)hash
{
    return _source.hash ^ _version.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKSourceRevision[%@ %@]", _source, _version];
}

@end

#pragma mark - HKDeletedObject

@implementation HKDeletedObject {
    NSUUID *_UUID;
    NSDictionary *_charonDeletedMetadata;
}
@dynamic metadata;


+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)charon_initWithUUID:(NSUUID *)uuid
{
    HKDeletedObject *deleted = [super init];
    if (deleted)
        deleted->_UUID = [uuid copy];
    return deleted;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKDeletedObject *deleted = [super init];
    if (deleted)
        deleted->_UUID = [[coder decodeObjectOfClass:[NSUUID class] forKey:@"UUID"] copy];
        NSDictionary *metadata = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class],
                                                                            [NSNumber class], [NSDate class], [NSData class], nil]
                                                forKey:@"deletedMetadata"];
        deleted->_charonDeletedMetadata = [metadata copy];
    return deleted;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_UUID forKey:@"UUID"];
    [coder encodeObject:_charonDeletedMetadata forKey:@"deletedMetadata"];
}

- (NSUUID *)UUID
{
    return _UUID;
}

- (nullable NSDictionary<NSString *, id> *)charon_deletedMetadata
{
    return _charonDeletedMetadata;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKDeletedObject %@", _UUID.UUIDString];
}

@end
