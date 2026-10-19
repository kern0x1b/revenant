// SpriteKitLabel7.m - SKLabelNode of iOS 7, carried for the releases that have no SpriteKit at all.
//
// A label is a node that shows a text in a font, with its colour, its alignment and its line layout. The text and its
// members are stored and read back, as the host stores them (measured against the host's own SpriteKit in
// facts/SpriteKit/SKLabelNode.md). Nothing here is rasterised yet: the text is the renderer's, which is owed.
#import "CharonSpriteKit.h"
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif

// The font of a new label: the host's own default (measured on macOS 27.0.1). The iOS default is not measured on a device.
static NSString *const CharonSKDefaultLabelFont = @"HelveticaNeue-UltraLight";

// The colours of a new label: the font colour is white in the sRGB space and the colour is white in the device space,
// as the host gives them (measured).
static CharonSKColor *CharonSKLabelFontColor(void)
{
#if TARGET_OS_IPHONE
    return [UIColor whiteColor];
#else
    return [NSColor colorWithRed:1 green:1 blue:1 alpha:1];
#endif
}

static CharonSKColor *CharonSKLabelColor(void)
{
#if TARGET_OS_IPHONE
    return [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
#else
    return [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:1];
#endif
}

// The font colour as the host keeps it when it is set: in the sRGB space (measured on macOS, facts/SpriteKit/SKLabelNode.md).
static CharonSKColor *CharonSKLabelSRGBColor(CharonSKColor *colour)
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
    CharonSKColor *_fontColor;
    CharonSKColor *_color;
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

- (void)setFontColor:(CharonSKColor *)fontColor
{
    _fontColor = CharonSKLabelSRGBColor(fontColor);
}

- (instancetype)initWithFontNamed:(NSString *)fontName
{
    self = [super init];
    if (self) {
        _fontName = [fontName copy];
        _fontSize = 32;
        _fontColor = CharonSKLabelFontColor();
        _color = CharonSKLabelColor();
        _horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
        _verticalAlignmentMode = SKLabelVerticalAlignmentModeBaseline;
        _numberOfLines = 1;
        _lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return self;
}

// The host gives a label made from text the default font, and the text as given (measured).
+ (instancetype)labelNodeWithText:(NSString *)text
{
    SKLabelNode *node = [[self alloc] initWithFontNamed:CharonSKDefaultLabelFont];
    node.text = text;
    return node;
}

+ (instancetype)labelNodeWithFontNamed:(NSString *)fontName
{
    return [[self alloc] initWithFontNamed:fontName];
}

@end
