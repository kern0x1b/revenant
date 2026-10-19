#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_rotating_key;
static const char charon_fixed_key;

@interface CharonScreenSpace : NSObject <UICoordinateSpace>
@property (nonatomic, assign) BOOL fixed;
@end

static UIWindow *charon_window_of(id space)
{
    if ([space isKindOfClass:[UIWindow class]])
        return space;
    return [space isKindOfClass:[UIView class]] ? [(UIView *)space window] : nil;
}

static UIWindow *charon_reference_window(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    return application.keyWindow ?: application.windows.firstObject;
}

static CGPoint charon_to_fixed(id<UICoordinateSpace> space, CGPoint point)
{
    if ([space isKindOfClass:[CharonScreenSpace class]]) {
        UIWindow *window = charon_reference_window();
        return [(CharonScreenSpace *)space fixed] || !window ? point : [window convertPoint:point toWindow:nil];
    }
    UIWindow *window = charon_window_of(space);
    if (!window)
        return point;
    if ([space isKindOfClass:[UIWindow class]])
        return [window convertPoint:point toWindow:nil];
    return [window convertPoint:[(UIView *)space convertPoint:point toView:nil] toWindow:nil];
}

static CGPoint charon_from_fixed(id<UICoordinateSpace> space, CGPoint point)
{
    if ([space isKindOfClass:[CharonScreenSpace class]]) {
        UIWindow *window = charon_reference_window();
        return [(CharonScreenSpace *)space fixed] || !window ? point : [window convertPoint:point fromWindow:nil];
    }
    UIWindow *window = charon_window_of(space);
    if (!window)
        return point;
    if ([space isKindOfClass:[UIWindow class]])
        return [window convertPoint:point fromWindow:nil];
    return [(UIView *)space convertPoint:[window convertPoint:point fromWindow:nil] fromView:nil];
}

static CGPoint charon_convert_point(id<UICoordinateSpace> from, CGPoint point, id<UICoordinateSpace> to)
{
    if (from == to)
        return point;
    return charon_from_fixed(to, charon_to_fixed(from, point));
}

static CGRect charon_convert_rect(id<UICoordinateSpace> from, CGRect rect, id<UICoordinateSpace> to)
{
    if (from == to)
        return rect;
    CGPoint corners[4] = {
        charon_convert_point(from, CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)), to),
        charon_convert_point(from, CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)), to),
        charon_convert_point(from, CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)), to),
        charon_convert_point(from, CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)), to)
    };
    CGFloat minX = corners[0].x, maxX = corners[0].x, minY = corners[0].y, maxY = corners[0].y;
    for (int index = 1; index < 4; index++) {
        minX = MIN(minX, corners[index].x);
        maxX = MAX(maxX, corners[index].x);
        minY = MIN(minY, corners[index].y);
        maxY = MAX(maxY, corners[index].y);
    }
    return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

@implementation CharonScreenSpace

@synthesize fixed;

- (CGRect)bounds
{
    CGRect bounds = [UIScreen mainScreen].bounds;
    if (self.fixed)
        return bounds;
    return UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) ? CGRectMake(0, 0, bounds.size.height, bounds.size.width) : bounds;
}

- (CGPoint)convertPoint:(CGPoint)point toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return charon_convert_point(self, point, coordinateSpace);
}

- (CGPoint)convertPoint:(CGPoint)point fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return charon_convert_point(coordinateSpace, point, self);
}

- (CGRect)convertRect:(CGRect)rect toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return charon_convert_rect(self, rect, coordinateSpace);
}

- (CGRect)convertRect:(CGRect)rect fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return charon_convert_rect(coordinateSpace, rect, self);
}

@end

@implementation UIScreen (CharonCoordinateSpace)

- (id<UICoordinateSpace>)coordinateSpace
{
    CharonScreenSpace *space = objc_getAssociatedObject(self, &charon_rotating_key);
    if (!space) {
        space = [[CharonScreenSpace alloc] init];
        objc_setAssociatedObject(self, &charon_rotating_key, space, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return space;
}

- (id<UICoordinateSpace>)fixedCoordinateSpace
{
    CharonScreenSpace *space = objc_getAssociatedObject(self, &charon_fixed_key);
    if (!space) {
        space = [[CharonScreenSpace alloc] init];
        space.fixed = YES;
        objc_setAssociatedObject(self, &charon_fixed_key, space, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return space;
}

@end

@implementation UIView (CharonCoordinateSpace)

+ (void)load
{
    class_addProtocol([UIView class], @protocol(UICoordinateSpace));
}

- (CGPoint)convertPoint:(CGPoint)point toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    if ([coordinateSpace isKindOfClass:[UIView class]] && charon_window_of(coordinateSpace) == charon_window_of(self) && ![self isKindOfClass:[UIWindow class]] && ![coordinateSpace isKindOfClass:[UIWindow class]])
        return [self convertPoint:point toView:(UIView *)coordinateSpace];
    return charon_convert_point(self, point, coordinateSpace);
}

- (CGPoint)convertPoint:(CGPoint)point fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    if ([coordinateSpace isKindOfClass:[UIView class]] && charon_window_of(coordinateSpace) == charon_window_of(self) && ![self isKindOfClass:[UIWindow class]] && ![coordinateSpace isKindOfClass:[UIWindow class]])
        return [self convertPoint:point fromView:(UIView *)coordinateSpace];
    return charon_convert_point(coordinateSpace, point, self);
}

- (CGRect)convertRect:(CGRect)rect toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    if ([coordinateSpace isKindOfClass:[UIView class]] && charon_window_of(coordinateSpace) == charon_window_of(self) && ![self isKindOfClass:[UIWindow class]] && ![coordinateSpace isKindOfClass:[UIWindow class]])
        return [self convertRect:rect toView:(UIView *)coordinateSpace];
    return charon_convert_rect(self, rect, coordinateSpace);
}

- (CGRect)convertRect:(CGRect)rect fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    if ([coordinateSpace isKindOfClass:[UIView class]] && charon_window_of(coordinateSpace) == charon_window_of(self) && ![self isKindOfClass:[UIWindow class]] && ![coordinateSpace isKindOfClass:[UIWindow class]])
        return [self convertRect:rect fromView:(UIView *)coordinateSpace];
    return charon_convert_rect(coordinateSpace, rect, self);
}

@end
