#import "imagetraits-cases.h"

static NSString *describe(UITraitCollection *traits)
{
    return [NSString stringWithFormat:@"scale %g idiom %ld horizontal %ld vertical %ld", traits.displayScale, (long)traits.userInterfaceIdiom, (long)traits.horizontalSizeClass, (long)traits.verticalSizeClass];
}

void imagetraits_run(UIWindow *window, ImageTraitsRecorder record)
{
    for (NSNumber *scale in @[@1, @2, @3]) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 10), YES, scale.doubleValue);
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        record([NSString stringWithFormat:@"bitmap at %@", scale], describe(image.traitCollection));
        UIImage *remade = [UIImage imageWithCGImage:image.CGImage scale:scale.doubleValue + 1 orientation:UIImageOrientationUp];
        record([NSString stringWithFormat:@"remade at %g", scale.doubleValue + 1], describe(remade.traitCollection));
        UIImage *resizable = [image resizableImageWithCapInsets:UIEdgeInsetsMake(1, 1, 1, 1)];
        record([NSString stringWithFormat:@"resizable at %@", scale], describe(resizable.traitCollection));
    }
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 10), YES, 2);
    UIImage *first = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 5), NO, 2);
    UIImage *second = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    record(@"equal at one scale", [NSString stringWithFormat:@"%d", [first.traitCollection isEqual:second.traitCollection]]);
}
