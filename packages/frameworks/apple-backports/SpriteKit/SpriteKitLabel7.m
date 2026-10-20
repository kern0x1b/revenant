#import "RevenantSpriteKit.h"
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif

static NSString *const RevenantSKDefaultLabelFont = @"HelveticaNeue-UltraLight";

static RevenantSKColor *RevenantSKLabelFontColor(void)
{
#if TARGET_OS_IPHONE
    return [UIColor whiteColor];
#else
    return [NSColor colorWithRed:1 green:1 blue:1 alpha:1];
#endif
}

static RevenantSKColor *RevenantSKLabelColor(void)
{
#if TARGET_OS_IPHONE
    return [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
#else
    return [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:1];
#endif
}

static RevenantSKColor *RevenantSKLabelSRGBColor(RevenantSKColor *colour)
{
#if TARGET_OS_IPHONE
    return colour;
#else
    NSColor *converted = [colour colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    return converted != nil ? converted : colour;
#endif
}

@implementation SKLabelNode {
    NSString *_text;
    NSString *_fontName;
    CGFloat _fontSize;
    RevenantSKColor *_fontColor;
    RevenantSKColor *_color;
    CGFloat _colorBlendFactor;
    SKBlendMode _blendMode;
    SKLabelHorizontalAlignmentMode _horizontalAlignmentMode;
    SKLabelVerticalAlignmentMode _verticalAlignmentMode;
    NSInteger _numberOfLines;
    NSLineBreakMode _lineBreakMode;
    CGFloat _preferredMaxLayoutWidth;
}

@synthesize text = _text;
@synthesize fontName = _fontName;
@synthesize fontSize = _fontSize;
@synthesize fontColor = _fontColor;
@synthesize color = _color;
@synthesize colorBlendFactor = _colorBlendFactor;
@synthesize blendMode = _blendMode;
@synthesize horizontalAlignmentMode = _horizontalAlignmentMode;
@synthesize verticalAlignmentMode = _verticalAlignmentMode;
@synthesize numberOfLines = _numberOfLines;
@synthesize lineBreakMode = _lineBreakMode;
@synthesize preferredMaxLayoutWidth = _preferredMaxLayoutWidth;

- (void)setFontColor:(RevenantSKColor *)fontColor
{
    _fontColor = RevenantSKLabelSRGBColor(fontColor);
}

- (instancetype)initWithFontNamed:(NSString *)fontName
{
    self = [super init];
    if (self) {
        _fontName = [fontName copy];
        _fontSize = 32;
        _fontColor = RevenantSKLabelFontColor();
        _color = RevenantSKLabelColor();
        _horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
        _verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
        _numberOfLines = 1;
        _lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return self;
}

+ (instancetype)labelNodeWithText:(NSString *)text
{
    SKLabelNode *node = [[self alloc] initWithFontNamed:RevenantSKDefaultLabelFont];
    node.text = text;
    return node;
}

+ (instancetype)labelNodeWithFontNamed:(NSString *)fontName
{
    return [[self alloc] initWithFontNamed:fontName];
}

@end
