#import "RevenantHomeKitInternal.h"

#pragma mark - HMNumberRange

@interface HMNumberRange (RevenantHomeKitStore)
@property (nonatomic, strong, nullable) NSNumber *revenant_minValue;
@property (nonatomic, strong, nullable) NSNumber *revenant_maxValue;
@end

@implementation HMNumberRange

@synthesize revenant_minValue = _revenant_minValue, revenant_maxValue = _revenant_maxValue;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    (void)store;
    (void)identifier;
    self = [super init];
    return self;
}

+ (instancetype)numberRangeWithMinValue:(NSNumber *)minValue maxValue:(NSNumber *)maxValue
{
    HMNumberRange *range = [[HMNumberRange alloc] revenant_initWithStore:nil identifier:nil];
    range.revenant_minValue = minValue;
    range.revenant_maxValue = maxValue;
    return range;
}

- (NSNumber *)minValue
{
    return [_revenant_minValue copy];
}

- (NSNumber *)maxValue
{
    return [_revenant_maxValue copy];
}

@end

HMNumberRange *RevenantHomeKitNumberRange(NSNumber *minimum, NSNumber *maximum)
{
    return [HMNumberRange numberRangeWithMinValue:minimum maxValue:maximum];
}
