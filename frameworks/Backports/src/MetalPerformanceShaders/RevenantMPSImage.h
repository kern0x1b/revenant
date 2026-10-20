#import "RevenantMPS.h"

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
} RevenantMPSImageLayout;

RevenantMPSImageLayout RevenantMPSImageLayoutOf(MPSImage *image);

BOOL RevenantMPSImageUsable(MPSImage *image, NSString *what);

NSUInteger RevenantMPSImageIndex(const RevenantMPSImageLayout *layout, NSUInteger pixel, NSUInteger channel);

double RevenantMPSImageLoad(const void *buffer, const RevenantMPSImageLayout *layout, NSUInteger index);
void RevenantMPSImageStore(void *buffer, const RevenantMPSImageLayout *layout, NSUInteger index, double value);

typedef double (^RevenantMPSImageUnary)(NSUInteger pixel, NSUInteger channel, double value);
typedef double (^RevenantMPSImageBinary)(NSUInteger pixel, NSUInteger channel, double primary, double secondary);

BOOL RevenantMPSImageMapUnary(MPSImage *source, MPSImage *destination, MTLRegion region,
                            RevenantMPSImageUnary fn, NSString *what);
BOOL RevenantMPSImageMapBinary(MPSImage *primaryImage, MPSImage *secondaryImage, MPSImage *destination,
                             MTLRegion region, RevenantMPSImageBinary fn, NSString *what);

MTLRegion RevenantMPSImageResolvedRegion(MPSImage *image, MTLRegion clip);

BOOL RevenantMPSImageRegionIsEmpty(MTLRegion region);

size_t RevenantMPSImageFeatureChannelSize(MPSImageFeatureChannelFormat format);

MPSDataType RevenantMPSImageDataTypeOf(MPSImageFeatureChannelFormat format);

void *_Nullable RevenantMPSImageReadRegion(MPSImage *image, const RevenantMPSImageLayout *layout, MTLRegion region, NSString *what);
BOOL RevenantMPSImageWriteRegion(MPSImage *image, const RevenantMPSImageLayout *layout, MTLRegion region, const void *buffer, NSString *what);

BOOL RevenantMPSImageConcatRows(const RevenantMPSImageLayout *source, const RevenantMPSImageLayout *destination,
                              NSUInteger offset, const void *sourceBytes, void *destinationBytes);

NS_ASSUME_NONNULL_END
