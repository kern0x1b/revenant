#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#ifdef __cplusplus
extern "C" {
#endif

NSData *RevenantVisionGrayscale(id image, CGImagePropertyOrientation orientation, size_t *width, size_t *height, NSError **error);

#ifdef __cplusplus
}
#endif
