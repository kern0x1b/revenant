// MPSMatrixRandomDistributionDescriptor, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


@implementation MPSMatrixRandomDistributionDescriptor {
    MPSMatrixRandomDistribution _distributionType;
    float _minimum, _maximum, _mean, _standardDeviation;
}

+ (MPSMatrixRandomDistributionDescriptor *)uniformDistributionDescriptorWithMinimum:(float)minimum maximum:(float)maximum
{
    MPSMatrixRandomDistributionDescriptor *descriptor = [[self alloc] init];
    descriptor->_distributionType = MPSMatrixRandomDistributionUniform;
    descriptor->_minimum = minimum;
    descriptor->_maximum = maximum;
    // A uniform distribution over [minimum, maximum] has its mean at the middle and its standard
    // deviation the width over the square root of twelve, which is the variance (width squared over
    // twelve) the distribution's own moments give. The release fills both in as well, measured.
    descriptor->_mean = (minimum + maximum) * 0.5f;
    descriptor->_standardDeviation = (float)((maximum - minimum) / 3.4641016151377544);
    return descriptor;
}

+ (MPSMatrixRandomDistributionDescriptor *)normalDistributionDescriptorWithMean:(float)mean standardDeviation:(float)standardDeviation
{
    return [self normalDistributionDescriptorWithMean:mean standardDeviation:standardDeviation minimum:-INFINITY maximum:INFINITY];
}

+ (MPSMatrixRandomDistributionDescriptor *)normalDistributionDescriptorWithMean:(float)mean standardDeviation:(float)standardDeviation minimum:(float)minimum maximum:(float)maximum
{
    MPSMatrixRandomDistributionDescriptor *descriptor = [[self alloc] init];
    descriptor->_distributionType = MPSMatrixRandomDistributionNormal;
    descriptor->_mean = mean;
    descriptor->_standardDeviation = standardDeviation;
    descriptor->_minimum = minimum;
    descriptor->_maximum = maximum;
    return descriptor;
}

+ (MPSMatrixRandomDistributionDescriptor *)defaultDistributionDescriptor
{
    MPSMatrixRandomDistributionDescriptor *descriptor = [[self alloc] init];
    descriptor->_distributionType = MPSMatrixRandomDistributionDefault;
    return descriptor;
}

- (MPSMatrixRandomDistribution)distributionType
{
    return _distributionType;
}

- (void)setDistributionType:(MPSMatrixRandomDistribution)distributionType
{
    _distributionType = distributionType;
}

- (float)minimum
{
    return _minimum;
}

- (void)setMinimum:(float)minimum
{
    _minimum = minimum;
}

- (float)maximum
{
    return _maximum;
}

- (void)setMaximum:(float)maximum
{
    _maximum = maximum;
}

- (float)mean
{
    return _mean;
}

- (void)setMean:(float)mean
{
    _mean = mean;
}

- (float)standardDeviation
{
    return _standardDeviation;
}

- (void)setStandardDeviation:(float)standardDeviation
{
    _standardDeviation = standardDeviation;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPSMatrixRandomDistributionDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy->_distributionType = _distributionType;
    copy->_minimum = _minimum;
    copy->_maximum = _maximum;
    copy->_mean = _mean;
    copy->_standardDeviation = _standardDeviation;
    return copy;
}

@end
