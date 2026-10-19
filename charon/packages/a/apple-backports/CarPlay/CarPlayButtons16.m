#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>

static CGRect CharonCarPlayFit(CGSize size, CGRect rect)
{
    if (size.width <= 0.0 || size.height <= 0.0) {
        return rect;
    }
    CGFloat scale = MIN(CGRectGetWidth(rect) / size.width, CGRectGetHeight(rect) / size.height);
    CGSize fitted = CGSizeMake(size.width * scale, size.height * scale);
    return CGRectMake(CGRectGetMidX(rect) - fitted.width / 2.0, CGRectGetMidY(rect) - fitted.height / 2.0,
                       fitted.width, fitted.height);
}

@implementation CPButton {
    UIImage *_image;
    NSString *_title;
    BOOL _enabled;
    void (^_handler)(__kindof CPButton *);
}

@synthesize title = _title;

- (instancetype)initWithImage:(UIImage *)image handler:(void (^)(__kindof CPButton *))handler
{
    self = [super init];
    if (self) {
        _image = image;
        _handler = [handler copy];
        _enabled = YES;
    }
    return self;
}

- (UIImage *)image
{
    return _image;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

- (void)charon_drawInRect:(CGRect)rect
{
    if (CGRectIsEmpty(rect)) {
        return;
    }
    CGFloat alpha = _enabled ? 1.0 : 0.4;
    if (_image) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (context) {
            CGContextSaveGState(context);
            CGContextSetAlpha(context, (CGFloat)alpha);
            [_image drawInRect:CharonCarPlayFit(_image.size, rect)];
            CGContextRestoreGState(context);
        }
        return;
    }
    if (_title.length > 0) {
        NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                                     NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:alpha]};
        CGSize text = [_title sizeWithAttributes:attributes];
        [_title drawAtPoint:CGPointMake(CGRectGetMidX(rect) - text.width / 2.0,
                                         CGRectGetMidY(rect) - text.height / 2.0)
             withAttributes:attributes];
        return;
    }
    UIBezierPath *plate = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 4.0, 4.0) cornerRadius:8.0];
    [[UIColor colorWithWhite:1.0 alpha:0.2 * alpha] setFill];
    [plate fill];
    [[UIColor colorWithWhite:1.0 alpha:alpha] setStroke];
    plate.lineWidth = 2.0;
    [plate stroke];
}

- (void)charon_tap
{
    if (_handler) {
        _handler(self);
    }
}

@end

@implementation CPTextButton {
    NSString *_title;
    CPTextButtonStyle _textStyle;
    void (^_handler)(__kindof CPTextButton *);
}

@synthesize title = _title;
@synthesize textStyle = _textStyle;

- (instancetype)initWithTitle:(NSString *)title
                    textStyle:(CPTextButtonStyle)textStyle
                      handler:(void (^)(__kindof CPTextButton *contactButton))handler
{
    self = [super init];
    if (self) {
        _title = [title copy] ?: @"";
        _textStyle = textStyle;
        _handler = [handler copy];
    }
    return self;
}

- (void)charon_drawInRect:(CGRect)rect
{
    if (CGRectIsEmpty(rect) || _title.length == 0) {
        return;
    }
    UIColor *background = [UIColor clearColor];
    if (_textStyle == CPTextButtonStyleConfirm) {
        background = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    } else if (_textStyle == CPTextButtonStyleCancel) {
        background = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    }
    if (background != [UIColor clearColor]) {
        UIBezierPath *plate = [UIBezierPath bezierPathWithRoundedRect:rect
                                                      cornerRadius:CGRectGetHeight(rect) / 2.0];
        [background setFill];
        [plate fill];
    }
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                                 NSForegroundColorAttributeName: [UIColor whiteColor]};
    CGSize text = [_title sizeWithAttributes:attributes];
    [_title drawAtPoint:CGPointMake(CGRectGetMidX(rect) - text.width / 2.0,
                                     CGRectGetMidY(rect) - text.height / 2.0)
         withAttributes:attributes];
}

- (void)charon_tap
{
    if (_handler) {
        _handler(self);
    }
}

@end
