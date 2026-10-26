#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#ifdef __cplusplus
extern "C" {
#endif

NSArray *RevenantVisionBarcodes(id image, CGImagePropertyOrientation orientation, NSArray *symbologies, NSError **error);

#ifdef __cplusplus
}
#endif
