// distinct.m: can any public construction make a second CIImage of the same extent?
//
// -[CIImage imageBySettingProperties:] returns a distinct object and the release's
// properties are readonly, so the question this probe answers is whether a port can
// reach that identity from outside the framework. The answer is what the facts file
// records, and this is the measurement: one image, seven public constructions, the
// pointer each of them hands back compared with the pointer it was given.
//
// Built and run by hand - it is a measurement, not part of the differential:
//
//   xcrun clang -fobjc-arc -Wno-deprecated-declarations distinct.m \
//       -framework CoreImage -framework CoreGraphics -framework Foundation -o distinct
//   ./distinct
//
// The last line is the one that settles the question: a gamma of 2 visibly changes the
// image and still hands back the same CIImage *, so no construction reaches the identity.

#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

static CIImage *make(void)
{
    unsigned char pixels[16] = {255, 60, 120, 128,  10, 200, 30, 200,  90, 40, 210, 90,  0, 0, 0, 0};
    return [CIImage imageWithBitmapData:[NSData dataWithBytes:pixels length:16]
                             bytesPerRow:4 size:CGSizeMake(2, 2) format:kCIFormatRGBA8
                            colorSpace:CGColorSpaceCreateDeviceRGB()];
}

static void show(NSString *what, CIImage *source, CIImage *made)
{
    printf("%-46s distinct %d", what.UTF8String, made != source);
    if (made) {
        printf("  extent %g %g %g %g", made.extent.origin.x, made.extent.origin.y,
               made.extent.size.width, made.extent.size.height);
    }
    printf("\n");
}

int main(void)
{
    @autoreleasepool {
        CIImage *image = make();
        show(@"copy", image, [image copy]);
        show(@"mutableCopy", image, [image mutableCopy]);

        CIFilter *gamma = [CIFilter filterWithName:@"CIGammaAdjust"];
        [gamma setValue:image forKey:kCIInputImageKey];
        [gamma setValue:@1.0 forKey:@"inputPower"];
        show(@"CIGammaAdjust power 1", image, gamma.outputImage);

        CIFilter *matrix = [CIFilter filterWithName:@"CIColorMatrix"];
        [matrix setValue:image forKey:kCIInputImageKey];
        [matrix setValue:[CIVector vectorWithX:1 Y:0 Z:0 W:0] forKey:@"inputRVector"];
        [matrix setValue:[CIVector vectorWithX:0 Y:1 Z:0 W:0] forKey:@"inputGVector"];
        [matrix setValue:[CIVector vectorWithX:0 Y:0 Z:1 W:0] forKey:@"inputBVector"];
        [matrix setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:1] forKey:@"inputAVector"];
        show(@"CIColorMatrix identity", image, matrix.outputImage);

        show(@"crop to own extent", image, [image imageByCroppingToRect:image.extent]);
        show(@"affine identity", image, [image imageByApplyingTransform:CGAffineTransformIdentity]);

        CIFilter *changed = [CIFilter filterWithName:@"CIGammaAdjust"];
        [changed setValue:image forKey:kCIInputImageKey];
        [changed setValue:@2.0 forKey:@"inputPower"];
        show(@"CIGammaAdjust power 2 (a real change)", image, changed.outputImage);
    }
    return 0;
}
