#import "../Foundation/check.h"
#import <CoreImage/CoreImage.h>

static BOOL revenant_same_transform(CGAffineTransform a, CGAffineTransform b)
{
    return a.a == b.a && a.b == b.b && a.c == b.c && a.d == b.d && a.tx == b.tx && a.ty == b.ty;
}

static BOOL revenant_same_rect(CGRect a, CGRect b)
{
    return a.origin.x == b.origin.x && a.origin.y == b.origin.y && a.size.width == b.size.width && a.size.height == b.size.height;
}

static CIImage *revenant_image(CGRect rect)
{
    return [[CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0]] imageByCroppingToRect:rect];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    CGRect rects[] = {CGRectMake(0, 0, 100, 60), CGRectMake(10, 20, 100, 60), CGRectMake(-30, 15, 48, 160)};
    BOOL transforms = YES;
    BOOL extents = YES;
    for (size_t index = 0; index < sizeof rects / sizeof rects[0]; index++) {
        CIImage *image = revenant_image(rects[index]);
        for (int orientation = -1; orientation <= 9; orientation++) {
            CGImagePropertyOrientation named = (CGImagePropertyOrientation)orientation;
            transforms = transforms && revenant_same_transform([image imageTransformForCGOrientation:named], [image imageTransformForOrientation:orientation]);
            extents = extents && revenant_same_rect([image imageByApplyingCGOrientation:named].extent, [image imageByApplyingOrientation:orientation].extent);
        }
    }
    revenant_check(transforms != revenant_negative, "the transform of a CGImagePropertyOrientation is the transform of the same number as an EXIF orientation", @"a transform differs between the two forms");
    revenant_check(extents != revenant_negative, "applying a CGImagePropertyOrientation gives the extent of applying the same number as an EXIF orientation", @"an oriented extent differs between the two forms");

    CIImage *unbounded = [CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0]];
    BOOL infinites = revenant_same_transform([unbounded imageTransformForCGOrientation:kCGImagePropertyOrientationRight], [unbounded imageTransformForOrientation:6])
        && revenant_same_transform([unbounded imageTransformForOrientation:6], CGAffineTransformIdentity);
    revenant_check(infinites != revenant_negative, "an image of infinite extent keeps the identity transform in both forms", @"an infinite extent was transformed");

    CGRect rect = CGRectMake(10, 20, 100, 60);
    CGRect turned = CGRectApplyAffineTransform(rect, [revenant_image(rect) imageTransformForCGOrientation:kCGImagePropertyOrientationRight]);
    revenant_check((turned.size.width == 60 && turned.size.height == 100) != revenant_negative, "the right orientation swaps width and height", @"the sides of the turned rect were not swapped");

    return revenant_finish();
}
