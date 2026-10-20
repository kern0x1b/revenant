#import <UIKit/UIKit.h>

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
