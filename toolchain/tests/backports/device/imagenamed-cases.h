#import <UIKit/UIKit.h>

static void imagenamed_write(NSString *folder, NSString *file, int pixels, BOOL jpeg)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(pixels, pixels), YES, 1);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, pixels, pixels));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *data = jpeg ? UIImageJPEGRepresentation(image, 1) : UIImagePNGRepresentation(image);
    [data writeToFile:[folder stringByAppendingPathComponent:file] atomically:YES];
}

static NSBundle *imagenamed_bundle(void)
{
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"imagenamed-%d", (int)getpid()]];
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    imagenamed_write(folder, @"plain.png", 10, NO);
    imagenamed_write(folder, @"double@2x.png", 20, NO);
    imagenamed_write(folder, @"triple@3x.png", 30, NO);
    imagenamed_write(folder, @"both.png", 10, NO);
    imagenamed_write(folder, @"both@2x.png", 20, NO);
    imagenamed_write(folder, @"idiom.png", 10, NO);
    imagenamed_write(folder, @"idiom~ipad.png", 12, NO);
    imagenamed_write(folder, @"idiom@2x~ipad.png", 24, NO);
    imagenamed_write(folder, @"photo.jpg", 16, YES);
    imagenamed_write(folder, @"three.png", 10, NO);
    imagenamed_write(folder, @"three@3x.png", 30, NO);
    return [NSBundle bundleWithPath:folder];
}

#define IMAGENAMED_NAMES @[@"plain", @"plain.png", @"double", @"triple", @"both", @"idiom", @"photo", @"photo.jpg", @"three", @"missing", @"", @"PLAIN"]
#define IMAGENAMED_SCALES @[@1, @2, @3]
#define IMAGENAMED_IDIOMS @[@(UIUserInterfaceIdiomPhone), @(UIUserInterfaceIdiomPad)]
#define IMAGENAMED_PARTIAL_TRAITS 2

static NSString *imagenamed_describe(UIImage *image)
{
    if (!image)
        return @"nil";
    return [NSString stringWithFormat:@"size %@ scale %g", NSStringFromCGSize(image.size), image.scale];
}
