// The twelve concrete MPSNNReduce classes, from MPSNNReduce.h of the iPhoneOS 16.4 surface. The
// release exports these from iOS 12.0, and the abstract base MPSNNReduceUnary they inherit from only
// from iOS 16.0, so they are their own object apart from MPSNNReduce16.m. Each differs from the base
// only in the axis and the operation, which is exactly what MPSNNReduce.h's twelve per-class sentences
// describe.
//
// Every header annotation here says ios(11.3) - MPSNNReduce.h:68, :95, :121, :175, :201, :227, :281,
// :307, :333, :359, :385, :412, each repeating the MPS_CLASS_AVAILABLE_STARTING above the base at :36 -
// and `introduced` in the registry says 11.3 for all twelve, and both are right about when APPLE
// published them. What an OBJECT is placed at is the first held release that EXPORTS the symbol, and the
// two answers differ: measured with modules/apple/dyld.lua's first_releases() over the held ladder, the
// call modules/apple/backports.lua's check_releases() makes, the twelve classes' class symbols are
// exported by the 12.0, 16.0 and 18.0 caches and by no earlier held one, so first_releases() answers
// 12.0. tools/cache-index/first-rung.lua answers 12.0 for them as well, and the two tools part company on
// the BASE rather than on these: the 12.0 cache carries MPSNNReduceUnary's name and does not export it,
// so the base reads as 16.0 and these as 12.0, and an object cannot be both.
//
// There is no arithmetic here: the walk is the base's, reached through the `charon_` seam
// CharonMPSReduce.h declares, which is the same seam MPSImageReduce12.m uses for the MPSImageReduce
// classes, because a class that declares no encode of its own - which the release's own cache says of
// all twelve - cannot carry one.

#import "CharonMPSReduce.h"

// One scoped suppression, and it is the same one MPSNNReduce16.m carries and the same one recorded in
// coordination/crutches.md, moved with the code it covers. Each of the twelve classes above declares
// -initWithCoder:device: (MPSNNReduce.h:85 and its eleven siblings) and none of them implements it: the
// coder cannot say which of the four operations to build over which axis, so the base's
// -initWithCoder:device: is the one that reads it, and MPSNNReduce16.m implements it there.
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// See MPSNNReduce16.m for why: each concrete class's -initWithDevice: is NS_DESIGNATED_INITIALIZER and
// the base's only designated initializer cannot know which operation to build. Recorded in
// coordination/crutches.md.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// The ONE class whose OWN @interface declares `weight` - MPSNNReduce.h:420, on
// MPSNNReduceFeatureChannelsSum - gets its accessors implemented against the base's storage, because
// the SDK's declaration makes it autosynthesize an ivar of its own that the walk does not read.
//
// ONE class and not two, measured rather than assumed: the header gives `weight` to
// MPSNNReduceFeatureChannelsSum alone (:413-420), and the release's own cache agrees - of the twelve
// concrete classes, only MPSNNReduceFeatureChannelsSum lists -weight and -setWeight:.
// MPSNNReduceFeatureChannelsMean (:334) declares no property at all, and its cache entry lists no
// weight selector, so a `weight` on it would be an API this port has and the release does not.
@interface MPSNNReduceFeatureChannelsSum (CharonMPSNNReduce)
- (float)weight;
- (void)setWeight:(float)weight;
@end

// The twelve concrete classes. Each differs from the base only in the axis and the operation, which
// is exactly what the header's twelve per-class sentences say, and CharonMPSReduce.h's
// CharonMPSReduceOperation already names the four operations this family has. There is no arithmetic
// here: the walk is the base's, reached through the same `charon_` seam MPSImageReduce12.m uses for
// the MPSImageReduce classes, because a class that declares no encode of its own - which the release's
// own cache says of all twelve - cannot carry one.
#define CHARON_DEFINE_NN_REDUCE(CLASS, COLUMN, FEATURE_CHANNEL, OPERATION)                          \
    @implementation CLASS                                                                          \
    - (instancetype)initWithDevice:(id<MTLDevice>)device                                          \
    {                                                                                              \
        return [self charon_nnReduceWithDevice:device                                             \
                                     byColumn:(COLUMN)                                            \
                             byFeatureChannel:(FEATURE_CHANNEL)                                    \
                                   operation:(OPERATION)];                                        \
    }                                                                                              \
    @end

// Row, column and feature channel, each four times: min, max, mean, sum.
CHARON_DEFINE_NN_REDUCE(MPSNNReduceRowMin, NO, NO, CharonMPSReduceMin)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceColumnMin, YES, NO, CharonMPSReduceMin)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMin, NO, YES, CharonMPSReduceMin)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceRowMax, NO, NO, CharonMPSReduceMax)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceColumnMax, YES, NO, CharonMPSReduceMax)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMax, NO, YES, CharonMPSReduceMax)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceRowMean, NO, NO, CharonMPSReduceMean)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceColumnMean, YES, NO, CharonMPSReduceMean)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsMean, NO, YES, CharonMPSReduceMean)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceRowSum, NO, NO, CharonMPSReduceSum)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceColumnSum, YES, NO, CharonMPSReduceSum)
CHARON_DEFINE_NN_REDUCE(MPSNNReduceFeatureChannelsSum, NO, YES, CharonMPSReduceSum)


// MPSNNReduceFeatureChannelsSum's `weight`, against the base's storage. The SDK declares the property
// on this class, so without these it would autosynthesize an ivar of its own that the walk - which
// reads the base's - never sees, and a caller setting the weight would watch the reduction ignore it.
// The accessors keep the release's spelling and the base keeps one piece of state.
@implementation MPSNNReduceFeatureChannelsSum (CharonMPSNNReduce)
- (float)weight { return [self charon_nnReduceWeight]; }
- (void)setWeight:(float)weight { [self charon_setNnReduceWeight:weight]; }
@end
