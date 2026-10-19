#import "CharonSwipeViews.h"

static const CGFloat CharonSwipeMinimumPad = 63;
static const CGFloat CharonSwipePadPadding = 11.5f;
static BOOL charon_swipe_phone(void)
{
    return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
}

static CGFloat charon_swipe_pad_height(void)
{
    return 33;
}

static const CGFloat CharonSwipeGap = 3;
static const CGFloat CharonSwipeEdge = 6;

static UIFont *charon_swipe_font(void)
{
    return [UIFont boldSystemFontOfSize:14];
}

CGFloat charon_swipe_width(NSString *title)
{
    CGFloat text = title.length ? ceilf([title sizeWithAttributes:@{NSFontAttributeName: charon_swipe_font()}].width) : 0;
    return MAX(CharonSwipeMinimumPad, text + 2 * CharonSwipePadPadding) + 2 * CharonSwipeGap;
}

static UIColor *charon_swipe_rgb(CGFloat r, CGFloat g, CGFloat b)
{
    return [UIColor colorWithRed:r / 255 green:g / 255 blue:b / 255 alpha:1];
}

static UIColor *charon_swipe_hsv(CGFloat h, CGFloat s, CGFloat v)
{
    return [UIColor colorWithHue:h saturation:MIN(1, MAX(0, s)) brightness:MIN(1, MAX(0, v)) alpha:1];
}

typedef struct {
    CGFloat top[3], highlight[3], gradientTop[3], gradientBottom[3], flat[3], borderTop[3], borderUpper[3], borderSide[3], borderBottom[3];
    CGFloat rows;
    CGFloat borderRows;
    CGFloat gradientRows;
} CharonSwipePalette;

static void charon_swipe_set(CGFloat out[3], CGFloat r, CGFloat g, CGFloat b)
{
    out[0] = r / 255;
    out[1] = g / 255;
    out[2] = b / 255;
}

static void charon_swipe_derive(CGFloat out[3], CGFloat h, CGFloat s, CGFloat v)
{
    CGFloat r, g, b;
    UIColor *color = charon_swipe_hsv(h, s, v);
    [color getRed:&r green:&g blue:&b alpha:NULL];
    out[0] = r;
    out[1] = g;
    out[2] = b;
}

static CharonSwipePalette charon_swipe_palette(UIColor *base)
{
    CharonSwipePalette palette;
    palette.rows = 33;
    palette.borderRows = 1;
    palette.gradientRows = 15;
    CGFloat r = 1, g = 0.23f, b = 0.19f;
    [base getRed:&r green:&g blue:&b alpha:NULL];
    UIColor *system = [UIColor systemRedColor];
    CGFloat sr, sg, sb;
    [system getRed:&sr green:&sg blue:&sb alpha:NULL];
    if (fabsf(r - sr) < 0.02f && fabsf(g - sg) < 0.02f && fabsf(b - sb) < 0.02f && charon_swipe_phone()) {
        palette.rows = 66;
        palette.borderRows = 2;
        palette.gradientRows = 31;
        charon_swipe_set(palette.borderTop, 44, 28, 28);
        charon_swipe_set(palette.highlight, 205, 128, 131);
        charon_swipe_set(palette.gradientTop, 246, 152, 156);
        charon_swipe_set(palette.gradientBottom, 214, 74, 78);
        charon_swipe_set(palette.flat, 207, 43, 45);
        charon_swipe_set(palette.borderUpper, 107, 59, 61);
        charon_swipe_set(palette.borderSide, 95, 20, 21);
        charon_swipe_set(palette.borderBottom, 114, 24, 25);
        return palette;
    }
    if (fabsf(r - sr) < 0.02f && fabsf(g - sg) < 0.02f && fabsf(b - sb) < 0.02f) {
        charon_swipe_set(palette.borderTop, 91, 52, 54);
        charon_swipe_set(palette.highlight, 199, 111, 116);
        charon_swipe_set(palette.gradientTop, 237, 130, 136);
        charon_swipe_set(palette.gradientBottom, 200, 54, 64);
        charon_swipe_set(palette.flat, 189, 20, 33);
        charon_swipe_set(palette.borderUpper, 139, 69, 74);
        charon_swipe_set(palette.borderSide, 122, 13, 22);
        charon_swipe_set(palette.borderBottom, 147, 16, 26);
        return palette;
    }
    CGFloat h, s, v;
    [[UIColor colorWithRed:r green:g blue:b alpha:1] getHue:&h saturation:&s brightness:&v alpha:NULL];
    charon_swipe_derive(palette.flat, h, s * 1.05f, v * 0.8f);
    charon_swipe_derive(palette.gradientTop, h, s * 0.5f, MIN(1, v * 1.05f + 0.15f));
    charon_swipe_derive(palette.gradientBottom, h, s * 0.85f, v * 0.9f);
    charon_swipe_derive(palette.highlight, h, s * 0.6f, MIN(1, v * 0.9f + 0.1f));
    charon_swipe_derive(palette.borderTop, h, s * 0.4f, v * 0.36f);
    charon_swipe_derive(palette.borderUpper, h, s * 0.55f, v * 0.55f);
    charon_swipe_derive(palette.borderSide, h, s, v * 0.5f);
    charon_swipe_derive(palette.borderBottom, h, s, v * 0.6f);
    return palette;
}

static void charon_swipe_fill(CGContextRef context, CGRect rect, CGFloat color[3])
{
    CGContextSetRGBFillColor(context, color[0], color[1], color[2], 1);
    CGContextFillRect(context, rect);
}

static void charon_swipe_pad(CGContextRef context, CGRect pad, UIColor *base, BOOL pressed)
{
    CharonSwipePalette palette = charon_swipe_palette(base);
    CGFloat radius = 4.5f;
    CGContextSaveGState(context);
    [[UIBezierPath bezierPathWithRoundedRect:pad cornerRadius:radius] addClip];
    CGFloat unit = pad.size.height / palette.rows;
    CGFloat edge = palette.borderRows * unit;
    CGFloat gradient_rows = palette.gradientRows;
    CGFloat x = pad.origin.x, y = pad.origin.y, w = pad.size.width;
    CGFloat gradientStart = edge + unit;
    CGFloat flatStart = gradientStart + gradient_rows * unit;
    charon_swipe_fill(context, CGRectMake(x, y + flatStart, w, pad.size.height - flatStart), palette.borderSide);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat borderColors[8] = {palette.borderTop[0], palette.borderTop[1], palette.borderTop[2], 1, palette.borderUpper[0], palette.borderUpper[1], palette.borderUpper[2], 1};
    CGGradientRef borderGradient = CGGradientCreateWithColorComponents(space, borderColors, NULL, 2);
    CGContextDrawLinearGradient(context, borderGradient, CGPointMake(x, y), CGPointMake(x, y + flatStart), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(borderGradient);
    charon_swipe_fill(context, CGRectMake(x, y + pad.size.height - edge, w, edge), palette.borderBottom);
    CGContextRestoreGState(context);

    CGContextSaveGState(context);
    CGRect inner = CGRectMake(x + edge, y + edge, w - 2 * edge, pad.size.height - 2 * edge);
    [[UIBezierPath bezierPathWithRoundedRect:inner cornerRadius:MAX(0, radius - edge)] addClip];
    charon_swipe_fill(context, CGRectMake(x, y + edge, w, unit), palette.highlight);
    CGFloat gradient[8] = {palette.gradientTop[0], palette.gradientTop[1], palette.gradientTop[2], 1, palette.gradientBottom[0], palette.gradientBottom[1], palette.gradientBottom[2], 1};
    CGGradientRef fill = CGGradientCreateWithColorComponents(space, gradient, NULL, 2);
    CGContextSaveGState(context);
    CGContextClipToRect(context, CGRectMake(x, y + gradientStart, w, gradient_rows * unit));
    CGContextDrawLinearGradient(context, fill, CGPointMake(x, y + gradientStart), CGPointMake(x, y + flatStart), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGContextRestoreGState(context);
    CGGradientRelease(fill);
    charon_swipe_fill(context, CGRectMake(x, y + flatStart, w, pad.size.height - flatStart - edge), palette.flat);
    if (pressed) {
        CGContextSetRGBFillColor(context, 0, 0, 0, 0.25f);
        CGContextFillRect(context, pad);
    }
    CGColorSpaceRelease(space);
    CGContextRestoreGState(context);
}

@implementation CharonSwipeItem
@synthesize title = _title;
@synthesize image = _image;
@synthesize color = _color;
@synthesize action = _action;
@synthesize width = _width;

@end

@implementation CharonSwipeButton {
    UILabel *_label;
    UIImageView *_icon;
}
@synthesize item = _item;
@synthesize edgeInsetLeft = _edgeInsetLeft;
@synthesize edgeInsetRight = _edgeInsetRight;

- (instancetype)initWithItem:(CharonSwipeItem *)item
{
    if ((self = [super initWithFrame:CGRectZero])) {
        _item = item;
        _edgeInsetLeft = _edgeInsetRight = CharonSwipeGap;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.clipsToBounds = YES;
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.text = item.title;
        _label.font = charon_swipe_font();
        _label.textColor = [UIColor whiteColor];
        _label.shadowColor = [UIColor colorWithWhite:0 alpha:0.5f];
        _label.shadowOffset = CGSizeMake(0, -1);
        _label.backgroundColor = [UIColor clearColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.lineBreakMode = NSLineBreakByClipping;
        [self addSubview:_label];
        if (item.image) {
            _icon = [[UIImageView alloc] initWithImage:item.image];
            _icon.contentMode = UIViewContentModeScaleAspectFit;
            [self addSubview:_icon];
        }
    }
    return self;
}

- (CGRect)padRect
{
    CGRect bounds = self.bounds;
    CGFloat height = MIN(charon_swipe_pad_height(), bounds.size.height - 4);
    CGFloat left = _edgeInsetLeft, right = _edgeInsetRight;
    return CGRectMake(left, floorf((bounds.size.height - height) / 2), MAX(0, bounds.size.width - left - right), height);
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}

- (void)setEdgeInsetLeft:(CGFloat)inset
{
    _edgeInsetLeft = inset;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)setEdgeInsetRight:(CGFloat)inset
{
    _edgeInsetRight = inset;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGRect pad = [self padRect];
    if (pad.size.width < 1)
        return;
    charon_swipe_pad(UIGraphicsGetCurrentContext(), pad, _item.color ?: [UIColor colorWithRed:0.55f green:0.56f blue:0.6f alpha:1], self.highlighted);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect pad = [self padRect];
    CGFloat labelHeight = 16;
    if (_icon) {
        CGFloat side = MIN(20, pad.size.height - labelHeight - 4);
        CGFloat top = pad.origin.y + floorf((pad.size.height - side - labelHeight) / 2);
        _icon.frame = CGRectMake(pad.origin.x + floorf((pad.size.width - side) / 2), top, side, side);
        _label.frame = CGRectMake(pad.origin.x, top + side, pad.size.width, labelHeight);
    } else {
        _label.frame = CGRectMake(pad.origin.x, pad.origin.y + floorf((pad.size.height - labelHeight) / 2), pad.size.width, labelHeight);
    }
}

@end

@implementation CharonSwipeContainer
@synthesize buttons = _buttons;
@synthesize side = _side;
@synthesize totalWidth = _totalWidth;


- (void)setOffset:(CGFloat)offset inCellWidth:(CGFloat)cellWidth height:(CGFloat)height
{
    CGFloat shown = fabsf(offset);
    self.frame = CGRectMake(_side < 0 ? cellWidth - shown : 0, 0, shown, height);
    CGFloat scale = shown <= _totalWidth || _totalWidth == 0 ? (_totalWidth == 0 ? 0 : shown / _totalWidth) : 1;
    CGFloat extra = shown > _totalWidth ? shown - _totalWidth : 0;
    NSUInteger count = _buttons.count;
    CGFloat x = 0;
    for (NSUInteger visual = 0; visual < count; visual++) {
        NSUInteger index = _side < 0 ? count - 1 - visual : visual;
        CharonSwipeButton *button = _buttons[index];
        CGFloat width = button.item.width * scale + (index == 0 ? extra : 0);
        button.frame = CGRectMake(x, 0, width, height);
        BOOL outer = index == 0;
        button.edgeInsetLeft = _side < 0 || !outer ? CharonSwipeGap : CharonSwipeEdge;
        button.edgeInsetRight = _side < 0 && outer ? CharonSwipeEdge : CharonSwipeGap;
        x += width;
    }
}

@end

