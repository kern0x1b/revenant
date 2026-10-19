#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKObject {
    NSUUID *_UUID;
    HKSource *_source;
    NSDictionary *_metadata;
    HKCorrelation *_correlation;
    HKSourceRevision *_storedSourceRevision;
    HKDevice *_storedDevice;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)charon_initWithUUID:(NSUUID *)uuid source:(HKSource *)source metadata:(NSDictionary *)metadata
{
    HKObject *fresh = [super init];
    if (fresh) {
        fresh->_UUID = [uuid copy] ?: [[NSUUID UUID] copy];
        fresh->_source = (HKSource *)[source copy];
        fresh->_metadata = [metadata copy];
    }
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSUUID *uuid = [coder decodeObjectOfClass:[NSUUID class] forKey:@"UUID"];
    HKSource *source = [coder decodeObjectOfClass:[HKSource class] forKey:@"source"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSNumber class], [NSDate class], [HKQuantity class], nil];
    NSDictionary *metadata = [coder decodeObjectOfClasses:classes forKey:@"metadata"];
    return [self charon_initWithUUID:uuid source:source metadata:metadata];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_UUID forKey:@"UUID"];
    [coder encodeObject:_source forKey:@"source"];
    [coder encodeObject:_metadata forKey:@"metadata"];
}

- (instancetype)charon_copyForStore
{
    return [self charon_initWithUUID:_UUID source:_source metadata:_metadata];
}

- (NSUUID *)UUID
{
    return _UUID;
}

- (HKSource *)source
{
    return _source;
}

- (NSDictionary *)metadata
{
    return _metadata;
}

- (nullable HKCorrelation *)charon_correlation
{
    return _correlation;
}

- (void)charon_setCorrelation:(nullable HKCorrelation *)correlation
{
    _correlation = correlation;
}

- (void)charon_setDevice:(nullable HKDevice *)device
{
    _storedDevice = device;
}

- (nullable HKDevice *)charon_storedDevice
{
    return _storedDevice;
}

- (nullable HKSourceRevision *)charon_storedSourceRevision
{
    return _storedSourceRevision;
}

- (void)charon_setStoredSourceRevision:(nullable HKSourceRevision *)revision
{
    _storedSourceRevision = revision;
}

#pragma mark - The store

- (NSString *)charon_storeTypeIdentifier
{
    return @"";
}

- (NSInteger)charon_storeKind
{
    return 0;
}

- (NSData *)charon_storeArchive
{
    return [NSKeyedArchiver archivedDataWithRootObject:self];
}

+ (instancetype)charon_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(CharonHKStore *)store
{
    if (!archive.length || ![self supportsSecureCoding])
        return nil;
    NSKeyedUnarchiver *coder = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    id object = [coder decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [coder finishDecoding];
    return object;
}

- (instancetype)charon_objectWithCoder:(NSCoder *)coder
{
    return [self initWithCoder:coder];
}

#pragma mark - Describing

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@", NSStringFromClass(self.class), _UUID.UUIDString];
}

@end
