#import <UIKit/UIKit.h>
#import "RevenantCalendar.h"

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

- (CGFloat)revenant_discSide
{
    switch (_size) {
        case UICalendarViewDecorationSizeMedium: return 6;
        case UICalendarViewDecorationSizeLarge: return 8;
        default: return 4;
    }
}

- (CGFloat)revenant_imageSide
{
    switch (_size) {
        case UICalendarViewDecorationSizeMedium: return 14;
        case UICalendarViewDecorationSizeLarge: return 18;
        default: return 10;
    }
}

- (void)revenant_drawInRect:(CGRect)rect
{
    if (_customViewProvider) {
        UIView *view = _customViewProvider();
        if (view)
            [self revenant_drawView:view inRect:rect];
        return;
    }
    if (_image) {
        CGFloat side = [self revenant_imageSide];
        CGRect frame = CGRectMake(CGRectGetMidX(rect) - side / 2.0, CGRectGetMaxY(rect) - side - 2, side, side);
        [_image drawInRect:frame];
        if (_color) {
            [_color setFill];
            UIRectFillUsingBlendMode(frame, kCGBlendModeSourceIn);
        }
        return;
    }
    if (_color) {
        CGFloat side = [self revenant_discSide];
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, _color.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(CGRectGetMidX(rect) - side / 2.0, CGRectGetMaxY(rect) - side - 2, side, side));
    }
}

- (void)revenant_drawView:(UIView *)view inRect:(CGRect)rect
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
