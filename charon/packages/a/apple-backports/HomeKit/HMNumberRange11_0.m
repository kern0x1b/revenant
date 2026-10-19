#import "CharonHomeKitInternal.h"

#pragma mark - HMNumberRange

@interface HMNumberRange (CharonHomeKitStore)
@property (nonatomic, strong, nullable) NSNumber *charon_minValue;
@property (nonatomic, strong, nullable) NSNumber *charon_maxValue;
@end

@implementation HMNumberRange

@synthesize charon_minValue = _charon_minValue, charon_maxValue = _charon_maxValue;

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    (void)identifier;
    self = [super init];
    return self;
}

+ (instancetype)numberRangeWithMinValue:(NSNumber *)minValue maxValue:(NSNumber *)maxValue
{
    HMNumberRange *range = [[HMNumberRange alloc] charon_initWithStore:nil identifier:nil];
    range.charon_minValue = minValue;
    range.charon_maxValue = maxValue;
    return range;
}

- (NSNumber *)minValue
{
    return [_charon_minValue copy];
}

- (NSNumber *)maxValue
{
    return [_charon_maxValue copy];
}

@end

HMNumberRange *CharonHomeKitNumberRange(NSNumber *minimum, NSNumber *maximum)
{
    return [HMNumberRange numberRangeWithMinValue:minimum maxValue:maximum];
}
