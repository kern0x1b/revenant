#import "RevenantMPS.h"


@implementation MPSMatrixRandom {
    MPSDataType _destinationDataType;
    MPSMatrixRandomDistribution _distributionType;
    NSUInteger _batchStart, _batchSize;
    double _minimum, _maximum, _mean, _standardDeviation;
    uint32_t _seed;
    BOOL _philox;
    uint32_t _mersenne[624];
    NSUInteger _mersenneIndex;
    BOOL _mersenneSeeded;
    NSUInteger _mersenneDrawn;
    uint32_t _mersenneHeld;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSMatrixRandom: -initWithDevice: is not a generator; use MPSMatrixRandomPhilox or MPSMatrixRandomMTGP32");
    return nil;
}

- (id)initWithDevice:(id<MTLDevice>)device revenantRandom:(BOOL)philox
{
    if ((self = [super initWithDevice:device]))
        _philox = philox;
    return self;
}

- (id)revenant_mps_configureWithDataType:(MPSDataType)dataType
                                  seed:(uint32_t)seed
                            distribution:(MPSMatrixRandomDistributionDescriptor *)distribution
{
    if (dataType != MPSDataTypeUInt32 && dataType != MPSDataTypeFloat32) {
        RevenantMPSRefuse(@"MPSMatrixRandom: a destination of data type %u is neither MPSDataTypeUInt32 nor MPSDataTypeFloat32, which are the two this kernel writes", (unsigned)dataType);
        return nil;
    }
    _destinationDataType = dataType;
    _seed = seed;
    _mersenneSeeded = NO;
    if (distribution) {
        _distributionType = distribution.distributionType;
        _minimum = distribution.minimum;
        _maximum = distribution.maximum;
        _mean = distribution.mean;
        _standardDeviation = distribution.standardDeviation;
    } else {
        _distributionType = MPSMatrixRandomDistributionDefault;
    }
    return self;
}

static inline void RevenantMPSPhiloxBlock(uint32_t block, uint32_t seed, uint32_t out[4])
{
    uint32_t c0 = 0, c1 = 0, c2 = 0, c3 = block;
    uint32_t k0 = seed, k1 = 0;
    for (int round = 0; round < 10; round++) {
        uint64_t low0 = (uint64_t)c0 * 0xD2511F53u;
        uint64_t low1 = (uint64_t)c2 * 0xCD9E8D57u;
        uint32_t hi0 = (uint32_t)(low0 >> 32), lo0 = (uint32_t)low0;
        uint32_t hi1 = (uint32_t)(low1 >> 32), lo1 = (uint32_t)low1;
        uint32_t n0 = hi1 ^ c1 ^ k0, n1 = lo1, n2 = hi0 ^ c3 ^ k1, n3 = lo0;
        c0 = n0; c1 = n1; c2 = n2; c3 = n3;
        k0 += 0x9E3779B9u;
        k1 += 0xBB67AE85u;
    }
    out[0] = c0;
    out[1] = c1;
    out[2] = c2;
    out[3] = c3;
}

static inline uint32_t RevenantMPSMersenne(uint32_t state[624], NSUInteger *index)
{
    if (*index >= 624) {
        for (NSUInteger i = 0; i < 624; i++) {
            uint32_t y = (state[i] & 0x80000000u) | (state[(i + 1) % 624] & 0x7fffffffu);
            state[i] = state[(i + 397) % 624] ^ (y >> 1) ^ ((y & 1) ? 0x9908B0DFu : 0u);
        }
        *index = 0;
    }
    uint32_t y = state[*index];
    *index = *index + 1;
    y ^= y >> 11;
    y ^= (y << 7) & 0x9D2C5680u;
    y ^= (y << 15) & 0xEFC60000u;
    y ^= y >> 18;
    return y;
}

static void RevenantMPSMersenneSeed(uint32_t state[624], uint32_t seed)
{
    state[0] = seed;
    for (NSUInteger i = 1; i < 624; i++)
        state[i] = (uint32_t)(1812433253u * (state[i - 1] ^ (state[i - 1] >> 30)) + i);
}

static inline double RevenantMPSRandomValue(MPSMatrixRandomDistribution type, uint32_t word, double minimum, double maximum, double mean, double standardDeviation)
{
    if (type == MPSMatrixRandomDistributionDefault)
        return (double)word;
    double t = (double)(word >> 9) * (1.0 / 8388608.0);
    if (type == MPSMatrixRandomDistributionUniform)
        return minimum + (maximum - minimum) * t;
    return mean + standardDeviation * RevenantMPSInverseNormal(t);
}

- (MPSDataType)destinationDataType
{
    return _destinationDataType;
}

- (MPSMatrixRandomDistribution)distributionType
{
    return _distributionType;
}

- (NSUInteger)batchStart
{
    return _batchStart;
}

- (void)setBatchStart:(NSUInteger)batchStart
{
    _batchStart = batchStart;
}

- (NSUInteger)batchSize
{
    return _batchSize;
}

- (void)setBatchSize:(NSUInteger)batchSize
{
    _batchSize = batchSize;
}

- (uint32_t)revenant_mps_wordAtIndex:(NSUInteger)index
{
    if (_philox) {
        uint32_t block[4];
        RevenantMPSPhiloxBlock(index / 4, _seed, block);
        return block[index % 4];
    }
    if (!_mersenneSeeded) {
        RevenantMPSMersenneSeed(_mersenne, _seed);
        _mersenneIndex = 624;
        _mersenneSeeded = YES;
        _mersenneDrawn = 0;
    }
    while (_mersenneDrawn <= index)
        _mersenneHeld = RevenantMPSMersenne(_mersenne, &_mersenneIndex), _mersenneDrawn++;
    return _mersenneHeld;
}

- (void)revenant_mps_batchOver:(NSUInteger)available first:(NSUInteger *)first count:(NSUInteger *)count
{
    NSUInteger begin = _batchStart < available ? _batchStart : available;
    NSUInteger end = available;
    if (_batchSize && begin + _batchSize < end)
        end = begin + _batchSize;
    *first = begin;
    *count = end - begin;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer destinationVector:(MPSVector *)destinationVector
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSVectorView out = RevenantMPSVectorViewOf(destinationVector);
    NSUInteger first, count;
    [self revenant_mps_batchOver:out.vectors first:&first count:&count];
    for (NSUInteger vector = first; vector < first + count; vector++) {
        for (NSUInteger component = 0; component < out.length; component++) {
            uint32_t word = [self revenant_mps_wordAtIndex:vector * out.length + component];
            void *element = RevenantMPSVectorElement(&out, vector, component);
            if (out.dataType == MPSDataTypeUInt32)
                RevenantMPSStore(element, out.dataType, 0, (double)word);
            else
                RevenantMPSStore(element, out.dataType, 0, RevenantMPSRandomValue(_distributionType, word, _minimum, _maximum, _mean, _standardDeviation));
        }
    }
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer destinationMatrix:(MPSMatrix *)destinationMatrix
{
    if (!RevenantMPSCommandBufferPermits(commandBuffer))
        return;
    RevenantMPSMatrixView out = RevenantMPSMatrixViewOf(destinationMatrix);
    NSUInteger first, count;
    [self revenant_mps_batchOver:out.matrices first:&first count:&count];
    for (NSUInteger matrix = first; matrix < first + count; matrix++) {
        for (NSUInteger row = 0; row < out.rows; row++) {
            for (NSUInteger column = 0; column < out.columns; column++) {
                NSUInteger index = (matrix * out.rows + row) * out.columns + column;
                uint32_t word = [self revenant_mps_wordAtIndex:index];
                void *element = RevenantMPSMatrixElement(&out, matrix, row, column);
                if (out.dataType == MPSDataTypeUInt32)
                    RevenantMPSStore(element, out.dataType, 0, (double)word);
                else
                    RevenantMPSStore(element, out.dataType, 0, RevenantMPSRandomValue(_distributionType, word, _minimum, _maximum, _mean, _standardDeviation));
            }
        }
    }
}

@end
