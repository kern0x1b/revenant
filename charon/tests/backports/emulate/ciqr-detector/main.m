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
