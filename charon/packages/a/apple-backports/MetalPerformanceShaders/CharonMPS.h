// CharonMPS.h — the arithmetic the matrix and vector kernels of this framework share.
//
// Every function here is static, so no backport file depends on another one's symbols: a band that
// leaves a file out does not leave the others with undefined ones.
//
// The device these kernels run on is charon's own, whose MTLBuffer is host memory the CPU reads and
// writes directly (facts/Metal/RenderPath.md). An MPS matrix kernel is therefore a loop over that
// memory, and its result is in the buffer when -encodeToCommandBuffer: returns, which is at least as
// strong as the release's own contract (a result valid once the command buffer completes).

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

#include <math.h>
#include <string.h>

// The data types an MPSMatrix may hold, and nothing else. MPSDataTypeInvalid and the normalized and
// boolean encodings are not matrix element types: the release's MPS does not accept them here, and
// this port refuses them the same way rather than storing something of a different meaning.
static inline BOOL CharonMPSDataTypeIsElement(MPSDataType type)
{
    switch (type) {
    case MPSDataTypeFloat32:
    case MPSDataTypeFloat16:
    case MPSDataTypeInt8:
    case MPSDataTypeInt16:
    case MPSDataTypeInt32:
    case MPSDataTypeUInt8:
    case MPSDataTypeUInt16:
    case MPSDataTypeUInt32:
        return YES;
    default:
        return NO;
    }
}

static inline BOOL CharonMPSDataTypeIsFloat(MPSDataType type)
{
    return type == MPSDataTypeFloat32 || type == MPSDataTypeFloat16;
}

// IEEE 754 binary16 as MPSDataTypeFloat16 stores it, converted in software rather than through the
// compiler's __fp16: a half load and store is not available on every armv7 core this port targets,
// and a conversion that the compiler may fold is a conversion nobody measured.
static inline float CharonMPSHalfToFloat(uint16_t half)
{
    uint32_t sign = ((uint32_t)half & 0x8000u) << 16;
    uint32_t exponent = ((uint32_t)half >> 10) & 0x1Fu;
    uint32_t mantissa = (uint32_t)half & 0x3FFu;
    uint32_t bits;
    float value;
    if (exponent == 0) {
        if (mantissa == 0) {
            bits = sign;
        } else {
            // A subnormal half is mantissa * 2^-24; the highest set bit gives the exponent.
            uint32_t top = 0, rest = mantissa;
            while (rest > 1) {
                rest >>= 1;
                top++;
            }
            bits = sign | ((uint32_t)(top - 24 + 127) << 23) | ((mantissa - (1u << top)) << (23 - top));
        }
    } else if (exponent == 0x1F) {
        bits = sign | 0x7F800000u | (mantissa << 13);
    } else {
        bits = sign | ((exponent + 127 - 15) << 23) | (mantissa << 13);
    }
    memcpy(&value, &bits, sizeof(value));
    return value;
}

// Two roundings, and which of them a caller gets is its own question. `awayFromZero` rounds a value
// that is exactly halfway between two halves away from zero; without it a halfway value rounds to the
// one with an even mantissa, which is what every family here has always done and what nothing has ever
// measured otherwise. The MPSGraph family asks for the other one, because the release's own half
// arithmetic rounds a halfway case away from zero - measured on macOS 27.0 build 26A428, an addition
// of 2^-10 to 3.0 answers 0x4201 where that sum is exactly halfway between 0x4200 and 0x4201 - and
// nothing else in this package is measured to want it.
static inline uint16_t CharonMPSFloatToHalfRounded(float value, int awayFromZero)
{
    uint32_t bits, sign, mantissa, half, rest, halfway;
    int32_t biased, exponent;
    memcpy(&bits, &value, sizeof(bits));
    sign = (bits >> 16) & 0x8000u;
    biased = (int32_t)((bits >> 23) & 0xFFu);
    mantissa = bits & 0x7FFFFFu;
    if (biased == 0xFF) {
        return (uint16_t)(sign | 0x7C00u | (mantissa ? 0x200u : 0u));
    }
    exponent = biased - 127 + 15;
    if (exponent >= 0x1F) {
        return (uint16_t)(sign | 0x7C00u);
    }
    if (exponent <= 0) {
        // Below 2^-25 a value rounds to zero whatever its low bits are. From there up, the value is
        // (2^23 + mantissa) * 2^(exponent - 38), so it is an integer multiple of 2^-24 and rounding is
        // that integer's.
        if (exponent < -10) {
            return (uint16_t)sign;
        }
        mantissa |= 0x800000u;
        half = mantissa >> (14 - exponent);
        rest = mantissa & ((1u << (14 - exponent)) - 1u);
        halfway = 1u << (13 - exponent);
        if (rest > halfway || (rest == halfway && (awayFromZero || (half & 1))))
            half++;
        return (uint16_t)(sign | half);
    }
    half = ((uint32_t)exponent << 10) | (mantissa >> 13);
    rest = mantissa & 0x1FFFu;
    if (rest > 0x1000u || (rest == 0x1000u && (awayFromZero || (half & 1))))
        half++;
    return (uint16_t)(sign | half);
}

static inline uint16_t CharonMPSFloatToHalf(float value)
{
    return CharonMPSFloatToHalfRounded(value, 0);
}

// One element of a matrix, vector or state, read and written through the data type it is stored as.
// A double carries every value an 8, 16 or 32 bit element can hold exactly, so one representation
// serves the floating and the integer types alike and the arithmetic below reads the way the header
// writes it.
static inline double CharonMPSLoad(const void *bytes, MPSDataType type, size_t index)
{
    switch (type) {
    case MPSDataTypeFloat32: {
        float value;
        memcpy(&value, (const char *)bytes + index * 4, 4);
        return (double)value;
    }
    case MPSDataTypeFloat16:
        return (double)CharonMPSHalfToFloat(((const uint16_t *)bytes)[index]);
    case MPSDataTypeInt8:
        return (double)((const int8_t *)bytes)[index];
    case MPSDataTypeInt16:
        return (double)((const int16_t *)bytes)[index];
    case MPSDataTypeInt32:
        return (double)((const int32_t *)bytes)[index];
    case MPSDataTypeUInt8:
        return (double)((const uint8_t *)bytes)[index];
    case MPSDataTypeUInt16:
        return (double)((const uint16_t *)bytes)[index];
    case MPSDataTypeUInt32:
        return (double)((const uint32_t *)bytes)[index];
    // A boolean is one byte, measured: MPSSizeofMPSDataType(MPSDataTypeBool) is 1 on this host, and
    // MPSDataTypeBool is MPSDataTypeAlternateEncodingBit | 8 (MPSCoreTypes.h:260), so the alternate
    // encoding's eight bits are a byte and not a bit.
    case MPSDataTypeBool:
        return (double)((const uint8_t *)bytes)[index];
    default:
        return 0.0;
    }
}

// The store, and the narrowing of a half is the release's own rounding for the MPSGraph family and the
// even one for every other, which is why the rounding is a parameter here and not a change to it: see
// CharonMPSFloatToHalfRounded. Every other data type is written the same either way.
static inline void CharonMPSStoreRounded(void *bytes, MPSDataType type, size_t index, double value,
                                         int awayFromZero)
{
#if defined(CHARON_PLANT)
    // THE RED CONTROL. Compiled only into the harness's planted builds, never into the library: this
    // perturbs what a KERNEL writes, on its way out through the shared store, so the differential is
    // shown a wrong kernel rather than a wrong print. That distinction matters - a plant in the case
    // file only proves the comparison can read two numbers, while a plant here proves it notices when
    // the port computes the wrong thing, and it reaches every kernel in the family that stores through
    // this function, which is all of them except the two that hand a finished buffer to -writeBytes:.
    // Those two are planted at the other end, in CharonMPSImageWriteRegion.
#if CHARON_PLANT == 1
    value = value + 1.0;                // every element of every case, off by one
#elif CHARON_PLANT == 2
    if (index == 0)
        value = value + 1.0;            // the first element of each case, and the rest exactly right
#endif
#endif
    switch (type) {
    case MPSDataTypeFloat32: {
        float narrowed = (float)value;
        memcpy((char *)bytes + index * 4, &narrowed, 4);
        break;
    }
    case MPSDataTypeFloat16:
        ((uint16_t *)bytes)[index] = CharonMPSFloatToHalfRounded((float)value, awayFromZero);
        break;
    case MPSDataTypeInt8:
        ((int8_t *)bytes)[index] = (int8_t)value;
        break;
    case MPSDataTypeInt16:
        ((int16_t *)bytes)[index] = (int16_t)value;
        break;
    case MPSDataTypeInt32:
        ((int32_t *)bytes)[index] = (int32_t)value;
        break;
    case MPSDataTypeUInt8:
        ((uint8_t *)bytes)[index] = (uint8_t)value;
        break;
    case MPSDataTypeUInt16:
        ((uint16_t *)bytes)[index] = (uint16_t)value;
        break;
    case MPSDataTypeUInt32:
        ((uint32_t *)bytes)[index] = (uint32_t)value;
        break;
    // The alternate encoding a comparison answers, one byte per element: see CharonMPSLoad.
    case MPSDataTypeBool:
        ((uint8_t *)bytes)[index] = value != 0.0 ? 1 : 0;
        break;
    default:
        break;
    }
}

static inline void CharonMPSStore(void *bytes, MPSDataType type, size_t index, double value)
{
    CharonMPSStoreRounded(bytes, type, index, value, 0);
}

// A matrix as the kernels walk it: the first byte of the data, and the three strides the header names.
typedef struct {
    void *bytes;
    MPSDataType dataType;
    size_t elementSize;
    size_t rowBytes;
    size_t matrixBytes;
    NSUInteger rows;
    NSUInteger columns;
    NSUInteger matrices;
} CharonMPSMatrixView;

static inline CharonMPSMatrixView CharonMPSMatrixViewOf(MPSMatrix *matrix)
{
    CharonMPSMatrixView view;
    view.bytes = (char *)[matrix.data contents] + matrix.offset;
    view.dataType = matrix.dataType;
    view.elementSize = MPSSizeofMPSDataType(matrix.dataType);
    view.rowBytes = matrix.rowBytes;
    view.matrixBytes = matrix.matrixBytes;
    view.rows = matrix.rows;
    view.columns = matrix.columns;
    view.matrices = matrix.matrices;
    return view;
}

static inline void *CharonMPSMatrixElement(const CharonMPSMatrixView *view, NSUInteger matrix, NSUInteger row, NSUInteger column)
{
    return (char *)view->bytes + matrix * view->matrixBytes + row * view->rowBytes + column * view->elementSize;
}

// Whether a matrix holds the region a kernel was asked to read or write. The release's own MPS
// asserts on a matrix that does not; an API in this port never crashes its caller, so the kernel says
// so in the log once and leaves the destination as it found it.
static inline BOOL CharonMPSMatrixHolds(const CharonMPSMatrixView *view, NSUInteger matrix, NSUInteger originRow, NSUInteger originColumn, NSUInteger rows, NSUInteger columns)
{
    if (matrix >= view->matrices)
        return NO;
    if (originRow > view->rows || rows > view->rows - originRow)
        return NO;
    if (originColumn > view->columns || columns > view->columns - originColumn)
        return NO;
    return YES;
}

typedef struct {
    void *bytes;
    MPSDataType dataType;
    size_t elementSize;
    size_t vectorBytes;
    NSUInteger length;
    NSUInteger vectors;
} CharonMPSVectorView;

static inline CharonMPSVectorView CharonMPSVectorViewOf(MPSVector *vector)
{
    CharonMPSVectorView view;
    view.bytes = (char *)[vector.data contents] + vector.offset;
    view.dataType = vector.dataType;
    view.elementSize = MPSSizeofMPSDataType(vector.dataType);
    view.vectorBytes = vector.vectorBytes;
    view.length = vector.length;
    view.vectors = vector.vectors;
    return view;
}

static inline void *CharonMPSVectorElement(const CharonMPSVectorView *view, NSUInteger index, NSUInteger component)
{
    return (char *)view->bytes + index * view->vectorBytes + component * view->elementSize;
}

static inline BOOL CharonMPSVectorHolds(const CharonMPSVectorView *view, NSUInteger index, NSUInteger length)
{
    return index < view->vectors && length <= view->length;
}

// The inverse of the normal distribution function, by the rational approximation of Wichura's AS 241
// (Applied Statistics 37, 1988), which is accurate to about sixteen digits over the whole range and
// needs no iteration. The tails use their own rational forms because the central one loses the
// significance a small probability has.
static inline double CharonMPSInverseNormal(double p)
{
    static const double a[6] = {-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00};
    static const double b[5] = {-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                                 6.680131188771972e+01, -1.328068155288572e+01};
    static const double c[6] = {-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00};
    static const double d[4] = {7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
                                 3.754408661907416e+00};
    const double boundary = 0.02425;
    if (p <= 0.0)
        return -INFINITY;
    if (p >= 1.0)
        return INFINITY;
    if (p < boundary) {
        double q = sqrt(-2.0 * log(p));
        return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
               ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0);
    }
    if (p <= 1.0 - boundary) {
        double q = p - 0.5, r = q * q;
        return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
               (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0);
    }
    double q = sqrt(-2.0 * log(1.0 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
            ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0);
}

// The batch a kernel walks: [batchStart, batchStart + batchSize), the whole of it when the size is 0,
// as the headers document for batchSize.
static inline void CharonMPSBatch(NSUInteger batchStart, NSUInteger batchSize, NSUInteger available, NSUInteger *start, NSUInteger *count)
{
    NSUInteger first = batchStart < available ? batchStart : available;
    NSUInteger last = available;
    if (batchSize && first + batchSize < last)
        last = first + batchSize;
    *start = first;
    *count = last - first;
}

// A kernel that cannot run says so once, in the log, naming the kernel and the reason, and leaves its
// destination as it found it. The release asserts instead; an API in this port never crashes its
// caller, and a silent wrong answer would be worse than either.
#define CharonMPSRefuse(...) NSLog(__VA_ARGS__)

// The private surface this framework's own files share. None of it is API an application calls, and
// each of these selectors is a name no SDK header declares.
@interface MPSPredicate (CharonMPS)
- (BOOL)charon_mps_permitsExecution;
@end

@interface MPSStateResourceList (CharonMPS)
- (NSArray<NSNumber *> *)charon_mps_bufferSizes;
- (NSArray<MTLTextureDescriptor *> *)charon_mps_textureDescriptors;
@end

@interface MPSState (CharonMPS)
- (void)charon_mps_appendBuffer:(size_t)size;
- (void)charon_mps_appendTexture:(MTLTextureDescriptor *)descriptor;
// A state that already HAS its resources - MPSState11.m builds these two and MPSNNStates12.m puts them in
// the list, which is what makes the state answer -resource and -bufferSizeAtIndex: for them.
- (void)charon_mps_appendResource:(id<MTLResource>)resource;
@end

@interface MPSTemporaryMatrix (CharonMPS)
- (instancetype)charon_mps_withReadCount:(NSUInteger)readCount;
@end

@interface MPSTemporaryVector (CharonMPS)
- (instancetype)charon_mps_withReadCount:(NSUInteger)readCount;
@end

// Whether a kernel encoded into this command buffer runs. Only an MPSCommandBuffer carries a
// predicate; a plain command buffer always runs what is encoded into it.
static inline BOOL CharonMPSCommandBufferPermits(id<MTLCommandBuffer> commandBuffer)
{
    if ([commandBuffer isKindOfClass:[MPSCommandBuffer class]])
        return [[(MPSCommandBuffer *)commandBuffer predicate] charon_mps_permitsExecution];
    return YES;
}

// The neuron state the neural-network matrix kernels all carry: the type, the three parameters its
// formula names, and the per-channel array a PReLU's parameter A lives in. MPSMatrixNeuron.h,
// MPSMatrixFullyConnected.h, MPSMatrixBatchNormalization.h and MPSMatrixSum.h each declare the same
// five members, so each of those classes holds one of these.
typedef struct {
    MPSCNNNeuronType type;
    float a, b, c;
    const float *prelu;   // one float per input feature channel, or NULL
    NSUInteger channels;
} CharonMPSNeuron;

static inline double CharonMPSNeuronA(const CharonMPSNeuron *neuron, NSUInteger channel)
{
    return neuron->prelu ? (double)neuron->prelu[channel] : (double)neuron->a;
}

@interface MPSMatrixNeuron (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixNeuronGradient (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixFullyConnected (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixBatchNormalization (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixBatchNormalizationGradient (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixSum (CharonMPS)
- (CharonMPSNeuron)charon_mps_neuron;
@end

@interface MPSMatrixRandom (CharonMPS)
// The two generators share one initialisation, in the init family so that it may build the object: the
// headers mark -initWithDevice: unavailable on MPSMatrixRandom itself, because a random kernel is
// always one of the two subclasses, and this is how each of them reaches MPSKernel's own initialiser.
- (id)initWithDevice:(id<MTLDevice>)device charonRandom:(BOOL)philox;
- (id)charon_mps_configureWithDataType:(MPSDataType)dataType
                                  seed:(uint32_t)seed
                            distribution:(MPSMatrixRandomDistributionDescriptor *)distribution;
- (uint32_t)charon_mps_wordAtIndex:(NSUInteger)index;
- (void)charon_mps_batchOver:(NSUInteger)available first:(NSUInteger *)first count:(NSUInteger *)count;
@end

@interface MPSNNOptimizer (CharonMPS)
// Internal, and how each of the three concrete optimizers is built. MPSNNOptimizers.h:249 marks the
// base's -initWithDevice: NS_UNAVAILABLE - "You must use one of the sub-classes of MPSNNOptimizer"
// (:247) - so a subclass of this base cannot call it: a [super initWithDevice:] inside
// MPSNNOptimizerStochasticGradientDescent, MPSNNOptimizerRMSProp or MPSNNOptimizerAdam resolves to that
// redeclaration and does not compile. The only initializer this base has left is MPSKernel's
// -initWithCoder:device: (MPSKernel.h:162), which decodes an archive and takes a nonnull coder no
// caller of these kernels has, so this is what reaches MPSKernel's own -initWithDevice: (MPSKernel.h:117)
// instead, which the header does not mark unavailable.
//
// Unlike MPSMatrixRandom's seam above this one takes nothing the base does not already know, so it is
// not in the init family: the name does not begin with "init", so it must not assign to self, and it
// returns what MPSKernel made instead - the object the caller's own allocation already is. That is the
// same shape MPSImageReduceUnary's seam has in CharonMPSReduce.h:35, for the same reason.
- (instancetype)charon_initWithDevice:(id<MTLDevice>)device;
@end

@interface MPSMatrixSoftMax (CharonMPS)
- (void)charon_mps_setLogarithmic:(BOOL)logarithmic;
@end

@interface MPSMatrixCopyDescriptor (CharonMPS)
- (id)charon_mps_withCount:(NSUInteger)count;
- (NSUInteger)charon_mps_count;
- (MPSMatrix *)charon_mps_sourceAtIndex:(NSUInteger)index;
- (MPSMatrix *)charon_mps_destinationAtIndex:(NSUInteger)index;
- (MPSMatrixCopyOffsets)charon_mps_offsetsAtIndex:(NSUInteger)index;
@end

// A temporary resource's read count, decremented by a kernel that reads it, as MPSCommandBuffer.h and
// MPSMatrix.h document: each -encode.. that reads a temporary decrements it, and a count of zero means
// the storage may be reused. A non-temporary matrix, vector or image has no read count of its own and
// is never recycled, so its count is left alone.
//
// MPSTemporaryImage is in this list, and it is here rather than in each kernel so that no kernel has to
// remember which temporaries this framework has. MPSImage.h:1030-1036 is the header's own statement
// that it belongs: a CNN kernel's encode, when it reads one, lowers that temporary's read count by one
// without the kernel doing anything. The class carries the count - MPSImage.h:1051 declares
// @property (readwrite, nonatomic) NSUInteger readCount on MPSTemporaryImage and on no other image -
// and MPSImageElements10.m answers -readCount and -setReadCount:, so a kernel that read one and left
// the count alone would leave the count describing a use that has already happened.
//
// WHAT WAS MEASURED, and what could not be. The number this rests on is the port's own, measured by
// tests/backports/host/mpstemporary/run.sh: a temporary image at readCount 2 answers 2 after
// -setReadCount:2 (so the reader is alive and a zero cannot come from a dead one), an encode that
// reads it answers 1 and the next answers 0, and a plain MPSImage through the same kernel answers
// nothing at all - MPSImage.h declares no readCount on it - so it is left alone.
//
// THE RELEASE ANSWERED NOTHING ON THIS HOST, and the case prints the selector rather than a number.
// Every path that makes an MPSTemporaryImage out of Apple's own MPS on this machine - the class
// method of MPSImage.h:955-975 with a texture descriptor, the same with an MPSImageDescriptor, and
// [MPSTemporaryImage defaultAllocator]'s -imageForCommandBuffer:imageDescriptor:kernel: of
// MPSImage.h:230-249 - raises
//
//     -[AGXG16XFamilyCommandBuffer_mtlnext userDictionary]: unrecognized selector
//
// out of MPSAutoTexture::InitDeferredUsingTextureCache, while +[MPSImage initWithDevice:imageDescriptor:]
// on the same command buffer answers an MPSImage and [MPSTemporaryImage defaultAllocator] answers
// MPSTemporaryImageDefaultAllocator. So there is no release-side number for this decrement to be
// compared against on this machine, the header's sentence is the only statement of it, and the case
// says which rather than implying one.
static inline void CharonMPSConsumeReadCount(id object)
{
    if ([object isKindOfClass:[MPSTemporaryMatrix class]] || [object isKindOfClass:[MPSTemporaryVector class]]) {
        NSUInteger count = [(MPSTemporaryVector *)object readCount];
        if (count)
            [(MPSTemporaryVector *)object setReadCount:count - 1];
        return;
    }
    if ([object isKindOfClass:[MPSTemporaryImage class]]) {
        NSUInteger count = [(MPSTemporaryImage *)object readCount];
        if (count)
            [(MPSTemporaryImage *)object setReadCount:count - 1];
    }
}

// The row stride the release recommends for a given number of columns and element type, measured on
// macOS 26.5's own MPSMatrixDescriptor over all eight element types and seventy column counts
// (tests/backports/host/mpsmatrix/run.sh prints the table this rule reproduces): one column is one
// element, a floating point row is rounded up to a multiple of sixteen bytes and an integer row to a
// multiple of four elements. Zero columns have no row. Both descriptors answer it, so it is here
// rather than in either of them, and static so that neither needs a symbol from the other.
static inline size_t CharonMPSRowBytesForColumns(NSUInteger columns, MPSDataType dataType)
{
    size_t elementSize = MPSSizeofMPSDataType(dataType);
    size_t alignment = CharonMPSDataTypeIsFloat(dataType) ? 16 : 4 * elementSize;
    if (columns == 0)
        return 0;
    if (columns == 1)
        return elementSize;
    return (columns * elementSize + alignment - 1) / alignment * alignment;
}

// The neuron activation functions MPSCNNNeuronType names, in the formulas that header gives for them.
// PReLU takes its parameter A per channel, in aPerChannel, because the header says a caller sets those
// through setNeuronToPReLUWithParametersA: and the table has no other way to see them.
static inline double CharonMPSApplyNeuron(MPSCNNNeuronType type, double x, double a, double b, double c, double aPerChannel)
{
    switch (type) {
    case MPSCNNNeuronTypeNone:
    case MPSCNNNeuronTypeCount:
        return x;
    case MPSCNNNeuronTypeReLU:
        return x >= 0.0 ? x : a * x;
    case MPSCNNNeuronTypeLinear:
        return a * x + b;
    case MPSCNNNeuronTypeSigmoid:
        return 1.0 / (1.0 + exp(-x));
    case MPSCNNNeuronTypeHardSigmoid: {
        double v = x * a + b;
        return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
    }
    case MPSCNNNeuronTypeTanH:
        return a * tanh(b * x);
    case MPSCNNNeuronTypeAbsolute:
        return fabs(x);
    case MPSCNNNeuronTypeSoftPlus:
        return a * log1p(exp(b * x));
    case MPSCNNNeuronTypeSoftSign: {
        double m = fabs(x);
        return m == INFINITY ? (x < 0.0 ? -1.0 : 1.0) : x / (1.0 + m);
    }
    case MPSCNNNeuronTypeELU:
        return x >= 0.0 ? x : a * (exp(x) - 1.0);
    case MPSCNNNeuronTypePReLU:
        return x >= 0.0 ? x : aPerChannel * x;
    case MPSCNNNeuronTypeReLUN: {
        double v = x >= 0.0 ? x : a * x;
        return v > b ? b : v;
    }
    case MPSCNNNeuronTypePower:
        return pow(a * x + b, c);
    case MPSCNNNeuronTypeExponential:
        return pow(c, a * x + b);
    case MPSCNNNeuronTypeLogarithm:
        return log(a * x + b) / log(c);
    case MPSCNNNeuronTypeGeLU:
        return (1.0 + erf(x * sqrt(0.5))) * 0.5 * x;
    default:
        return x;
    }
}

// The same table's derivative, which MPSMatrixNeuronGradient is built from. It is the value
// MPSCNNNeuronType's own formulas differentiate to, computed in double so the ratio that decides a
// softplus or a logarithm's parameter is not decided by a rounded one.
static inline double CharonMPSApplyNeuronGradient(MPSCNNNeuronType type, double x, double y, double a, double b, double c, double aPerChannel)
{
    switch (type) {
    case MPSCNNNeuronTypeNone:
    case MPSCNNNeuronTypeCount:
        return 1.0;
    case MPSCNNNeuronTypeReLU:
        return x >= 0.0 ? 1.0 : a;
    case MPSCNNNeuronTypeLinear:
        return a;
    case MPSCNNNeuronTypeSigmoid: {
        // s*(1-s) with s = 1/(1+e^-x), written on |x|: s(-x) is 1-s(x), so the product is the same
        // for a negative x, and this is the even function the table's own value gives. The softplus
        // below is not even, and the same trick there is a wrong answer.
        double e = exp(-fabs(x));
        double s = 1.0 / (1.0 + e);
        return s * (1.0 - s);
    }
    case MPSCNNNeuronTypeHardSigmoid:
        return (x * a + b) >= 0.0 && (x * a + b) <= 1.0 ? a : 0.0;
    case MPSCNNNeuronTypeTanH: {
        double t = tanh(b * x);
        return a * b * (1.0 - t * t);
    }
    case MPSCNNNeuronTypeAbsolute:
        return x > 0.0 ? 1.0 : (x < 0.0 ? -1.0 : 0.0);
    case MPSCNNNeuronTypeSoftPlus: {
        // MPSCNNNeuronType.h gives f(x) = a * log(1 + e^(b*x)), so f'(x) = a*b*e^(b*x)/(1+e^(b*x)).
        // The exponent is signed: taking its magnitude makes the derivative an even function where
        // the function is not, and for b*x < 0 it answers a*b - f'(x) instead of f'(x), which the
        // release's own neuron-gradient cases measure at 94 % of the value. Written as the sigmoid
        // of b*x so no intermediate overflows: for b*x >= 0 the denominator 1+e^(-b*x) is at most 2,
        // and for b*x < 0 the numerator e^(b*x) is at most 1.
        double t = b * x;
        double s = t >= 0.0 ? 1.0 / (1.0 + exp(-t)) : exp(t) / (1.0 + exp(t));
        return a * b * s;
    }
    case MPSCNNNeuronTypeSoftSign: {
        double m = fabs(x);
        if (m == INFINITY)
            return 0.0;
        return 1.0 / ((1.0 + m) * (1.0 + m));
    }
    case MPSCNNNeuronTypeELU:
        return x >= 0.0 ? 1.0 : a * exp(x);
    case MPSCNNNeuronTypePReLU:
        return x >= 0.0 ? 1.0 : aPerChannel;
    case MPSCNNNeuronTypeReLUN:
        return (x >= 0.0 ? x : a * x) >= b ? 0.0 : (x >= 0.0 ? 1.0 : a);
    case MPSCNNNeuronTypePower: {
        double t = a * x + b;
        return t == 0.0 ? 0.0 : c * pow(t, c - 1.0) * a;
    }
    case MPSCNNNeuronTypeExponential: {
        double t = pow(c, a * x + b);
        return t * a * log(c);
    }
    case MPSCNNNeuronTypeLogarithm: {
        // MPSCNNNeuronType.h gives f(x) = log_c(a*x+b), so f'(x) = a / ((a*x+b) * ln c) on the whole
        // line and not only where the forward is defined. Clamping a*x+b at zero answered 0 where
        // the release answers the analytic value, and a negative one where it answers a negative
        // one: measured over the case's own inputs the release writes -2.18271 and +inf where this
        // wrote 0, which is a/(t*ln c) at t = -0.375 and at t = 0. The forward's NaN for a
        // non-positive argument is unchanged - the release's own forward writes one too.
        double t = a * x + b;
        return a / (t * log(c));
    }
    case MPSCNNNeuronTypeGeLU: {
        double u = x * 0.70710678118654752440;
        return 0.5 * (1.0 + erf(u)) + x * exp(-0.5 * x * x) * 0.39894228040143267794;
    }
    default:
        return 1.0;
    }
}
