#import <IntentsUI/IntentsUI.h>
#import <UIKit/UIKit.h>
#import "CharonIntentsUIImage.h"

// The one INImage member of IntentsUI that arrived with iOS 11: the image's bytes decoded into a UIImage. Measured on
// the Catalyst host (tests/backports/host/inimage-bridge), and the port matches it on every case the probe builds:
// an image that carries bytes calls the completion before the call returns, on the calling thread, with a UIImage
// of the PNG's size, or nil for bytes that are not an image (the raw bytes of a CGImage). An image with no bytes
// calls the completion later, on a background queue, with nil. A URL-backed image is named in facts/IntentsUI: the
// port reads its URL when the image is made, so it is data-backed here.

@implementation INImage (CharonIntentsUI110)

- (void)fetchUIImageWithCompletion:(void (^)(UIImage *image))completion
{
    NSData *bytes = [self charon_imageData];
    if (bytes) {
        completion([UIImage imageWithData:bytes]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(nil);
    });
}

@end
