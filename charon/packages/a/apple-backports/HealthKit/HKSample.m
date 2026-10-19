#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKSample {
    HKSampleType *_sampleType;
    NSDate *_startDate;
    NSDate *_endDate;
}
@dynamic hasUndeterminedDuration;


+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)charon_initWithType:(HKSampleType *)sampleType
                           metadata:(NSDictionary *)metadata
                          startDate:(NSDate *)startDate
                            endDate:(NSDate *)endDate
{
    HKSample *fresh = [super charon_initWithUUID:[[NSUUID UUID] copy] source:[HKSource defaultSource] metadata:metadata];
    if (fresh) {
        fresh->_sampleType = (HKSampleType *)[sampleType copy];
        fresh->_startDate = [startDate copy];
        fresh->_endDate = [endDate copy];
    }
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKSample *sample = [super initWithCoder:coder];
    if (sample) {
        sample->_sampleType = [[coder decodeObjectOfClass:[HKSampleType class] forKey:@"sampleType"] copy];
        sample->_startDate = [[coder decodeObjectOfClass:[NSDate class] forKey:@"startDate"] copy];
        sample->_endDate = [[coder decodeObjectOfClass:[NSDate class] forKey:@"endDate"] copy];
    }
    return sample;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_sampleType forKey:@"sampleType"];
    [coder encodeObject:_startDate forKey:@"startDate"];
    [coder encodeObject:_endDate forKey:@"endDate"];
}

- (instancetype)charon_copyForStore
{
    HKSample *copy = [super charon_copyForStore];
    if (copy) {
        copy->_sampleType = [self->_sampleType copy];
        copy->_startDate = [self->_startDate copy];
        copy->_endDate = [self->_endDate copy];
    }
    return copy;
}

- (HKSampleType *)sampleType
{
    return _sampleType;
}

- (NSDate *)startDate
{
    return _startDate;
}

- (NSDate *)endDate
{
    return _endDate;
}

- (NSString *)charon_storeTypeIdentifier
{
    return _sampleType.identifier ?: @"";
}

- (HKObjectType *)charon_typeForSaving
{
    return _sampleType;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@ from %@ to %@", NSStringFromClass(self.class), _sampleType.identifier,
                                      _startDate, _endDate];
}

@end
