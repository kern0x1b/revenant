#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "RevenantPDFObjects.h"

NS_ASSUME_NONNULL_BEGIN

extern const double RevenantPDFDefaultImageQuality;

typedef struct {
    CGRect mediaBox;
    CGAffineTransform placement;
} RevenantPDFImagePlacement;

typedef struct {
    BOOL hasMediaBox;
    CGRect mediaBox;
    NSInteger rotation;
    BOOL upscaleIfSmaller;
    double quality;
} RevenantPDFImagePage;

RevenantPDFImagePlacement RevenantPDFPlaceImage(size_t width, size_t height, BOOL hasMediaBox, CGRect mediaBox, NSInteger rotation,
                                                BOOL upscaleIfSmaller);

RevenantPDFReference *_Nullable RevenantPDFAddImage(RevenantPDFWriter *writer, CGImageRef image, double quality);

NSData *_Nullable RevenantPDFImagePageData(CGImageRef image, RevenantPDFImagePage page);

NSData *RevenantPDFBlankPageData(CGRect mediaBox);

NS_ASSUME_NONNULL_END
