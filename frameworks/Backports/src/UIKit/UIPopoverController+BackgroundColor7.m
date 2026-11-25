#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "RevenantPopoverArrow.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char revenant_popover_class_color_key;
static const char revenant_popover_color_key;
static const CGFloat revenant_popover_arrow_base = 37;
static const CGFloat revenant_popover_arrow_height = 13;
static const CGFloat revenant_popover_corner_radius = 7;

@interface RevenantPopoverColorBackground : UIPopoverBackgroundView
@end

@implementation RevenantPopoverColorBackground {
    CGFloat _arrowOffset;
    UIPopoverArrowDirection _arrowDirection;
    CAShapeLayer *_shape;
}

+ (CGFloat)arrowBase
{
    return revenant_popover_arrow_base;
}

+ (CGFloat)arrowHeight
{
    return revenant_popover_arrow_height;
}

+ (UIEdgeInsets)contentViewInsets
{
    return UIEdgeInsetsZero;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _shape = [CAShapeLayer layer];
        _shape.fillColor = [objc_getAssociatedObject([self class], &revenant_popover_class_color_key) CGColor];
        [self.layer addSublayer:_shape];
    }
    return self;
}

- (CGFloat)arrowOffset
{
    return _arrowOffset;
}

- (void)setArrowOffset:(CGFloat)arrowOffset
{
    _arrowOffset = arrowOffset;
    [self setNeedsLayout];
}

- (UIPopoverArrowDirection)arrowDirection
{
    return _arrowDirection;
}

- (void)setArrowDirection:(UIPopoverArrowDirection)arrowDirection
{
    _arrowDirection = arrowDirection;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    RevenantPopoverShape shape = RevenantPopoverShapeMake(self.bounds, (int)_arrowDirection, _arrowOffset, revenant_popover_arrow_base,
                                                          revenant_popover_arrow_height);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:shape.body cornerRadius:revenant_popover_corner_radius];
    if (!CGPointEqualToPoint(shape.first, shape.second)) {
        [path moveToPoint:shape.first];
        [path addLineToPoint:shape.tip];
        [path addLineToPoint:shape.second];
        [path closePath];
    }
    _shape.frame = self.bounds;
    _shape.path = path.CGPath;
}

@end

static Class revenant_popover_background_class(UIColor *color)
{
    static NSMutableDictionary *classes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        classes = [[NSMutableDictionary alloc] init];
    });
    @synchronized (classes) {
        Class made = classes[color];
        if (!made) {
            char name[64];
            snprintf(name, sizeof name, "RevenantPopoverColorBackground%lu", (unsigned long)classes.count);
            made = objc_allocateClassPair([RevenantPopoverColorBackground class], name, 0);
            objc_registerClassPair(made);
            objc_setAssociatedObject(made, &revenant_popover_class_color_key, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            classes[color] = made;
        }
        return made;
    }
}

@implementation UIPopoverController (RevenantBackgroundColor7)

- (UIColor *)backgroundColor
{
    return objc_getAssociatedObject(self, &revenant_popover_color_key);
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    UIColor *color = [backgroundColor copy];
    objc_setAssociatedObject(self, &revenant_popover_color_key, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    Class current = self.popoverBackgroundViewClass;
    if (current && ![current isSubclassOfClass:[RevenantPopoverColorBackground class]])
        return;
    self.popoverBackgroundViewClass = color ? revenant_popover_background_class(color) : Nil;
}

@end
