#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

static const CGFloat CharonTextInsetX = 14;
static const CGFloat CharonTextInsetY = 10;
static const CGFloat CharonTextCornerRadius = 13;

static UIColor *charon_default_background(void)
{
    if ([UIColor respondsToSelector:@selector(systemBackgroundColor)])
        return [UIColor systemBackgroundColor];
    return [UIColor whiteColor];
}

static void charon_add_line_rect(UIBezierPath *path, CGRect rect)
{
    CGFloat r = MIN(CharonTextCornerRadius, MIN(CGRectGetWidth(rect) + 2 * CharonTextInsetX, CGRectGetHeight(rect) + 2 * CharonTextInsetY) / 2);
    const CGFloat e = 1.528665f * r, a = 1.0884929576185292f * r, b = 0.8684069440630023f * r, c = 0.6314937928309926f * r;
    const CGFloat d = 0.07491138784701594f * r, f = 0.3728238266257468f * r, g = 0.16905955604436995f * r;
    CGFloat x0 = CGRectGetMinX(rect) - CharonTextInsetX, x1 = CGRectGetMaxX(rect) + CharonTextInsetX;
    CGFloat y0 = CGRectGetMinY(rect) - CharonTextInsetY, y1 = CGRectGetMaxY(rect) + CharonTextInsetY;
    [path moveToPoint:CGPointMake(x0 + e, y1)];
    [path addCurveToPoint:CGPointMake(x0 + c, y1 - d) controlPoint1:CGPointMake(x0 + a, y1) controlPoint2:CGPointMake(x0 + b, y1)];
    [path addLineToPoint:CGPointMake(x0 + c, y1 - d)];
    [path addCurveToPoint:CGPointMake(x0 + d, y1 - c) controlPoint1:CGPointMake(x0 + f, y1 - g) controlPoint2:CGPointMake(x0 + g, y1 - f)];
    [path addCurveToPoint:CGPointMake(x0, y1 - e) controlPoint1:CGPointMake(x0, y1 - b) controlPoint2:CGPointMake(x0, y1 - a)];
    [path addLineToPoint:CGPointMake(x0, y0 + e)];
    [path addCurveToPoint:CGPointMake(x0 + d, y0 + c) controlPoint1:CGPointMake(x0, y0 + a) controlPoint2:CGPointMake(x0, y0 + b)];
    [path addLineToPoint:CGPointMake(x0 + d, y0 + c)];
    [path addCurveToPoint:CGPointMake(x0 + c, y0 + d) controlPoint1:CGPointMake(x0 + g, y0 + f) controlPoint2:CGPointMake(x0 + f, y0 + g)];
    [path addCurveToPoint:CGPointMake(x0 + e, y0) controlPoint1:CGPointMake(x0 + b, y0) controlPoint2:CGPointMake(x0 + a, y0)];
    [path addLineToPoint:CGPointMake(x1 - e, y0)];
    [path addCurveToPoint:CGPointMake(x1 - c, y0 + d) controlPoint1:CGPointMake(x1 - a, y0) controlPoint2:CGPointMake(x1 - b, y0)];
    [path addLineToPoint:CGPointMake(x1 - c, y0 + d)];
    [path addCurveToPoint:CGPointMake(x1 - d, y0 + c) controlPoint1:CGPointMake(x1 - f, y0 + g) controlPoint2:CGPointMake(x1 - g, y0 + f)];
    [path addCurveToPoint:CGPointMake(x1, y0 + e) controlPoint1:CGPointMake(x1, y0 + b) controlPoint2:CGPointMake(x1, y0 + a)];
    [path addLineToPoint:CGPointMake(x1, y1 - e)];
    [path addCurveToPoint:CGPointMake(x1 - d, y1 - c) controlPoint1:CGPointMake(x1, y1 - a) controlPoint2:CGPointMake(x1, y1 - b)];
    [path addLineToPoint:CGPointMake(x1 - d, y1 - c)];
    [path addCurveToPoint:CGPointMake(x1 - c, y1 - d) controlPoint1:CGPointMake(x1 - g, y1 - f) controlPoint2:CGPointMake(x1 - f, y1 - g)];
    [path addCurveToPoint:CGPointMake(x1 - e, y1) controlPoint1:CGPointMake(x1 - b, y1) controlPoint2:CGPointMake(x1 - a, y1)];
    [path closePath];
}

@implementation UIPreviewParameters {
@private
    UIColor *_backgroundColor;
    UIBezierPath *_visiblePath;
}

@dynamic shadowPath;

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithTextLineRects:(NSArray<NSValue *> *)textLineRects
{
    if ((self = [self init])) {
        UIBezierPath *path = nil;
        for (NSValue *value in textLineRects) {
            if (![value isKindOfClass:[NSValue class]])
                continue;
            if (!path)
                path = [UIBezierPath bezierPath];
            charon_add_line_rect(path, CGRectIntegral([value CGRectValue]));
        }
        _visiblePath = path;
    }
    return self;
}

- (UIColor *)backgroundColor
{
    return _backgroundColor ?: charon_default_background();
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    _backgroundColor = [backgroundColor copy];
}

- (UIBezierPath *)visiblePath
{
    return _visiblePath;
}

- (void)setVisiblePath:(UIBezierPath *)visiblePath
{
    _visiblePath = [visiblePath copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIPreviewParameters *copy = [[[self class] allocWithZone:zone] init];
    copy->_backgroundColor = [_backgroundColor copy];
    copy->_visiblePath = [_visiblePath copy];
    UIBezierPath *shadow = objc_getAssociatedObject(self, @selector(shadowPath));
    if (shadow)
        objc_setAssociatedObject(copy, @selector(shadowPath), shadow, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return copy;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p; backgroundColor = %@", [self class], self, self.backgroundColor];
    if (_visiblePath)
        [text appendFormat:@"; visiblePath = %@", _visiblePath];
    UIBezierPath *shadow = objc_getAssociatedObject(self, @selector(shadowPath));
    if (shadow)
        [text appendFormat:@"; shadowPath = %@", shadow];
    [text appendString:@">"];
    return text;
}

@end
