#import <UIKit/UIKit.h>

typedef struct {
    CGFloat radius;
    CGFloat saturation;
    CGFloat tintRed;
    CGFloat tintGreen;
    CGFloat tintBlue;
    CGFloat tintAlpha;
} RevenantBlurParameters;

@interface UIBlurEffect (RevenantStyle)
- (UIBlurEffectStyle)revenant_style;
@end

RevenantBlurParameters revenant_blur_parameters(UIBlurEffectStyle style);

void revenant_blur_pixels(uint8_t *pixels, size_t width, size_t height, size_t rowBytes, CGFloat sigma, CGFloat saturation, CGFloat tintRed, CGFloat tintGreen, CGFloat tintBlue, CGFloat tintAlpha);
