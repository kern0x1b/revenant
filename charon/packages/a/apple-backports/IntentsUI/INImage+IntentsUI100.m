#import <CoreGraphics/CoreGraphics.h>
#import <IntentsUI/IntentsUI.h>
#import <UIKit/UIKit.h>
#import "CharonIntentsUIImage.h"

// The three INImage members of IntentsUI that arrived with iOS 10. The first two resolve a UIImage or a
// CGImage into an Intents image, which the port keeps as the bytes the release's own image holds: a UIImage
// as its PNG, through UIImagePNGRepresentation, which iOS 6 has; a CGImage as the bytes of its data provider,
// unencoded. Both are measured against the Catalyst host (tests/backports/host/inimage-bridge): the host's
// imageWithUIImage: and imageWithCGImage: answer an image object with the bytes in exactly those forms, and
// the host's imageWithUIImage:nil answers an object whose bytes are nil rather than nil itself.
// imageSizeForIntentResponse: answers 60 by 60 for every input the host was asked with: nil, four response
// classes and a plain NSObject. The value is the host's measured answer, not a stand-in for one.

@implementation INImage (CharonIntentsUI100)

+ (instancetype)imageWithUIImage:(UIImage *)image
{
    NSData *bytes = image ? UIImagePNGRepresentation(image) : nil;
    return [self charon_imageWithName:nil data:bytes width:0 height:0];
}

+ (instancetype)imageWithCGImage:(CGImageRef)image
{
    NSData *bytes = nil;
    if (image)
        bytes = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(image));
    return [self charon_imageWithName:nil data:bytes width:0 height:0];
}

+ (CGSize)imageSizeForIntentResponse:(id)response
{
    return CGSizeMake(60, 60);
}

@end
