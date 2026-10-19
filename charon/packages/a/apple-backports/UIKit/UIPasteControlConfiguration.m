#import <UIKit/UIKit.h>

// The defaults the host's -init answers, measured by tests/backports/host/paste-config: an icon and a label, the cornerStyle the host
// gives (2), no corner radius, the image on the leading edge (NSDirectionalRectEdgeLeading), and no colours. The first two are not zero,
// so -init sets them; the release's -init is the constructor the SDK does not mark unavailable.
//
// The class is NSSecureCoding: each property is archived under its own name, and an archive decodes to the same six values.
@implementation UIPasteControlConfiguration {
@private
    UIPasteControlDisplayMode _displayMode;
    UIButtonConfigurationCornerStyle _cornerStyle;
    CGFloat _cornerRadius;
    NSDirectionalRectEdge _imagePlacement;
    UIColor *_baseForegroundColor;
    UIColor *_baseBackgroundColor;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _cornerStyle = 2;
        _imagePlacement = NSDirectionalRectEdgeLeading;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _displayMode = [coder decodeIntegerForKey:@"displayMode"];
        _cornerStyle = [coder decodeIntegerForKey:@"cornerStyle"];
        _cornerRadius = [coder decodeDoubleForKey:@"cornerRadius"];
        _imagePlacement = [coder decodeIntegerForKey:@"imagePlacement"];
        _baseForegroundColor = [coder decodeObjectForKey:@"baseForegroundColor"];
        _baseBackgroundColor = [coder decodeObjectForKey:@"baseBackgroundColor"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_displayMode forKey:@"displayMode"];
    [coder encodeInteger:_cornerStyle forKey:@"cornerStyle"];
    [coder encodeDouble:_cornerRadius forKey:@"cornerRadius"];
    [coder encodeInteger:_imagePlacement forKey:@"imagePlacement"];
    [coder encodeObject:_baseForegroundColor forKey:@"baseForegroundColor"];
    [coder encodeObject:_baseBackgroundColor forKey:@"baseBackgroundColor"];
}

- (UIPasteControlDisplayMode)displayMode
{
    return _displayMode;
}

- (void)setDisplayMode:(UIPasteControlDisplayMode)displayMode
{
    _displayMode = displayMode;
}

- (UIButtonConfigurationCornerStyle)cornerStyle
{
    return _cornerStyle;
}

- (void)setCornerStyle:(UIButtonConfigurationCornerStyle)cornerStyle
{
    _cornerStyle = cornerStyle;
}

- (CGFloat)cornerRadius
{
    return _cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = cornerRadius;
}

- (NSDirectionalRectEdge)imagePlacement
{
    return _imagePlacement;
}

- (void)setImagePlacement:(NSDirectionalRectEdge)imagePlacement
{
    _imagePlacement = imagePlacement;
}

- (UIColor *)baseForegroundColor
{
    return _baseForegroundColor;
}

- (void)setBaseForegroundColor:(UIColor *)baseForegroundColor
{
    _baseForegroundColor = baseForegroundColor;
}

- (UIColor *)baseBackgroundColor
{
    return _baseBackgroundColor;
}

- (void)setBaseBackgroundColor:(UIColor *)baseBackgroundColor
{
    _baseBackgroundColor = baseBackgroundColor;
}

@end
