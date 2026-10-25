#import <UIKit/UIKit.h>
#import "../revenant_alias.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static CGFloat revenant_rounded_to_scale(CGFloat value, CGFloat scale)
{
    if (scale <= 0)
        scale = [UIScreen mainScreen].scale;
    if (scale == 1)
        return round(value);
    return round(value * scale) / scale;
}

static CGFloat revenant_scale_for_text_style(UIFontTextStyle textStyle, UITraitCollection *traits)
{
    UIFont *preferred = [UIFont preferredFontForTextStyle:textStyle];
    UIFont *base = [UIFont preferredFontForTextStyle:textStyle];
    if (!preferred || !base || base.pointSize <= 0)
        return 1;
    return preferred.pointSize / base.pointSize;
}

REVENANT_ALIAS_STATE(UIFontMetrics, NSObject,
    UIFontTextStyle _revenantTextStyle;
)

@implementation REVENANT_ALIAS_CLASS(UIFontMetrics) (RevenantBackport)

+ (UIFontMetrics *)defaultMetrics
{
    return (UIFontMetrics *)[[self alloc] initForTextStyle:UIFontTextStyleBody];
}

+ (UIFontMetrics *)metricsForTextStyle:(UIFontTextStyle)textStyle
{
    return (UIFontMetrics *)[[self alloc] initForTextStyle:textStyle];
}

- (instancetype)initForTextStyle:(UIFontTextStyle)textStyle
{
    if ((self = [super init]))
        _revenantTextStyle = [textStyle copy];
    return self;
}

- (instancetype)init
{
    return [self initForTextStyle:UIFontTextStyleBody];
}

- (UIFont *)scaledFontForFont:(UIFont *)font
{
    return [self scaledFontForFont:font maximumPointSize:0 compatibleWithTraitCollection:nil];
}

- (UIFont *)scaledFontForFont:(UIFont *)font compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    return [self scaledFontForFont:font maximumPointSize:0 compatibleWithTraitCollection:traitCollection];
}

- (UIFont *)scaledFontForFont:(UIFont *)font maximumPointSize:(CGFloat)maximumPointSize
{
    return [self scaledFontForFont:font maximumPointSize:maximumPointSize compatibleWithTraitCollection:nil];
}

- (UIFont *)scaledFontForFont:(UIFont *)font maximumPointSize:(CGFloat)maximumPointSize
 compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    if (!font)
        [NSException raise:NSInvalidArgumentException format:@"The font passed to %@ must be non-nil.",
                                                             NSStringFromSelector(@selector(scaledFontForFont:maximumPointSize:compatibleWithTraitCollection:))];
    CGFloat size = font.pointSize * revenant_scale_for_text_style(_revenantTextStyle, traitCollection);
    if (maximumPointSize > 0 && size > maximumPointSize)
        size = maximumPointSize;
    return [font fontWithSize:size];
}

- (CGFloat)scaledValueForValue:(CGFloat)value
{
    return [self scaledValueForValue:value compatibleWithTraitCollection:nil];
}

- (CGFloat)scaledValueForValue:(CGFloat)value compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    CGFloat scale = 0;
    if ([traitCollection respondsToSelector:@selector(displayScale)])
        scale = traitCollection.displayScale;
    return revenant_rounded_to_scale(value * revenant_scale_for_text_style(_revenantTextStyle, traitCollection), scale);
}

@end
