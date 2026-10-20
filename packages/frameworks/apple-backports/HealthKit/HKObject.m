#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

@implementation HKObject {
    NSUUID *_UUID;
    HKSource *_source;
    NSDictionary *_metadata;
    HKCorrelation *_correlation;
    HKSourceRevision *_storedSourceRevision;
    HKDevice *_storedDevice;
}
REVENANT_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)revenant_initWithUUID:(NSUUID *)uuid source:(HKSource *)source metadata:(NSDictionary *)metadata
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
    return [self revenant_initWithUUID:uuid source:source metadata:metadata];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_UUID forKey:@"UUID"];
    [coder encodeObject:_source forKey:@"source"];
    [coder encodeObject:_metadata forKey:@"metadata"];
}

- (instancetype)revenant_copyForStore
{
    return [self revenant_initWithUUID:_UUID source:_source metadata:_metadata];
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

- (nullable HKCorrelation *)revenant_correlation
{
    return _correlation;
}

- (void)revenant_setCorrelation:(nullable HKCorrelation *)correlation
{
    _correlation = correlation;
}

- (void)revenant_setDevice:(nullable HKDevice *)device
{
    _storedDevice = device;
}

- (nullable HKDevice *)revenant_storedDevice
{
    return _storedDevice;
}

- (nullable HKSourceRevision *)revenant_storedSourceRevision
{
    return _storedSourceRevision;
}

- (void)revenant_setStoredSourceRevision:(nullable HKSourceRevision *)revision
{
    _storedSourceRevision = revision;
}

#pragma mark - The store

- (NSString *)revenant_storeTypeIdentifier
{
    return @"";
}

- (NSInteger)revenant_storeKind
{
    return 0;
}

- (NSData *)revenant_storeArchive
{
    return [NSKeyedArchiver archivedDataWithRootObject:self];
}

+ (instancetype)revenant_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(RevenantHKStore *)store
{
    if (!archive.length || ![self supportsSecureCoding])
        return nil;
    NSKeyedUnarchiver *coder = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    id object = [coder decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [coder finishDecoding];
    return object;
}

- (instancetype)revenant_objectWithCoder:(NSCoder *)coder
{
    return [self initWithCoder:coder];
}

#pragma mark - Describing

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@", NSStringFromClass(self.class), _UUID.UUIDString];
}

@end
