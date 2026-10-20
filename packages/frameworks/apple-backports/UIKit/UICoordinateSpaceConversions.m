#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_rotating_key;
static const char revenant_fixed_key;

@interface RevenantScreenSpace : NSObject <UICoordinateSpace>
@property (nonatomic, assign) BOOL fixed;
@end

static UIWindow *revenant_window_of(id space)
{
    if ([space isKindOfClass:[UIWindow class]])
        return space;
    return [space isKindOfClass:[UIView class]] ? [(UIView *)space window] : nil;
}

static UIWindow *revenant_reference_window(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    return application.keyWindow ?: application.windows.firstObject;
}

static CGPoint revenant_to_fixed(id<UICoordinateSpace> space, CGPoint point)
{
    if ([space isKindOfClass:[RevenantScreenSpace class]]) {
        UIWindow *window = revenant_reference_window();
        return [(RevenantScreenSpace *)space fixed] || !window ? point : [window convertPoint:point toWindow:nil];
    }
    UIWindow *window = revenant_window_of(space);
    if (!window)
        return point;
    if ([space isKindOfClass:[UIWindow class]])
        return [window convertPoint:point toWindow:nil];
    return [window convertPoint:[(UIView *)space convertPoint:point toView:nil] toWindow:nil];
}

static CGPoint revenant_from_fixed(id<UICoordinateSpace> space, CGPoint point)
{
    if ([space isKindOfClass:[RevenantScreenSpace class]]) {
        UIWindow *window = revenant_reference_window();
        return [(RevenantScreenSpace *)space fixed] || !window ? point : [window convertPoint:point fromWindow:nil];
    }
    UIWindow *window = revenant_window_of(space);
    if (!window)
        return point;
    if ([space isKindOfClass:[UIWindow class]])
        return [window convertPoint:point fromWindow:nil];
    return [(UIView *)space convertPoint:[window convertPoint:point fromWindow:nil] fromView:nil];
}

static CGPoint revenant_convert_point(id<UICoordinateSpace> from, CGPoint point, id<UICoordinateSpace> to)
{
    if (from == to)
        return point;
    return revenant_from_fixed(to, revenant_to_fixed(from, point));
}

static CGRect revenant_convert_rect(id<UICoordinateSpace> from, CGRect rect, id<UICoordinateSpace> to)
{
    if (from == to)
        return rect;
    CGPoint corners[4] = {
        revenant_convert_point(from, CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)), to),
        revenant_convert_point(from, CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)), to),
        revenant_convert_point(from, CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)), to),
        revenant_convert_point(from, CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)), to)
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

@implementation RevenantScreenSpace

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
    return revenant_convert_point(self, point, coordinateSpace);
}

- (CGPoint)convertPoint:(CGPoint)point fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return revenant_convert_point(coordinateSpace, point, self);
}

- (CGRect)convertRect:(CGRect)rect toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return revenant_convert_rect(self, rect, coordinateSpace);
}

- (CGRect)convertRect:(CGRect)rect fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return revenant_convert_rect(coordinateSpace, rect, self);
}

@end

@implementation UIScreen (RevenantCoordinateSpace)

- (id<UICoordinateSpace>)coordinateSpace
{
    RevenantScreenSpace *space = objc_getAssociatedObject(self, &revenant_rotating_key);
    if (!space) {
        space = [[RevenantScreenSpace alloc] init];
        objc_setAssociatedObject(self, &revenant_rotating_key, space, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return space;
}

- (id<UICoordinateSpace>)fixedCoordinateSpace
{
    RevenantScreenSpace *space = objc_getAssociatedObject(self, &revenant_fixed_key);
    if (!space) {
        space = [[RevenantScreenSpace alloc] init];
        space.fixed = YES;
        objc_setAssociatedObject(self, &revenant_fixed_key, space, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return space;
}

@end

@implementation UIView (RevenantCoordinateSpace)

+ (void)load
{
    class_addProtocol([UIView class], @protocol(UICoordinateSpace));
}

- (CGPoint)convertPoint:(CGPoint)point toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    if ([coordinateSpace isKindOfClass:[UIView class]] && revenant_window_of(coordinateSpace) == revenant_window_of(self) && ![self isKindOfClass:[UIWindow class]] && ![coordinateSpace isKindOfClass:[UIWindow class]])
        return [self convertPoint:point toView:(UIView *)coordinateSpace];
    return revenant_convert_point(self, point, coordinateSpace);
}

- (CGPoint)convertPoint:(CGPoint)point fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    if ([coordinateSpace isKindOfClass:[UIView class]] && revenant_window_of(coordinateSpace) == revenant_window_of(self) && ![self isKindOfClass:[UIWindow class]] && ![coordinateSpace isKindOfClass:[UIWindow class]])
        return [self convertPoint:point fromView:(UIView *)coordinateSpace];
    return revenant_convert_point(coordinateSpace, point, self);
}

- (CGRect)convertRect:(CGRect)rect toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    if ([coordinateSpace isKindOfClass:[UIView class]] && revenant_window_of(coordinateSpace) == revenant_window_of(self) && ![self isKindOfClass:[UIWindow class]] && ![coordinateSpace isKindOfClass:[UIWindow class]])
        return [self convertRect:rect toView:(UIView *)coordinateSpace];
    return revenant_convert_rect(self, rect, coordinateSpace);
}

- (CGRect)convertRect:(CGRect)rect fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    if ([coordinateSpace isKindOfClass:[UIView class]] && revenant_window_of(coordinateSpace) == revenant_window_of(self) && ![self isKindOfClass:[UIWindow class]] && ![coordinateSpace isKindOfClass:[UIWindow class]])
        return [self convertRect:rect fromView:(UIView *)coordinateSpace];
    return revenant_convert_rect(coordinateSpace, rect, self);
}

@end
