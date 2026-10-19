// MPSMatrixRandom, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


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

// The two generators share one construction. -initWithDevice: is unavailable on MPSMatrixRandom itself
// because a random kernel is always one of the two subclasses, and this is how each of them reaches
// MPSKernel's own initialiser: it is in the init family, so it may build the object.
- (id)initWithDevice:(id<MTLDevice>)device charonRandom:(BOOL)philox
{
    if ((self = [super initWithDevice:device]))
        _philox = philox;
    return self;
}

// What the two generators share after that: the data type, the distribution and the seed. A caller that
// changes the data type or the distribution after the kernel is made gets a kernel that draws from the
// new ones with the same seed, which is what the release's own properties do.
- (id)charon_mps_configureWithDataType:(MPSDataType)dataType
                                  seed:(uint32_t)seed
                            distribution:(MPSMatrixRandomDistributionDescriptor *)distribution
{
    if (dataType != MPSDataTypeUInt32 && dataType != MPSDataTypeFloat32) {
        CharonMPSRefuse(@"MPSMatrixRandom: a destination of data type %u is neither MPSDataTypeUInt32 nor MPSDataTypeFloat32, which are the two this kernel writes", (unsigned)dataType);
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

// Philox4x32-10, the counter based generator of Salmon, Moraes, Dror and Shaw: two 32 bit multipliers,
// a Weyl sequence on the key and ten rounds. The counter is (0, 0, 0, block) for the caller's seed as
// the key's first word, and the four words of a block are four consecutive elements of the stream.
// Measured against the release's own MPSMatrixRandomPhilox, which produces exactly this, for the seeds
// and the lengths in tests/backports/host/mpsmatrix/run.sh.
static inline void CharonMPSPhiloxBlock(uint32_t block, uint32_t seed, uint32_t out[4])
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

// The Mersenne Twister of Matsumoto and Nishimura, the recurrence MTGP32 belongs to: the same 624 word
// state and the same tempering, seeded from the caller's word. See facts/MetalPerformanceShaders/Solve.md
// for what this does and does not reproduce of the release's own MTGP32 stream.
static inline uint32_t CharonMPSMersenne(uint32_t state[624], NSUInteger *index)
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

static void CharonMPSMersenneSeed(uint32_t state[624], uint32_t seed)
{
    state[0] = seed;
    for (NSUInteger i = 1; i < 624; i++)
        state[i] = (uint32_t)(1812433253u * (state[i - 1] ^ (state[i - 1] >> 30)) + i);
}

// The value a random word takes for a distribution, in the release's own arithmetic: the default
// distribution hands the word over untouched, a uniform one takes the top 23 bits as a fraction and
// scales it into the range, and a normal one takes the inverse normal of that fraction. The uniform's
// scale and add are done once, at the precision of the expression, which is what the release's own
// lerp does and what the differential's bits confirm.
static inline double CharonMPSRandomValue(MPSMatrixRandomDistribution type, uint32_t word, double minimum, double maximum, double mean, double standardDeviation)
{
    if (type == MPSMatrixRandomDistributionDefault)
        return (double)word;
    double t = (double)(word >> 9) * (1.0 / 8388608.0);
    if (type == MPSMatrixRandomDistributionUniform)
        return minimum + (maximum - minimum) * t;
    return mean + standardDeviation * CharonMPSInverseNormal(t);
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

// One word of the stream, by position. Philox is counter based and so can be asked for any position
// directly, which is what lets a batch range start in the middle of a destination; the Mersenne
// Twister can only be walked, so the state is advanced to the batch's first word and then runs on.
- (uint32_t)charon_mps_wordAtIndex:(NSUInteger)index
{
    if (_philox) {
        uint32_t block[4];
        CharonMPSPhiloxBlock(index / 4, _seed, block);
        return block[index % 4];
    }
    if (!_mersenneSeeded) {
        CharonMPSMersenneSeed(_mersenne, _seed);
        _mersenneIndex = 624;
        _mersenneSeeded = YES;
        _mersenneDrawn = 0;
    }
    while (_mersenneDrawn <= index)
        _mersenneHeld = CharonMPSMersenne(_mersenne, &_mersenneIndex), _mersenneDrawn++;
    return _mersenneHeld;
}

// The batch a random kernel walks is its destination's batch dimension - the matrices of an MPSMatrix,
// the vectors of an MPSVector - and within the batch the elements are the destination's own order. A
// batchSize of zero, or a range past the end, is the whole of it, as the headers say.
- (void)charon_mps_batchOver:(NSUInteger)available first:(NSUInteger *)first count:(NSUInteger *)count
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
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSVectorView out = CharonMPSVectorViewOf(destinationVector);
    NSUInteger first, count;
    [self charon_mps_batchOver:out.vectors first:&first count:&count];
    for (NSUInteger vector = first; vector < first + count; vector++) {
        for (NSUInteger component = 0; component < out.length; component++) {
            uint32_t word = [self charon_mps_wordAtIndex:vector * out.length + component];
            void *element = CharonMPSVectorElement(&out, vector, component);
            if (out.dataType == MPSDataTypeUInt32)
                CharonMPSStore(element, out.dataType, 0, (double)word);
            else
                CharonMPSStore(element, out.dataType, 0, CharonMPSRandomValue(_distributionType, word, _minimum, _maximum, _mean, _standardDeviation));
        }
    }
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer destinationMatrix:(MPSMatrix *)destinationMatrix
{
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    CharonMPSMatrixView out = CharonMPSMatrixViewOf(destinationMatrix);
    NSUInteger first, count;
    [self charon_mps_batchOver:out.matrices first:&first count:&count];
    for (NSUInteger matrix = first; matrix < first + count; matrix++) {
        for (NSUInteger row = 0; row < out.rows; row++) {
            for (NSUInteger column = 0; column < out.columns; column++) {
                NSUInteger index = (matrix * out.rows + row) * out.columns + column;
                uint32_t word = [self charon_mps_wordAtIndex:index];
                void *element = CharonMPSMatrixElement(&out, matrix, row, column);
                if (out.dataType == MPSDataTypeUInt32)
                    CharonMPSStore(element, out.dataType, 0, (double)word);
                else
                    CharonMPSStore(element, out.dataType, 0, CharonMPSRandomValue(_distributionType, word, _minimum, _maximum, _mean, _standardDeviation));
            }
        }
    }
}

@end
