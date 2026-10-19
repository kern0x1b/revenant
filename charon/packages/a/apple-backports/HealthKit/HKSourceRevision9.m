// HKSourceRevision and HKDeletedObject: which revision of which source wrote an object, and that an
// object of the store is gone. Both arrived in iOS 9.0, so both are files of their own.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

// The 11.0 members' storage, added here beside the 9.0 one's: the properties that read them are in
// HKWorkoutRoute110.m, of the release that declares them, and the port's own accessors below are what
// reach it from this file.
@implementation HKSourceRevision {
    HKSource *_source;
    NSString *_version;
    NSString *_charonProductType;
    NSOperatingSystemVersion _charonOperatingSystemVersion;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

// The port's own constructor, which the 11.0 initialiser of the class goes through, so that the two
// release's forms share one path and the facts of the 9.0 one are set in one place.
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
// iOS 11.0 added -productType and -operatingSystemVersion, and this delivery carries the 9.0 group,
// so both are @dynamic and the compiler emits no accessor for either.
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
    // The two members of 11.0, which -encodeWithCoder: below writes under these four keys and which
    // this was not reading, so an archive round trip lost them: measured by
    // tests/backports/host/healthkit, where the round trip answered nil and 0 for a product type and
    // an operating system version this port had been given iPhone and 15 for.
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

// The version of the source, which the header says is taken from the source's CFBundleVersion and
// "may be nil for older data". Nil stays nil, so a caller can tell a source that reported no version
// from one that reported an empty one.
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
// iOS 11.0 added -metadata, and this delivery carries the 9.0 group, so the member is @dynamic and
// the compiler emits no accessor for it.
@dynamic metadata;


+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The store makes one of these for every object it removed, out of its own deleted table, so that an
// anchored query can hand an application the identifier of what is gone as the release hands it an
// HKDeletedObject rather than a bare UUID.
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

// 11.0's metadata, read by the property of that name in HKWorkoutRoute110.m
- (nullable NSDictionary<NSString *, id> *)charon_deletedMetadata
{
    return _charonDeletedMetadata;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKDeletedObject %@", _UUID.UUIDString];
}

@end
