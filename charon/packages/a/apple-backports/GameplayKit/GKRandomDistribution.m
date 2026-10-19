#import "CharonGK.h"

@implementation GKRandomDistribution {
    id<GKRandom> _source;
    NSInteger _lowest;
    NSInteger _highest;
}

- (instancetype)initWithRandomSource:(id<GKRandom>)source lowestValue:(NSInteger)lowestInclusive highestValue:(NSInteger)highestInclusive
{
    self = [super init];
    if (self) {
        _source = source;
        _lowest = lowestInclusive;
        _highest = highestInclusive;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithRandomSource:[[GKRandomSource alloc] init] lowestValue:0 highestValue:0];
}

- (NSInteger)lowestValue
{
    return _lowest;
}

- (NSInteger)highestValue
{
    return _highest;
}

- (NSUInteger)numberOfPossibleOutcomes
{
    return (NSUInteger)(_highest - _lowest) + 1;
}

- (NSInteger)nextInt
{
    return _lowest + (NSInteger)[_source nextIntWithUpperBound:[self numberOfPossibleOutcomes]];
}

- (NSUInteger)nextIntWithUpperBound:(NSUInteger)upperBound
{
    if ((NSInteger)upperBound < _lowest) {
        [NSException raise:NSInvalidArgumentException
                    format:@"upper bound provided is less than lowestInclusive"];
        return 0;
    }
    NSInteger span = (NSInteger)upperBound == 0 ? (NSInteger)[self numberOfPossibleOutcomes]
                                               : (NSInteger)upperBound - _lowest;
    if (span > (NSInteger)[self numberOfPossibleOutcomes]) {
        span = (NSInteger)[self numberOfPossibleOutcomes];
    }
    return (NSUInteger)(MAX(_lowest, 0) + (NSInteger)[_source nextIntWithUpperBound:(NSUInteger)span]);
}

- (float)nextUniform
{
    return (float)[self nextInt] / (float)_highest;
}

- (BOOL)nextBool
{
    return [_source nextBool];
}

- (id<GKRandom>)charon_source
{
    return _source;
}

+ (instancetype)distributionWithLowestValue:(NSInteger)lowestInclusive highestValue:(NSInteger)highestInclusive
{
    return [[self alloc] initWithRandomSource:[[GKRandomSource alloc] init] lowestValue:lowestInclusive highestValue:highestInclusive];
}

+ (instancetype)distributionForDieWithSideCount:(NSInteger)sideCount
{
    return [self distributionWithLowestValue:1 highestValue:sideCount];
}

+ (instancetype)d6
{
    return [self distributionForDieWithSideCount:6];
}

+ (instancetype)d20
{
    return [self distributionForDieWithSideCount:20];
}

@end

@implementation GKGaussianDistribution {
    float _mean;
    float _deviation;
}

- (instancetype)initWithRandomSource:(id<GKRandom>)source lowestValue:(NSInteger)lowestInclusive highestValue:(NSInteger)highestInclusive
{
    self = [super initWithRandomSource:source lowestValue:lowestInclusive highestValue:highestInclusive];
    if (self) {
        _mean = (float)((lowestInclusive + highestInclusive) / 2.0);
        _deviation = (float)(highestInclusive - lowestInclusive) / 6.0f;
    }
    return self;
}

- (instancetype)initWithRandomSource:(id<GKRandom>)source mean:(float)mean deviation:(float)deviation
{
    self = [super initWithRandomSource:source
                           lowestValue:(NSInteger)lroundf(mean - 3.0f * deviation)
                           highestValue:(NSInteger)lroundf(mean + 3.0f * deviation)];
    if (self) {
        _mean = mean;
        _deviation = deviation;
    }
    return self;
}

- (float)mean
{
    return _mean;
}

- (float)deviation
{
    return _deviation;
}

- (NSInteger)nextInt
{
    id<GKRandom> source = [self charon_source];
    float first = [source nextUniform];
    float second = [source nextUniform];
    if (first < 1.0e-7f) {
        first = 1.0e-7f;
    }
    double radius = sqrt(-2.0 * log((double)first));
    double deviate = radius * cos(2.0 * M_PI * (double)second);
    long long value = llround((double)_mean + (double)_deviation * deviate);
    if (value < (long long)self.lowestValue) {
        value = (long long)self.lowestValue;
    }
    if (value > (long long)self.highestValue) {
        value = (long long)self.highestValue;
    }
    return (NSInteger)value;
}

@end

@implementation GKShuffledDistribution {
    NSMutableArray<NSNumber *> *_bag;
    NSInteger _lowest;
    NSInteger _highest;
}

- (instancetype)initWithRandomSource:(id<GKRandom>)source lowestValue:(NSInteger)lowestInclusive highestValue:(NSInteger)highestInclusive
{
    self = [super initWithRandomSource:source lowestValue:lowestInclusive highestValue:highestInclusive];
    if (self) {
        _lowest = lowestInclusive;
        _highest = highestInclusive;
    }
    return self;
}

- (NSInteger)nextInt
{
    if (![_bag count]) {
        _bag = [NSMutableArray arrayWithCapacity:(NSUInteger)(_highest - _lowest) + 1];
        for (NSInteger value = _lowest; value <= _highest; value++) {
            [_bag addObject:@(value)];
        }
        for (NSUInteger index = 0; index < [_bag count]; index++) {
            NSUInteger other = [[self charon_source] nextIntWithUpperBound:index + 1];
            [_bag exchangeObjectAtIndex:index withObjectAtIndex:other];
        }
    }
    NSNumber *value = [[_bag lastObject] copy];
    [_bag removeLastObject];
    return [value integerValue];
}

@end
