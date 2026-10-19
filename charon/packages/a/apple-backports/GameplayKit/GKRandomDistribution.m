// GKRandomDistribution.m -- the three distributions: the uniform one, the gaussian one and the
// shuffled one. Every one of them draws through the GKRandom protocol of the source it was given,
// and which protocol methods it calls was measured on the host with a source that logs them, by
// tests/backports/host/gameplaykit-core/measure.m:
//
//   -init and the range it builds are the degenerate distribution over 0 and 0, measured, and an
//   inverted range is kept rather than refused, measured.
//   GKRandomDistribution -nextIntWithUpperBound: asks the source for the range itself
//     ([source nextIntWithUpperBound:numberOfPossibleOutcomes]) and adds the lowest value;
//     -nextUniform is that integer over the highest value, so a d20 is quantised in steps of 1/20
//     exactly as its header says, and its range is [lowest / highest, 1.0] as the header says;
//     -nextBool is the source's own -nextBool; and -nextIntWithUpperBound: with a bound above the
//     range asks the source for no more than the range, so a bound of 3 over [2, 7] asks for 2, and a
//     bound of exactly 0 asks for the whole range whatever the lowest is.
//
//   GKGaussianDistribution -nextInt asks the source for two uniforms and applies the Box-Muller
//     transform to them, z = sqrt(-2 ln u1) cos(2 pi u2), and rounds mean + deviation * z, clamped
//     to the range. Over a source seeded with 1, whose first two uniforms are 0.0000895261837 and
//     0.731953204, that gives 9 for both (10, 2) and (10.5, 19/6), measured.
//
//   GKShuffledDistribution keeps a bag of every value in the range, shuffles it forward with a
//     Fisher-Yates that asks the source for bounds 1, 2, 3 ... and hands the values out from the
//     back of the bag, refilling it when it is empty. Measured: over a source that answers those
//     bounds 0, 1, 1, 1, 4, 5 it answers 6, 5, 3, 2, 4, 1, then 6, 3, 5, 4, 2, 1 for the bounds
//     0, 1, 2, 2, 3, 5, then 5, 1 for 0, 0, 2, 1, 3, 3. The shuffle happens on the first draw, not
//     at init and not on -nextBool.
//
// Every property these three declare is readonly and is answered from an ivar this file keeps with a
// getter of the class's own, so clang auto-synthesizes none and the pragma the archived version
// silenced -Wobjc-missing-property-synthesis with is gone with the thing it hid.

#import "CharonGK.h"

@implementation GKRandomDistribution {
    id<GKRandom> _source;
    NSInteger _lowest;
    NSInteger _highest;
}

// The range is kept as it was given, with nothing checked: an inverted range (lowest 5, highest 1)
// is a distribution whose -numberOfPossibleOutcomes wraps to (NSUInteger)(1 - 5) + 1, which is what
// the host answers, and the archived version of this file raised NSInvalidArgumentException at init
// instead -- a rule of its own that the host does not have and that turned a measurable answer into
// an error. Measured: lowest 5, highest 1, 18446744073709551613 outcomes, -nextInt 5, -nextUniform 5.
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

// A distribution with no range of its own is the degenerate one, over 0 and 0: one outcome, and a
// -nextUniform of nan because it divides its own lowest by itself. Measured.
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

// A bound below the range is the error the host raises, with the host's own reason. Above it, the
// span asked of the source is the bound less the lowest, never more than the whole range -- except
// that a bound of exactly zero asks for the WHOLE range, which is the one rule the archived version
// did not have: it asked for `bound - lowest`, which over a range whose lowest is below zero is a
// number below the whole range. Measured with a source that logs what it is asked, one call per
// source, over the ranges -2..2, 0..2, 2..5 and 3..3 and every bound from 0 to 8:
//   over -2..2 (five outcomes) the bounds 0..8 ask for 5, 3, 4, 5, 5, 5, 5, 5, 5
//   over  0..2 (three outcomes) the bounds 0..8 ask for 3, 1, 2, 3, 3, 3, 3, 3, 3
//   over  2..5 (four outcomes) the bounds 0 and 1 raise and the bounds 2..8 ask for 0, 1, 2, 3, 4, 4, 4
// and every one of those is `bound == 0 ? the whole range : min(bound - lowest, the whole range)`.
// The answer is that draw added to the lowest, and to nothing when the lowest is below zero, so that
// a range below zero still answers inside its own range: with a source that answers 3 over -2..2, a
// bound of 2 answers 3 and not 1.
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

// A gaussian over a range sets the two parameters the way its header spells out: the mean is the
// middle of the range and the deviation a sixth of it, so three deviations reach both ends.
- (instancetype)initWithRandomSource:(id<GKRandom>)source lowestValue:(NSInteger)lowestInclusive highestValue:(NSInteger)highestInclusive
{
    self = [super initWithRandomSource:source lowestValue:lowestInclusive highestValue:highestInclusive];
    if (self) {
        _mean = (float)((lowestInclusive + highestInclusive) / 2.0);
        _deviation = (float)(highestInclusive - lowestInclusive) / 6.0f;
    }
    return self;
}

// A gaussian given its mean and deviation runs over mean +/- 3 deviations, which is the whole of a
// gaussian as far as this framework is concerned: its header says values beyond three deviations
// are dropped from the output set as too improbable to keep.
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
    // Box-Muller: the first uniform is the radius of the point on the unit circle and the second
    // its angle, and its distance from the origin is one normal deviate. A uniform of exactly zero
    // has no angle and no radius, so it is lifted off the origin rather than turned into infinity.
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
    // The bag is refilled when it has run out, not when it has never been made: a pass of the whole
    // range is one shuffle, and the next value starts a new one, which is what the host's own log
    // of the bounds it asks its source shows -- six draws of a d6 ask for 1 to 6 once, the next six
    // ask for 1 to 6 again, and so on.
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