#import <UIKit/UIKit.h>

typedef struct {
    CGFloat radius;
    CGFloat saturation;
    CGFloat tintRed;
    CGFloat tintGreen;
    CGFloat tintBlue;
    CGFloat tintAlpha;
} CharonBlurParameters;

@interface UIBlurEffect (CharonStyle)
- (UIBlurEffectStyle)charon_style;
@end

CharonBlurParameters charon_blur_parameters(UIBlurEffectStyle style);

void charon_blur_pixels(uint8_t *pixels, size_t width, size_t height, size_t rowBytes, CGFloat sigma, CGFloat saturation, CGFloat tintRed, CGFloat tintGreen, CGFloat tintBlue, CGFloat tintAlpha);
