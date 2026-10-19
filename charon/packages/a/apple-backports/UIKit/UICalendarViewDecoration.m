#import <UIKit/UIKit.h>
#import "CharonCalendar.h"

// What a day shows under its number: an image, a disc of colour, both (the image tinted), or a view the app makes. The decoration keeps what
// the app gave and has no getters: the release's view is its only reader, and the port's view reads it through charon_drawInRect:.
//
// The three sizes are the port's own steps: the release's sizes are not measured, since a decoration is only visible in a drawn calendar.
@implementation UICalendarViewDecoration {
@private
    UIImage *_image;
    UIColor *_color;
    UICalendarViewDecorationSize _size;
    UIView *(^_customViewProvider)(void);
}

- (instancetype)init
{
    return [self initWithImage:nil color:nil size:UICalendarViewDecorationSizeSmall];
}

- (instancetype)initWithImage:(UIImage *)image color:(UIColor *)color size:(UICalendarViewDecorationSize)size
{
    if ((self = [super init])) {
        _image = image;
        _color = color;
        _size = size;
    }
    return self;
}

- (instancetype)initWithCustomViewProvider:(UIView *(^)(void))customViewProvider
{
    if ((self = [super init])) {
        _customViewProvider = [customViewProvider copy];
        _size = UICalendarViewDecorationSizeSmall;
    }
    return self;
}

+ (instancetype)decorationWithColor:(UIColor *)color size:(UICalendarViewDecorationSize)size
{
    return [[self alloc] initWithImage:nil color:color size:size];
}

+ (instancetype)decorationWithImage:(UIImage *)image
{
    return [[self alloc] initWithImage:image color:nil size:UICalendarViewDecorationSizeSmall];
}

+ (instancetype)decorationWithImage:(UIImage *)image color:(UIColor *)color size:(UICalendarViewDecorationSize)size
{
    return [[self alloc] initWithImage:image color:color size:size];
}

+ (instancetype)decorationWithCustomViewProvider:(UIView *(^)(void))customViewProvider
{
    return [[self alloc] initWithCustomViewProvider:customViewProvider];
}

// The side of the disc, or of the image, for the size the app gave.
- (CGFloat)charon_discSide
{
    switch (_size) {
        case UICalendarViewDecorationSizeMedium: return 6;
        case UICalendarViewDecorationSizeLarge: return 8;
        default: return 4;
    }
}

- (CGFloat)charon_imageSide
{
    switch (_size) {
        case UICalendarViewDecorationSizeMedium: return 14;
        case UICalendarViewDecorationSizeLarge: return 18;
        default: return 10;
    }
}

// Drawn at the foot of the cell, centred: the custom view at its own size, the image at its side, and the disc.
- (void)charon_drawInRect:(CGRect)rect
{
    if (_customViewProvider) {
        UIView *view = _customViewProvider();
        if (view)
            [self charon_drawView:view inRect:rect];
        return;
    }
    if (_image) {
        CGFloat side = [self charon_imageSide];
        CGRect frame = CGRectMake(CGRectGetMidX(rect) - side / 2.0, CGRectGetMaxY(rect) - side - 2, side, side);
        [_image drawInRect:frame];
        if (_color) {
            [_color setFill];
            UIRectFillUsingBlendMode(frame, kCGBlendModeSourceIn);
        }
        return;
    }
    if (_color) {
        CGFloat side = [self charon_discSide];
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, _color.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(CGRectGetMidX(rect) - side / 2.0, CGRectGetMaxY(rect) - side - 2, side, side));
    }
}

// The view's layer is drawn into the cell at its own size, with its origin at the foot of the cell.
- (void)charon_drawView:(UIView *)view inRect:(CGRect)rect
{
    CGSize size = view.frame.size;
    CGRect frame = CGRectMake(CGRectGetMidX(rect) - size.width / 2.0, CGRectGetMaxY(rect) - size.height, size.width, size.height);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(frame), CGRectGetMinY(frame));
    [view layoutIfNeeded];
    [view.layer renderInContext:context];
    CGContextRestoreGState(context);
}

@end
