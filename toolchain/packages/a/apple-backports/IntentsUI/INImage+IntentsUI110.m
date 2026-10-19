#import <IntentsUI/IntentsUI.h>
#import <UIKit/UIKit.h>
#import "CharonIntentsUIImage.h"

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
