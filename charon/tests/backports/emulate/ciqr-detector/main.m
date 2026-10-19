// What the 6.1.3 release's own +[CIDetector detectorOfType:context:options:] answers, for the three detector types the
// host's CIFeatureType constants name and for the face type as a control. Each answer is printed as the class the
// release returns, or nil, or the exception it raises. The types are the strings the host's CIDetectorType constants
// hold, named directly, so the probe does not depend on whether the release exports those constants.
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <stdio.h>

static void answer(NSString *type) {
    @try {
        id detector = [CIDetector detectorOfType:type context:nil options:nil];
        printf("ciqr-detector: %s -> %s\n", [type UTF8String],
               detector ? [NSStringFromClass([detector class]) UTF8String] : "nil");
    } @catch (NSException *e) {
        printf("ciqr-detector: %s raised %s\n", [type UTF8String], [e.name UTF8String]);
    }
    fflush(stdout);
}

int main(void) {
    answer(@"CIDetectorTypeFace");
    answer(@"CIDetectorTypeQRCode");
    answer(@"CIDetectorTypeRectangle");
    answer(@"CIDetectorTypeText");
    return 0;
}
