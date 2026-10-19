#import <CoreGraphics/CoreGraphics.h>
#import <IntentsUI/IntentsUI.h>
#import <UIKit/UIKit.h>
#import "CharonIntentsUIImage.h"

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
