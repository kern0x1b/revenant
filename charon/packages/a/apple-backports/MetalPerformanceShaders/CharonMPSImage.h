#import "CharonMPS.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    NSUInteger width, height;
    NSUInteger channels;
    NSUInteger bytesPerPixel;
    NSUInteger bytesPerRow;
    size_t elementSize;
    MPSDataType dataType;
    NSUInteger count;
    int pixelFormat;
} CharonMPSImageLayout;

CharonMPSImageLayout CharonMPSImageLayoutOf(MPSImage *image);

BOOL CharonMPSImageUsable(MPSImage *image, NSString *what);

NSUInteger CharonMPSImageIndex(const CharonMPSImageLayout *layout, NSUInteger pixel, NSUInteger channel);

double CharonMPSImageLoad(const void *buffer, const CharonMPSImageLayout *layout, NSUInteger index);
void CharonMPSImageStore(void *buffer, const CharonMPSImageLayout *layout, NSUInteger index, double value);

typedef double (^CharonMPSImageUnary)(NSUInteger pixel, NSUInteger channel, double value);
typedef double (^CharonMPSImageBinary)(NSUInteger pixel, NSUInteger channel, double primary, double secondary);

BOOL CharonMPSImageMapUnary(MPSImage *source, MPSImage *destination, MTLRegion region,
                            CharonMPSImageUnary fn, NSString *what);
BOOL CharonMPSImageMapBinary(MPSImage *primaryImage, MPSImage *secondaryImage, MPSImage *destination,
                             MTLRegion region, CharonMPSImageBinary fn, NSString *what);

MTLRegion CharonMPSImageResolvedRegion(MPSImage *image, MTLRegion clip);

BOOL CharonMPSImageRegionIsEmpty(MTLRegion region);

size_t CharonMPSImageFeatureChannelSize(MPSImageFeatureChannelFormat format);

MPSDataType CharonMPSImageDataTypeOf(MPSImageFeatureChannelFormat format);

void *_Nullable CharonMPSImageReadRegion(MPSImage *image, const CharonMPSImageLayout *layout, MTLRegion region, NSString *what);
BOOL CharonMPSImageWriteRegion(MPSImage *image, const CharonMPSImageLayout *layout, MTLRegion region, const void *buffer, NSString *what);

BOOL CharonMPSImageConcatRows(const CharonMPSImageLayout *source, const CharonMPSImageLayout *destination,
                              NSUInteger offset, const void *sourceBytes, void *destinationBytes);

NS_ASSUME_NONNULL_END
