#import <IntentsUI/IntentsUI.h>
#import <UIKit/UIKit.h>
#import "RevenantIntentsUIImage.h"

@implementation INImage (RevenantIntentsUI110)

- (void)fetchUIImageWithCompletion:(void (^)(UIImage *image))completion
{
    NSData *bytes = [self revenant_imageData];
    if (bytes) {
        completion([UIImage imageWithData:bytes]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(nil);
    });
}

@end
