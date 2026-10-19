// HMNumberRange, of iOS 11.0: the range a threshold event fires on, a value object with no identifier
// of its own. It is a class of its own in the release's headers and of its own here, because two
// files defining it is two class symbols with one name -- the link said so by name.
//
// One release's API per object file, which is what the band machinery needs.
#import "CharonHomeKitInternal.h"

#pragma mark - HMNumberRange

@interface HMNumberRange (CharonHomeKitStore)
@property (nonatomic, strong, nullable) NSNumber *charon_minValue;
@property (nonatomic, strong, nullable) NSNumber *charon_maxValue;
@end

@implementation HMNumberRange

@synthesize charon_minValue = _charon_minValue, charon_maxValue = _charon_maxValue;

// -init and +new are unavailable in the release's own header, so the range is made the way the
// release makes the objects it has no initialiser for, through its own class method; see
// CharonHomeKitConstruction.h for why the port's construction is what it is.
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
