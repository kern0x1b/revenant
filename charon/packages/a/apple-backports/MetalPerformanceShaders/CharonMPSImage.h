// CharonMPSImage.h - the walking layer this package's MPSImage kernels share.
//
// Every kernel in this family takes an MPSImage on each side and walks it pixel by pixel, so the walking
// is here once rather than in each kernel: a layout resolved once from the image, a read of one channel
// of one pixel, a write of the same, and a readBytes:/writeBytes: pair over a region.
//
// The channel format is a property of the image and a kernel does not choose it. This package compiles
// against the iPhoneOS 16.4 surface, where `MPSImageFeatureChannelFormat` names an element width —
// Unorm8, Unorm16, Float16, Float32 — and the channel count is the image's own `featureChannels`. There
// is no planar format in that surface, so the addressing is always interleaved: a pixel's channels sit
// together at `pixel * bytesPerPixel`, and a row is `bytesPerRow` from the next. Every read and write
// below goes through CharonMPSLoad/CharonMPSStore at the image's own element width — the same two the
// matrix kernels use, which is why they are not re-implemented here.
//
// MPSImage13.m holds the class: the texture, the descriptor, the properties and the two readBytes:/
// writeBytes: forms. This header is the arithmetic on top of them, and it reads and writes through that
// same pair - `MPSDataLayoutHeightxWidthxFeatureChannels`, the row-major order of a region, and the
// `MPSImageReadWriteParams` argument the 26.2 form carries - so a walk and a caller see the same bytes in
// the same order.

#import "CharonMPS.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    NSUInteger width, height;      // the image's shape
    NSUInteger channels;           // featureChannels, which is 1 for every kernel in this family
    NSUInteger bytesPerPixel;      // texture.bytesPerPixel
    NSUInteger bytesPerRow;        // texture.bytesPerRow
    size_t elementSize;            // the element size of dataType, from this file's table
    MPSDataType dataType;          // what the image's channel format maps to
    NSUInteger count;              // width * height * channels: how many elements a region holds
    int pixelFormat;               // the image's own, printed by the guard when it refuses
} CharonMPSImageLayout;

// ONE table, keyed by the CHANNEL FORMAT, which is the image's own and the thing a layout is built
// from. It replaces the release's MPSSizeofMPSDataType, which answers 0 for a type the host does not
// know, and a zero element size makes a region's buffer one byte long. There was a second, data-type
// keyed copy of the same four widths; it could not disagree with this one - CharonMPSImageDataTypeOf maps
// each of the four formats onto exactly one of those four data types - and it had no call site, so it
// is gone rather than left as a second answer for the next author to choose between.

// The layout of `image`, or a zeroed one when it is nil. A kernel holds it in a local for the length of
// its walk and does not ask the image again per pixel.
CharonMPSImageLayout CharonMPSImageLayoutOf(MPSImage *image);

// YES when the image can be walked at all: a data type the eight element types name, a shape, a
// channel count and a texture. A kernel handed the other answers NO from its encode and says which.
BOOL CharonMPSImageUsable(MPSImage *image, NSString *what);

// The element index of one channel of one pixel WITHIN A REGION'S BUFFER, which the region's read is
// one row-major run of `width * channels` elements per row, pixel counted from the region's own origin.
NSUInteger CharonMPSImageIndex(const CharonMPSImageLayout *layout, NSUInteger pixel, NSUInteger channel);

// One element of a region already read into a buffer, and one element written back into the buffer a
// region will be written from, in elements of the image's own width.
double CharonMPSImageLoad(const void *buffer, const CharonMPSImageLayout *layout, NSUInteger index);
void CharonMPSImageStore(void *buffer, const CharonMPSImageLayout *layout, NSUInteger index, double value);

// One channel of a whole region, pixel by pixel, through a callback. The layout decides the element
// width, so the callbacks see a double whatever the image holds: a kernel is written once and answers
// Float32 and Float16 images alike.
typedef double (^CharonMPSImageUnary)(NSUInteger pixel, NSUInteger channel, double value);
typedef double (^CharonMPSImageBinary)(NSUInteger pixel, NSUInteger channel, double primary, double secondary);

// Walk `source` into `destination` through `fn`, over `region`. The two images must be the same shape
// and the same data type: a walk reads one element of each, so a caller that gave a kernel two
// different shapes gets NO and the numbers in the message, rather than a walk of one against the other.
BOOL CharonMPSImageMapUnary(MPSImage *source, MPSImage *destination, MTLRegion region,
                            CharonMPSImageUnary fn, NSString *what);
BOOL CharonMPSImageMapBinary(MPSImage *primaryImage, MPSImage *secondaryImage, MPSImage *destination,
                             MTLRegion region, CharonMPSImageBinary fn, NSString *what);

// The whole image as a region, which is what a kernel walks when the caller set no clip rectangle.

// The region a kernel's clipRect means, resolved against the image it clips. MPSKernel's clipRect is
// MPSRectNoClip - size {-1, -1, 0} - when the caller set none, and that is a SENTINEL, not a region: to
// a texture it is xoffset + width = -2 and the framework asserts. Apple's contract is that it means the
// whole destination. A negative size, and a size that runs past the image, both become what is left of
// the image, and the origin is clamped into it.
MTLRegion CharonMPSImageResolvedRegion(MPSImage *image, MTLRegion clip);

// YES when the region has no pixels, and the walk does nothing at all for it - no allocation, no read,
// no write, no assertion. That is what "clipped away" means.
BOOL CharonMPSImageRegionIsEmpty(MTLRegion region);

// The element size of a channel format, from the four the 16.4 surface names. 0 for the rest, which
// the 26.2 surface's planar formats and alpha formats are on this surface.
size_t CharonMPSImageFeatureChannelSize(MPSImageFeatureChannelFormat format);

// The data type an image's channel format's elements have. The 16.4 MPSImage carries no `dataType` of
// its own, so a kernel that wants to know how wide an element is and whether it is signed asks here.
MPSDataType CharonMPSImageDataTypeOf(MPSImageFeatureChannelFormat format);

// The two region helpers a kernel outside the walk file needs. They are static in
// MPSImageWalk13.m, so a kernel that calls them has to be able to see them; MPSImageTranspose
// is the one, because the permutation it performs is in the index.
//
// THE READ IS _Nullable, AND NIL IS ITS ANSWER IN THREE NAMED CASES, not a stand-in for something the
// release returns. It answers the region's elements as a buffer, and there are three times there is no
// such buffer:
//
//   * the region names no pixel. There is nothing to read and no row to lay out, so an empty run has no
//     buffer. The release's own -[MPSImage readBytes:...] over a zero-size region is a no-op with no
//     output pointer, so nil is what it answers too.
//   * the channel format names no element width - MPSImageFeatureChannelFormatNone, or any format the
//     26.2 surface's planar and alpha encodings name and this one does not. There is no element size to
//     multiply by, so no buffer. The refusal in CharonMPSRefuse says which format.
//   * calloc failed. There is no memory for the region.
//
// The declaration sat inside NS_ASSUME_NONNULL_BEGIN with no annotation, so all three reads of NULL were
// diagnosed: the host compile of MPSImageWalk13.m stopped at :181, :188 and :197 with "null returned
// from function that requires a non-null return value [-Werror,-Wnonnull]", which is how
// `sh tests/backports/host/run-all.sh --seconds 120 mpsmatrix` came to be DEAD - and DEAD on origin/main
// itself, not only here.
//
// EVERY CALLER ALREADY HANDLED IT, which is the measurement that says nil is the intended answer rather
// than an accident: twelve call sites in ten files, and several of them distinguish the two cases
// explicitly with the count they set on the layout - `if (slice.count && !from) return;` at
// MPSImageConvolution13.m:69, MPSImageMorphology13.m:63, MPSNNReduce16.m:298 and
// MPSImageReduceUnary16.m:192, and `if (region.size.width && !primary) return NO;` at
// MPSImageWalk13.m:299 - which is only correct if a nil that means "empty region" and a nil that means
// "failed" are the same nil and the caller has the count to tell them apart. So the callers were written
// against a nullable read and the header was the one place that disagreed. Nothing here needed changing
// but the annotation.
void *_Nullable CharonMPSImageReadRegion(MPSImage *image, const CharonMPSImageLayout *layout, MTLRegion region, NSString *what);
BOOL CharonMPSImageWriteRegion(MPSImage *image, const CharonMPSImageLayout *layout, MTLRegion region, const void *buffer, NSString *what);

// Lay one image's channels into another's at a feature channel offset, the source and the destination in
// SEPARATE buffers. This is the concatenation MPSNNGraphNodes.h:2443 describes - "[0,M-1] will be drawn
// from image M, [M, M+N-1] from image N" - and it is a scatter through the destination's own element
// width, so a source and a destination of different channel formats join correctly rather than byte for
// byte.
//
// `source` and `sourceBytes` are one source region as CharonMPSImageReadRegion returned it;
// `destination` and `destinationBytes` are a whole destination image, one row after another, each of
// `destination->width * destination->channels` elements. Two buffers, not one, because a concatenation's
// destination is wider than every source: CharonMPSImageReadRegion allocates
// width * height * sourceChannels elements, and joining in place writes a row of
// width * destinationChannels into a buffer of the source's own size. Measured on one channel into four:
// the write puts a row of four elements into a buffer of one and walks off the end of it, a SIGSEGV
// inside objc_storeStrong.
//
// It answers NO, and writes nothing, when the two cannot be joined: the widths or the heights differ,
// because a concatenation joins channels of one plane and not pixels of two, or the destination has no
// channels at `offset .. offset + sourceChannels`, or either side names no element size. The caller's
// refusal in the log is where the numbers go; a partial join would leave an image half joined and the
// caller none the wiser.
BOOL CharonMPSImageConcatRows(const CharonMPSImageLayout *source, const CharonMPSImageLayout *destination,
                              NSUInteger offset, const void *sourceBytes, void *destinationBytes);

NS_ASSUME_NONNULL_END
